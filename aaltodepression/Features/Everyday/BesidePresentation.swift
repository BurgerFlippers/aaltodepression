import Foundation
import Observation

/// Frontend adapter: translates existing profile inputs and UI taps to the backend's public API.
/// Planning, persistence, question interpretation and message rules remain in Backend / Planner.
@MainActor @Observable
final class BesidePresentation {
    private(set) var backend: Backend
    let liveBackend: Backend
    private var sandbox: Backend?
    private(set) var selectedDay: Day?
    private(set) var boxes: [BesideHomeBox] = BesideHomeBox.allCases
    private(set) var healthHistory: [StepDay] = []
    private(set) var healthStatus: String?
    private(set) var healthReadAt: Date?
    private var demoEdits: [Int: [String: Double]] = [:]
    let profileStore: EverydayStore
    private(set) var isRefreshing = false
    private var table = FeatureTable()
    private let defaults = UserDefaults.standard

    init(profileStore: EverydayStore, backend: Backend = Backend()) {
        self.profileStore = profileStore
        self.backend = backend
        self.liveBackend = backend
        // Retire personal fields that the simplified onboarding no longer collects.
        profileStore.state.profile.gender = "Prefer not to say"
        profileStore.state.profile.age = ""
        profileStore.state.profile.weight = ""
        profileStore.state.profile.height = ""
        if let data = defaults.data(forKey: "beside.home.boxes"), let stored = try? JSONDecoder().decode([BesideHomeBox].self, from: data) { boxes = stored }
    }

    var setupSignature: String {
        let p = profileStore.state.profile
        return [p.name, String(p.wakeHour), String(p.wakeMinute ?? 0), String(p.bedtimeHour), String(p.bedtimeMinute ?? 0),
                String(p.usesMedication), String(p.medicationHour), String(p.medicationMinute ?? 0),
                String(profileStore.state.motionEnabled ?? false), String(profileStore.state.healthSleepEnabled ?? false),
                profileStore.state.people.map { "\($0.id)|\($0.name)|\($0.phone)|\($0.role.rawValue)" }.joined(separator: ";")].joined(separator: ":")
    }

    func syncSetup() {
        let backend = liveBackend
        let p = profileStore.state.profile
        var setup = backend.planner.setup
        let wasSetUp = backend.planner.isSetUp
        if !p.name.isEmpty || !wasSetUp { setup.personName = p.name }
        setup.wakeTime = p.wakeHour * 60 + (p.wakeMinute ?? 0)
        setup.bedtime = p.bedtimeHour * 60 + (p.bedtimeMinute ?? 0)
        let oldManaged = Set(defaults.stringArray(forKey: "beside.backend.managedContacts") ?? [])
        let mappedIDs = Set(profileStore.state.people.map { person in
            setup.contacts.first { $0.id == person.id || ContactIntake.normalized($0.phone) == ContactIntake.normalized(person.phone) }?.id ?? person.id
        })
        setup.contacts.removeAll { oldManaged.contains($0.id) && !mappedIDs.contains($0.id) }
        for person in profileStore.state.people {
            let old = setup.contacts.first { $0.id == person.id || ContactIntake.normalized($0.phone) == ContactIntake.normalized(person.phone) }
            let sameRole = old.map { ($0.relation == .friend) == (person.role == .friend) } ?? false
            let samePhone = old.map { ContactIntake.normalized($0.phone) == ContactIntake.normalized(person.phone) } ?? false
            let defaultKinds: Set<HelpKind> = person.role == .friend ? [.doSomethingFun] : [.inviteToEat, .groceryRun, .shopTogether, .call]
            let contact = Contact(id: old?.id ?? person.id, name: person.name, phone: person.phone,
                                  relation: sameRole ? old!.relation : person.role == .friend ? .friend : .other,
                                  canHelpWith: sameRole ? old!.canHelpWith : defaultKinds,
                                  agreed: samePhone && sameRole && old?.agreed == true)
            if let index = setup.contacts.firstIndex(where: { $0.id == contact.id }) { setup.contacts[index] = contact }
            else { setup.contacts.append(contact) }
        }
        defaults.set(Array(mappedIDs), forKey: "beside.backend.managedContacts")
        // Importing an address-book entry or UI draft never grants permission to send automatic messages.
        setup.helpConsent = .askEachTime
        if setup != backend.planner.setup { backend.planner.updateSetup(setup) }
    }

    func refresh(readSensors: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        profileStore.refreshDay()
        syncSetup()
        if readSensors {
            await profileStore.refreshSensors()
            var fresh = FeatureTable()
            // Read only what Health already permits. New unrequested types must not hide previously shared core readings.
            // Queries never open a permission prompt; missing or denied types return no usable rows.
            await liveBackend.permissions.refresh()
            if HealthKitSource.isAvailable {
                let keys = Set(BesideHealthMetric.allCases.map(\.key) + [F.activeHours, F.sleepEfficiency, F.awakeMin, F.deepMin, F.remMin, F.coreMin])
                let read = await HealthKitSource().read(days: 120, latitude: 0, longitude: 0, keys: keys)
                // No real location is available here: discard location-dependent daylight estimates.
                for (key, series) in read.numbers where keys.contains(key) {
                    for (day, value) in series { fresh.set(key, day, value) }
                }
                healthReadAt = Date()
                healthStatus = fresh.keys.isEmpty ? "No shared Health readings yet. Check the types shared with Beside in Apple Health." : "Shared Health readings refreshed."
            }
            if profileStore.state.motionEnabled == true {
                fresh.merge(await MotionSource.read())
                if let reading = profileStore.state.movementReading { fresh.set(F.steps, Day(reading.date), Double(reading.steps)) }
            }
            if fresh.value(F.sleepHours, Day(Date())) == nil, profileStore.state.healthSleepEnabled == true, let sleep = profileStore.state.sleepReading {
                fresh.set(F.sleepHours, Day(sleep.end), Double(sleep.minutes) / 60)
            }
            table = fresh
        }
        let inputs = planningTable(table)
        let history = StepEngine.run(table: inputs, through: Day(Date()), homeTimeZone: TimeZone.current.identifier, locationEnabled: false)
        liveBackend.refresh(table: inputs, history: history, locationEnabled: false)
        if selectedDay != nil { refreshSandbox() } else { healthHistory = history }
        if selectedDay == nil { migrateMarksIfNeeded() }
    }

    func connectHealth() async {
        healthStatus = "Opening Apple Health permissions…"
        do {
            try await BesideHealthAccess.request()
            defaults.set(true, forKey: "beside.health.connected")
            await refresh()
        } catch { healthStatus = "Health access couldn't be requested. Try again or check Settings." }
    }

    func saveSupportPreferences(_ preferences: SupportPreferences, contactAgreed: Bool) {
        var setup = backend.planner.setup
        setup.supportPreferences = preferences
        setup.helpConsent = .askEachTime
        if preferences.automaticDemo, contactAgreed, let index = setup.contacts.firstIndex(where: { $0.id == preferences.personID }) {
            setup.contacts[index].agreed = true
            setup.contacts[index].canHelpWith.formUnion(preferences.topics.map(\.helpKind))
        }
        backend.planner.updateSetup(setup)
    }

    func saveBoxes(_ value: [BesideHomeBox]) {
        boxes = value
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "beside.home.boxes") }
    }

    var isDemoMode: Bool { selectedDay != nil }
    func selectDay(_ day: Day) {
        guard day >= Day(Date()) - 120, day <= Day(Date()) else { return }
        if sandbox == nil {
            // Copy the real planner snapshot via its public store API. The copy is in memory;
            // edits never reach the live planner or write back to Apple Health.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("beside-preview-\(UUID().uuidString).json")
            let temporary = PlannerStore(url: url)
            temporary.save(liveBackend.planner.state)
            sandbox = Backend(planner: Planner(store: temporary, isDemo: true))
            temporary.erase()
        }
        selectedDay = day
        backend = sandbox!
        refreshSandbox()
    }

    func returnToLive() {
        selectedDay = nil
        backend = liveBackend
        healthHistory = StepEngine.run(table: planningTable(table), through: Day(Date()), homeTimeZone: TimeZone.current.identifier, locationEnabled: false)
    }

    /// Nutrition and Mind are user-requested context, not new automatic scoring inputs.
    private func planningTable(_ source: FeatureTable) -> FeatureTable {
        let contextKeys = Set(BesideHealthMetric.allCases.filter(\.isContextOnly).map(\.key))
        var result = FeatureTable()
        for (key, series) in source.numbers where !contextKeys.contains(key) {
            for (day, value) in series { result.set(key, day, value) }
        }
        for (key, series) in source.texts { for (day, value) in series { result.setText(key, day, value) } }
        return result
    }
    private var displayedTable: FeatureTable {
        guard isDemoMode else { return table }
        var result = table
        for (jdn, edits) in demoEdits {
            for (key, value) in edits { result.set(key, Day(jdn: jdn), value) }
        }
        return result
    }
    func reading(_ metric: BesideHealthMetric, on day: Day? = nil) -> Double? { displayedTable.value(metric.key, day ?? self.day) }
    func isEdited(_ metric: BesideHealthMetric, on day: Day? = nil) -> Bool { isDemoMode && demoEdits[(day ?? self.day).jdn]?[metric.key] != nil }
    func edit(_ metric: BesideHealthMetric, value: Double, on day: Day) {
        guard isDemoMode, metric.range.contains(value), value.isFinite, !metric.wholeNumber || value.rounded() == value else { return }
        demoEdits[day.jdn, default: [:]][metric.key] = value
        refreshSandbox()
    }
    func resetEdits(on day: Day) { demoEdits.removeValue(forKey: day.jdn); refreshSandbox() }
    var hasDemoEdits: Bool { isDemoMode && !demoEdits.isEmpty }
    private func refreshSandbox() {
        guard let selectedDay, let sandbox else { return }
        let inputs = planningTable(displayedTable.truncated(through: selectedDay))
        healthHistory = StepEngine.run(table: inputs, through: selectedDay, homeTimeZone: TimeZone.current.identifier, locationEnabled: false)
        sandbox.refresh(day: selectedDay, minutes: 18 * 60, table: inputs, history: healthHistory, locationEnabled: false)
    }

    // Live mode uses a complete day; the demo explicitly evaluates the selected day.
    var signalDay: Day { !isDemoMode && day == Day(Date()) ? day - 1 : day }
    var healthSignal: StepDay? { healthHistory.first { $0.day == signalDay } }
    var signalHasBaseline: Bool { healthSignal?.baselineDay != nil }
    var indicatorPosition: Double? {
        if callCue != nil || healthSignal?.step == .reachOut { return 0.95 }
        if let steadiness = healthSignal?.result.steadiness { return min(0.95, max(0.05, 1 - steadiness / 100)) }
        guard let capacity = backend.planner.today?.capacity else { return nil }
        switch capacity { case .good: return 0.08; case .ok: return 0.4; case .low: return 0.72 }
    }

    func handleNotification(_ action: PlannerNotificationAction, at date: Date) {
        liveBackend.planner.handle(action, deliveredAt: date)
    }

    var day: Day { selectedDay ?? Day(Date()) }
    var checkIn: CheckIn? { backend.planner.state.checkIn(on: day) }

    func item(for box: BesideHomeBox) -> PlanItem {
        if box == .sleep {
            var item = PlanItem(id: TodayBuilder.itemID(day, .sleep, "lastnight"), pillar: .sleep, title: "Last night's rest", detail: "Recorded sleep from Apple Health, or your own mark.", size: .tiny)
            if (reading(.sleep) ?? 0) > 0 { item.status = .done; item.doneBy = .health }
            return item
        }
        if box == .move, let item = backend.planner.today?.items.first(where: { $0.pillar == box.pillar }) { return item }
        if box == .eat, let item = backend.planner.today?.items.first(where: { $0.pillar == .food && $0.groceries == nil }) { return item }
        let slug = box == .eat ? "meal" : box == .social ? "connect" : box == .move ? "move" : box == .sleep ? "winddown" : box.id
        return PlanItem(id: TodayBuilder.itemID(day, box.pillar, slug), pillar: box.pillar, title: box.title, size: .tiny)
    }

    func isDone(_ box: BesideHomeBox) -> Bool {
        let item = item(for: box)
        if let mark = backend.planner.state.marks[item.id]?.status { return mark == .done }
        if box == .social { return backend.planner.today?.items.contains(where: { $0.pillar == .social && $0.status == .done }) == true }
        return item.status == .done
    }

    func toggle(_ box: BesideHomeBox) {
        backend.planner.mark(item(for: box), isDone(box) ? .open : .done)
    }

    var callCue: String? {
        for card in backend.planner.today?.cards ?? [] {
            if case .callSignal(let suggestion) = card { return suggestion.contact.name }
        }
        return backend.planner.outbox.first { $0.kind == .call && ($0.status == .pending || $0.status == .sent) && day - $0.day >= 0 && day - $0.day <= 3 }?.contactName
    }

    var winCount: Int {
        let prefix = "\(day.jdn)|"
        var ids = Set(backend.planner.state.marks.filter { $0.key.hasPrefix(prefix) && $0.value.status == .done }.map(\.key))
        for item in backend.planner.today?.items ?? [] where item.status == .done { ids.insert(item.id) }
        return ids.count
    }

    private func migrateMarksIfNeeded() {
        let key = "beside.backend.migratedEverydayMarks"
        guard !defaults.bool(forKey: key) else { return }
        for (legacy, box) in [(EverydayTaskKind.food, BesideHomeBox.eat), (.movement, .move), (.sleep, .sleep)] {
            let item = item(for: box)
            if profileStore.state.completed.contains(legacy), backend.planner.state.marks[item.id] == nil { backend.planner.mark(item, .done) }
        }
        defaults.set(true, forKey: key)
    }
}

import Foundation
import Observation

/// Frontend adapter: translates existing profile inputs and UI taps to the backend's public API.
/// Planning, persistence, question interpretation and message rules remain in Backend / Planner.
@MainActor @Observable
final class BesidePresentation {
    let backend: Backend
    private let profileStore: EverydayStore
    private(set) var isRefreshing = false
    private var table = FeatureTable()
    private let defaults = UserDefaults.standard

    init(profileStore: EverydayStore, backend: Backend = Backend()) {
        self.profileStore = profileStore
        self.backend = backend

    }

    var setupSignature: String {
        let p = profileStore.state.profile
        return [p.name, String(p.wakeHour), String(p.wakeMinute ?? 0), String(p.bedtimeHour), String(p.bedtimeMinute ?? 0),
                String(p.usesMedication), String(p.medicationHour), String(p.medicationMinute ?? 0),
                String(profileStore.state.motionEnabled ?? false), String(profileStore.state.healthSleepEnabled ?? false),
                profileStore.state.people.map { "\($0.id)|\($0.name)|\($0.phone)|\($0.role.rawValue)" }.joined(separator: ";")].joined(separator: ":")
    }

    func syncSetup() {
        guard !backend.isDemo else { return }
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
        if !wasSetUp { setup.helpConsent = .askEachTime }
        let medicationID = "beside-profile-medication"
        if p.usesMedication {
            let medication = Medication(id: medicationID, name: "Your medication", times: [p.medicationHour * 60 + (p.medicationMinute ?? 0)])
            if let i = setup.medications.firstIndex(where: { $0.id == medicationID }) { setup.medications[i] = medication }
            else if setup.medications.isEmpty { setup.medications.append(medication) }
        } else { setup.medications.removeAll { $0.id == medicationID } }
        if setup != backend.planner.setup { backend.planner.updateSetup(setup) }
    }

    func refresh(readSensors: Bool = true) async {
        guard !backend.isDemo else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        profileStore.refreshDay()
        syncSetup()
        if readSensors {
            await profileStore.refreshSensors()
            var fresh = FeatureTable()
            if profileStore.state.motionEnabled == true {
                fresh.merge(await MotionSource.read())
                if let reading = profileStore.state.movementReading { fresh.set(F.steps, Day(reading.date), Double(reading.steps)) }
            }
            if profileStore.state.healthSleepEnabled == true, let sleep = profileStore.state.sleepReading {
                let day = Day(sleep.end)
                fresh.set(F.sleepHours, day, Double(sleep.minutes) / 60)
                let c = Calendar.current.dateComponents([.hour, .minute], from: sleep.start)
                var bedtime = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
                if bedtime < 18 { bedtime += 24 }
                fresh.set(F.bedtime, day, bedtime)
                let wake = Calendar.current.dateComponents([.hour, .minute], from: sleep.end)
                fresh.set(F.wake, day, Double(wake.hour ?? 0) + Double(wake.minute ?? 0) / 60)
            }
            table = fresh
        }
        let history = StepEngine.run(table: table, through: Day(Date()), homeTimeZone: TimeZone.current.identifier, locationEnabled: false)
        backend.refresh(table: table, history: history, locationEnabled: false)
        migrateMarksIfNeeded()
    }

    func handleNotification(_ action: PlannerNotificationAction, at date: Date) {
        backend.planner.handle(action, deliveredAt: date)
    }

    var day: Day { backend.isDemo ? backend.planner.currentDay : Day(Date()) }
    var checkIn: CheckIn? { backend.planner.state.checkIn(on: day) }

    func item(for box: BesideHomeBox) -> PlanItem {
        let pillar = box.pillar
        if box != .eat && box != .connect, let item = backend.planner.today?.items.first(where: { $0.pillar == pillar }) { return item }
        if box == .eat, let item = backend.planner.today?.items.first(where: { $0.pillar == .food && $0.groceries == nil }) { return item }
        let slug = box == .eat ? "meal" : box == .connect ? "connect" : box == .move ? "move" : "winddown"
        return PlanItem(id: TodayBuilder.itemID(day, pillar, slug), pillar: pillar, title: box.title, size: .tiny)
    }

    func isDone(_ box: BesideHomeBox) -> Bool {
        let item = item(for: box)
        if let mark = backend.planner.state.marks[item.id]?.status { return mark == .done }
        if box == .connect { return backend.planner.today?.items.contains(where: { $0.pillar == .social && $0.status == .done }) == true }
        return item.status == .done
    }

    func toggle(_ box: BesideHomeBox) {
        backend.planner.mark(item(for: box), isDone(box) ? .open : .done)
    }

    var callCue: String? {
        for card in backend.planner.today?.cards ?? [] {
            if case .callSignal(let suggestion) = card { return suggestion.contact.name }
        }
        return backend.planner.outbox.first { $0.kind == .call && ($0.status == .pending || $0.status == .sent) && day - $0.day <= 3 }?.contactName
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

enum BesideHomeBox: String, CaseIterable, Identifiable {
    case eat, move, sleep, connect
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var pillar: Pillar { switch self { case .eat: .food; case .move: .movement; case .sleep: .sleep; case .connect: .social } }
    var legacyTask: EverydayTaskKind? { switch self { case .eat: .food; case .move: .movement; case .sleep: .sleep; case .connect: nil } }
    var colorKind: EverydayTaskKind { switch self { case .eat: .food; case .move: .movement; case .sleep: .sleep; case .connect: .medication } }
}

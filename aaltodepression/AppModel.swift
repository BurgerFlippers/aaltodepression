import Foundation
import SwiftData
import UserNotifications
import Observation
import CoreLocation
import HealthKit

@MainActor
@Observable
final class AppModel {
    enum Mode: String { case demo, real }

    var mode: Mode { didSet { defaults.set(mode.rawValue, forKey: "mode"); recompute() } }
    var demoDay: Int { didSet { defaults.set(demoDay, forKey: "demoDay"); recompute() } }
    var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }

    let plan: CarePlan
    let location = LocationSource()
    private(set) var history: [StepDay] = []
    private(set) var table = FeatureTable()
    private(set) var isReading = false
    private(set) var lastRead: Date?

    private let demoTable = DemoSource.table()
    private var realTable = FeatureTable()
    private let defaults = UserDefaults.standard
    private var context: ModelContext?

    static let demoDays = 28...59

    // Navigation shared between tabs.
    enum Tab: Hashable { case today, plan, days }
    var tab: Tab = .today
    var daysDay: Day?
    var daysFocus: ScoreKind?
    var showSettings = false
    var showCompose = false

    /// Action track records, worked out from the data up to the current step period.
    private(set) var records: [String: ActionRecord] = [:]

    /// Signals read live from real HealthKit even in the demo, so the stage demo can close
    /// the step-1 card with a real Apple Watch Breathe session.
    let liveOverrides: Set<String> = [F.mindfulMin]
    private(set) var liveMindfulToday: Double?
    private var observer: HKObserverQuery?
    private let liveStore = HKHealthStore()

    /// Steadiness number on Today: always in the demo, a setting in real use.
    var showSteadinessSetting: Bool { didSet { defaults.set(showSteadinessSetting, forKey: "showSteadiness") } }
    var showsSteadiness: Bool { isDemo || showSteadinessSetting }

    var friendPhone: String { didSet { defaults.set(friendPhone, forKey: "friendPhone") } }
    var clinicEndpoint: String { didSet { defaults.set(clinicEndpoint, forKey: "clinicEndpoint") } }

    init() {
        let url = Bundle.main.url(forResource: "plan_perttu", withExtension: "json")!
        plan = try! CarePlan.load(from: Data(contentsOf: url))
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .demo
        let saved = defaults.integer(forKey: "demoDay")
        demoDay = Self.demoDays.contains(saved) ? saved : 40
        onboarded = defaults.bool(forKey: "onboarded")
        friendPhone = defaults.string(forKey: "friendPhone") ?? ""
        showSteadinessSetting = defaults.bool(forKey: "showSteadiness")
        clinicEndpoint = defaults.string(forKey: "clinicEndpoint") ?? ""
        location.onChange = { [weak self] in self?.recompute() }
    }

    func attach(_ context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        realTable = FeatureStore.load(context)
        location.start()
        recompute()
    }

    // MARK: - Current day

    var current: StepDay? { history.last }
    var isDemo: Bool { mode == .demo }

    /// In real mode the scored day is yesterday, the last complete day. In the demo it is the chosen demo day.
    var scoredDay: Day { isDemo ? DemoSource.day(demoDay) : Day(Date()) - 1 }

    var homeTimeZone: String { isDemo ? DemoSource.homeTimeZone : TimeZone.current.identifier }
    var locationEnabled: Bool { isDemo || location.isEnabled }

    func recompute() {
        if isDemo {
            table = demoTable.truncated(through: scoredDay)
        } else {
            var t = realTable
            t.merge(location.table())
            table = t
        }
        history = StepEngine.run(table: table, through: scoredDay, homeTimeZone: homeTimeZone, locationEnabled: locationEnabled)
        records = ActionHistory.records(plan: plan, history: history, table: table, before: current?.since ?? scoredDay)
        notifyIfNeeded()
        scheduleMessageReminderIfNeeded()
        syncIfNeeded()
    }

    var suggestion: SuggestedAction? {
        guard let c = current, c.step == .nudge else { return nil }
        return ActionPicker.pick(plan: plan, table: table, day: c.day, records: records)
    }

    /// Records for the Plan, up to and including the shown day.
    var planRecords: [String: ActionRecord] {
        ActionHistory.records(plan: plan, history: history, table: table, before: scoredDay + 1)
    }

    /// What confirms that today's action happened, if anything did.
    func doneToday(_ a: CarePlan.Action) -> Double? {
        if a.seenBy == F.mindfulMin, let live = liveMindfulToday, live > 0 { return live }
        return ActionHistory.done(a, table: table, day: scoredDay)
    }

    func openDays(_ day: Day, focus: ScoreKind? = nil) {
        daysDay = day
        daysFocus = focus
        tab = .days
    }

    // MARK: - Live mindful minutes (HKObserverQuery while in the foreground)

    func startLiveObserver() {
        guard HealthKitSource.isAvailable, observer == nil else { return }
        let type = HKCategoryType(.mindfulSession)
        let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, done, _ in
            Task { @MainActor in await self?.refreshLiveMindful() }
            done()
        }
        observer = q
        liveStore.execute(q)
        Task { await refreshLiveMindful() }
    }

    func stopLiveObserver() {
        if let q = observer { liveStore.stop(q) }
        observer = nil
    }

    func refreshLiveMindful() async {
        let start = Calendar.current.startOfDay(for: Date())
        let d = HKSampleQueryDescriptor(predicates: [.categorySample(type: HKCategoryType(.mindfulSession),
                                                                     predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
                                        sortDescriptors: [])
        let samples = (try? await d.result(for: liveStore)) ?? []
        let minutes = samples.map { $0.endDate.timeIntervalSince($0.startDate) / 60 }.reduce(0, +)
        liveMindfulToday = samples.isEmpty ? nil : max(1, minutes.rounded())
    }

    /// Settings fallback for the stage: writes a 1-minute mindful session to Health.
    func simulateBreathing() async {
        let type = HKCategoryType(.mindfulSession)
        try? await liveStore.requestAuthorization(toShare: [type], read: [type])
        let end = Date()
        let sample = HKCategorySample(type: type, value: HKCategoryValue.notApplicable.rawValue,
                                      start: end.addingTimeInterval(-60), end: end)
        try? await liveStore.save(sample)
        await refreshLiveMindful()
    }

    // MARK: - Real data

    func readEverything() async {
        guard !isReading else { return }
        isReading = true
        defer { isReading = false }
        var t = FeatureTable()
        let coord = location.approximateLocation?.coordinate
        let lat = coord?.latitude ?? DemoSource.latitude, lon = coord?.longitude ?? DemoSource.longitude
        if HealthKitSource.isAvailable { t.merge(await HealthKitSource().read(latitude: lat, longitude: lon)) }
        t.merge(await MotionSource.read())
        t.merge(CalendarSource.read())
        t.merge(PhotosSource.read(home: location.home))
        let days = Day.range(Day(Date()) - 365, Day(Date()) + 1)
        t.merge(SolarSource.table(days: days, latitude: lat, longitude: lon))
        realTable.merge(t)
        if let context { FeatureStore.save(t, context) }
        lastRead = Date()
        for key in t.keys.sorted() { print("read \(key): \(t.dayCount(key)) days") }
        recompute()
    }

    func requestPermissions() async {
        if HealthKitSource.isAvailable { try? await HealthKitSource().requestAuthorization() }
        _ = await MotionSource.read()              // first query shows the Motion prompt
        location.requestPermission()
        await CalendarSource.requestAccess()
        await PhotosSource.requestAccess()
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func requestMedicationAccess() async {
        await HealthKitSource().requestMedicationAccess()
        await readEverything()
    }

    // MARK: - Friend message (step 2)

    /// Reminder at 12:00 the next day to send the message. Perttu sends it himself.
    private func scheduleMessageReminderIfNeeded() {
        guard let c = current, c.step == .reachOut, !messageCancelled else { return }
        let key = "messageReminder-\(mode.rawValue)"
        guard defaults.integer(forKey: key) != (c.since?.jdn ?? 0) else { return }
        defaults.set(c.since?.jdn ?? 0, forKey: key)
        guard !isDemo else { return }   // the demo uses "Skip to tomorrow"
        var noon = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
        noon.hour = 12
        postMessageReminder(trigger: UNCalendarNotificationTrigger(dateMatching: noon, repeats: false))
    }

    func skipToTomorrow() {
        postMessageReminder(trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
    }

    private func postMessageReminder(trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.title = "Time to send your message to \(plan.friendName)"
        content.body = "Tap to open it. You send it yourself."
        content.userInfo = ["compose": true]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "message", content: content, trigger: trigger))
    }

    // MARK: - Optional clinic sync: only the step, Steadiness and a short reason leave the phone

    private func syncIfNeeded() {
        guard !clinicEndpoint.isEmpty, let url = URL(string: clinicEndpoint), let c = current else { return }
        let key = "synced-\(mode.rawValue)"
        let stamp = "\(c.step.rawValue)-\(c.since?.jdn ?? 0)"
        guard defaults.string(forKey: key) != stamp else { return }
        defaults.set(stamp, forKey: key)
        let parts = c.result.parts.values.flatMap { $0 }.sorted { $0.points < $1.points }.prefix(2)
        let reason = parts.compactMap { p -> String? in
            guard let u = p.usual else { return nil }
            let i = Explain.info(p.key)
            return "\(i.title) \(Format.value(p.value, i.format)), usual \(Format.value(u.median, i.format))."
        }.joined(separator: " ")
        let body: [String: Any] = [
            "patient": "P-0142", "step": c.step.rawValue,
            "steadiness": Int((c.result.steadiness ?? 0).rounded()),
            "usualSteadiness": Int((c.baselineDay ?? 0).rounded()),
            "reason": reason,
            "tried": records.values.filter { $0.tried > 0 }.map(\.action.title).sorted(),
            "day": c.day.description,
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    /// Cancellation belongs to one reach-out period, identified by its first day.
    var messageCancelled: Bool {
        get { guard let s = current?.since else { return false }; return defaults.integer(forKey: cancelKey) == s.jdn }
        set { defaults.set(newValue ? (current?.since?.jdn ?? 0) : 0, forKey: cancelKey) }
    }
    private var cancelKey: String { "messageCancelled-\(mode.rawValue)" }

    // MARK: - Notification (step 1, at most one per day)

    private func notifyIfNeeded() {
        guard let c = current, c.step == .nudge, let s = suggestion else { return }
        let key = "notified-\(mode.rawValue)"
        guard defaults.integer(forKey: key) != c.day.jdn else { return }
        defaults.set(c.day.jdn, forKey: key)
        let content = UNMutableNotificationContent()
        content.title = "One small thing for today"
        content.body = "\(s.action.title)? It's from your plan with \(plan.nurseName)."
        let request = UNNotificationRequest(identifier: "nudge", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: isDemo ? 2 : 1, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}

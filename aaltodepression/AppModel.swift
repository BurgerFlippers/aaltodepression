import Foundation
import SwiftData
import UserNotifications
import Observation
import CoreLocation

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

    init() {
        let url = Bundle.main.url(forResource: "plan_perttu", withExtension: "json")!
        plan = try! CarePlan.load(from: Data(contentsOf: url))
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .demo
        let saved = defaults.integer(forKey: "demoDay")
        demoDay = Self.demoDays.contains(saved) ? saved : 40
        onboarded = defaults.bool(forKey: "onboarded")
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
        notifyIfNeeded()
    }

    var suggestion: SuggestedAction? {
        guard let c = current, c.step == .nudge else { return nil }
        return ActionPicker.pick(plan: plan, table: table, day: c.since ?? c.day)
    }

    // MARK: - Real data

    func readEverything() async {
        guard !isReading else { return }
        isReading = true
        defer { isReading = false }
        var t = FeatureTable()
        if HealthKitSource.isAvailable { t.merge(await HealthKitSource().read()) }
        t.merge(await MotionSource.read())
        t.merge(CalendarSource.read())
        t.merge(PhotosSource.read(home: location.home))
        let loc = location.approximateLocation?.coordinate
        let days = Day.range(Day(Date()) - 365, Day(Date()) + 1)
        t.merge(SolarSource.table(days: days, latitude: loc?.latitude ?? DemoSource.latitude, longitude: loc?.longitude ?? DemoSource.longitude))
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
        content.title = "Something small for today"
        content.body = "\(s.action.title). It's from your plan with \(plan.nurseName)."
        let request = UNNotificationRequest(identifier: "nudge", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: isDemo ? 2 : 1, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}

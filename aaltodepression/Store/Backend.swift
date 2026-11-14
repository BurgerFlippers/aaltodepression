import Foundation
import Observation

/// Sleep, activity and places, ready for the screens. Rebuilt on every refresh.
@MainActor @Observable
final class TrackingService {
    private(set) var snapshot: TrackingSnapshot?

    var sleep: SleepSummary? { snapshot?.sleep }
    var activity: ActivitySummary? { snapshot?.activity }
    var places: PlacesSummary? { snapshot?.places }

    func refresh(day: Day, minutes: Int, table: FeatureTable, locationEnabled: Bool) {
        snapshot = TrackingBuilder.snapshot(table: table, day: day, minutes: minutes, locationEnabled: locationEnabled)
    }
}

/// The one object the frontend needs. See docs/BACKEND_API.md.
///
///     // AppModel (integrator), once:
///     let backend = Backend()                      // or Backend.demo(day: 50)
///     // after reading Health data, and when the app becomes active:
///     backend.refresh(table: table, history: history, locationEnabled: location.isEnabled)
///
/// Screens then read `backend.planner.today`, `backend.tracking.sleep`, `backend.permissions.status`
/// and call the methods on those three.
@MainActor @Observable
final class Backend {
    let planner: Planner
    let tracking = TrackingService()
    let permissions = PermissionCenter()
    let isDemo: Bool

    // Last inputs, so tracking can be rebuilt when the person answers something (screen time).
    @ObservationIgnored private var lastTable = FeatureTable()
    @ObservationIgnored private var lastMinutes = 12 * 60
    @ObservationIgnored private var lastDay = Day(Date())
    @ObservationIgnored private var lastLocation = false

    init(planner: Planner = Planner()) {
        self.planner = planner
        self.isDemo = planner.isDemo
        planner.onChange = { [weak self] in self?.retrack() }
        Task { [permissions] in await permissions.refresh() }
    }

    private func retrack() {
        tracking.refresh(day: lastDay, minutes: lastMinutes, table: planner.withAnswers(lastTable), locationEnabled: lastLocation)
    }

    /// Demo user on synthetic day `n` (1–59), with the clock at `minutes`.
    static func demo(day n: Int, minutes: Int = 17 * 60 + 30) -> Backend {
        let b = Backend(planner: .demo(day: n, minutes: minutes))
        b.lastTable = DemoSource.table().truncated(through: DemoSource.day(n))
        b.lastDay = DemoSource.day(n)
        b.lastMinutes = minutes
        b.lastLocation = true
        b.retrack()
        return b
    }

    /// Feeds new data to everything. `table` is the feature table (today partial), `history` the step
    /// engine's days. Cheap enough to call on every app activation.
    func refresh(table: FeatureTable, history: [StepDay], locationEnabled: Bool, now: Date = Date()) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        refresh(day: Day(now), minutes: (c.hour ?? 12) * 60 + (c.minute ?? 0), table: table, history: history,
                locationEnabled: locationEnabled)
        Task { [permissions] in await permissions.refresh() }   // statuses can change in the Settings app
    }

    /// Same, with an explicit day and clock (the demo moves its own clock without losing what was done).
    func refresh(day: Day, minutes: Int, table: FeatureTable, history: [StepDay], locationEnabled: Bool) {
        lastTable = table; lastDay = day; lastMinutes = minutes; lastLocation = locationEnabled
        planner.refresh(day: day, minutes: minutes, table: table, history: history)
        retrack()
    }
}

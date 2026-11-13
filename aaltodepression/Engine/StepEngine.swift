import Foundation

/// The hidden step. Never shown as a number.
nonisolated enum Step: Int, Sendable, Comparable {
    case steady = 0
    case nudge = 1      // one action from the plan
    case reachOut = 2   // friend message + nurse call

    static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
}

nonisolated struct StepDay: Sendable {
    let result: DayResult
    let baselineDay: Double?
    let isDrift: Bool
    let driftDaysInLastWeek: Int
    let step: Step
    /// First day of the current step 1 or 2 period.
    let since: Day?

    var day: Day { result.day }
}

nonisolated enum StepEngine {
    static let driftMargin = 15.0
    static let enterNudge = 5        // drift days of the last 7
    static let backToSteady = 2      // drift days of the last 7
    static let reachOutAfter = 10    // days in step 1
    static let minimumCoverageShare = 0.6

    /// Replays every day from the first day with data up to `through`.
    static func run(table: FeatureTable, through: Day, homeTimeZone: String, locationEnabled: Bool) -> [StepDay] {
        guard let first = table.firstDay, first <= through else { return [] }
        let scorer = Scorer(table: table, homeTimeZone: homeTimeZone, locationEnabled: locationEnabled)
        let days = Day.range(first, through + 1)
        let results = days.map(scorer.evaluate)
        // Only compare days that rest on a similar amount of data. Early days, before most
        // features have a usual, are scored from one or two signals and would inflate the baseline.
        let fullest = results.map(\.coverage).max() ?? 0
        let comparable = fullest * minimumCoverageShare
        var steadinessByDay: [Day: Double] = [:]
        for r in results where r.coverage >= comparable {
            if let s = r.steadiness { steadinessByDay[r.day] = s }
        }

        var out: [StepDay] = []
        var drift: [Day: Bool] = [:]
        var step = Step.steady
        var since: Day?

        for r in results {
            let w = Baseline.window(for: r.day)
            let past = Day.range(w.from, w.to).compactMap { steadinessByDay[$0] }.sorted()
            let baselineDay = past.count >= Baseline.minimumDays ? Baseline.median(past) : nil

            var isDrift = false
            if let b = baselineDay, let s = steadinessByDay[r.day] {
                isDrift = s < b - driftMargin && !r.likelyIll && !r.travelling
            }
            drift[r.day] = isDrift
            let count = Day.range(r.day - 6, r.day + 1).filter { drift[$0] == true }.count

            switch step {
            case .steady:
                if count >= enterNudge { step = .nudge; since = r.day }
            case .nudge:
                if count <= backToSteady { step = .steady; since = nil }
                else if let s = since, r.day - s >= reachOutAfter { step = .reachOut; since = r.day }
            case .reachOut:
                if count <= backToSteady { step = .steady; since = nil }
            }
            out.append(StepDay(result: r, baselineDay: baselineDay, isDrift: isDrift,
                               driftDaysInLastWeek: count, step: step, since: since))
        }
        return out
    }
}

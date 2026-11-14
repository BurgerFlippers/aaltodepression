import Foundation

/// How much today can hold. The check-in leads; the data can only make the day lighter,
/// never heavier, and never decides on its own that the day is "good".
nonisolated enum CapacityEstimator {
    static func estimate(checkIn: CheckIn?, stepDay: StepDay?) -> Capacity {
        let step = stepDay?.step ?? .steady
        guard let c = checkIn else {
            // No check-in yet: lean on the data, but never above ok.
            switch step {
            case .reachOut: return .low
            case .nudge, .steady: return .ok
            }
        }
        if c.mood <= 2 || c.energy == .low || c.feelings.contains(.low) || c.feelings.contains(.anxious) {
            return .low
        }
        var cap: Capacity = (c.mood >= 4 && c.energy >= .some && !c.feelings.contains(.tired)) ? .good : .ok
        // Several days off the person's usual: keep the day modest even if this morning feels fine.
        if step >= .nudge { cap = min(cap, .ok) }
        if step == .reachOut, c.mood <= 3 { cap = .low }
        return cap
    }

    /// Consecutive days up to and including `day` with good capacity from a check-in.
    static func goodStreak(state: PlannerState, through day: Day, steps: [Day: StepDay]) -> Int {
        var n = 0
        var d = day
        while let c = state.checkIn(on: d), estimate(checkIn: c, stepDay: steps[d - 1]) == .good {
            n += 1
            d = d - 1
        }
        return n
    }

    /// Check-ins in the last `days` days (including `day`) that came out low.
    static func lowDays(state: PlannerState, through day: Day, days: Int, steps: [Day: StepDay]) -> Int {
        Day.range(day - (days - 1), day + 1).filter { d in
            guard let c = state.checkIn(on: d) else { return false }
            return estimate(checkIn: c, stepDay: steps[d - 1]) == .low
        }.count
    }
}

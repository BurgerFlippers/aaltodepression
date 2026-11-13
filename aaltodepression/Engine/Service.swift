import Foundation

/// Bands for Steadiness, shown as words to the person. The number itself stays in Days.
nonisolated enum SteadinessBand: Sendable {
    case close, bitOff, further

    init(_ steadiness: Double) {
        self = steadiness >= 80 ? .close : steadiness >= 60 ? .bitOff : .further
    }

    var words: String {
        switch self {
        case .close: "Close to your usual"
        case .bitOff: "A bit off your usual"
        case .further: "Further from your usual"
        }
    }
}

/// How much each signal and each score pulls Steadiness down, in points.
/// A score is the equal-weight mean of its signals, so a signal's effect on its score is
/// (sub - 100) / n, and the effects of one score add up to score - 100.
nonisolated enum Effects {
    static func onScore(_ part: ScorePart, in parts: [ScorePart]) -> Double {
        let w = parts.map(\.weight).reduce(0, +)
        return w > 0 ? (part.points - 100) * part.weight / w : 0
    }

    static func onSteadiness(_ kind: ScoreKind, _ result: DayResult) -> Double? {
        guard let score = result.scores[kind] else { return nil }
        let total = result.scores.keys.map(\.weight).reduce(0, +)
        return total > 0 ? (score - 100) * kind.weight / total : nil
    }

    /// Scores sorted by how much they pull Steadiness down, the biggest first.
    static func sortedKinds(_ result: DayResult) -> [ScoreKind] {
        result.scores.keys.sorted { (onSteadiness($0, result) ?? 0) < (onSteadiness($1, result) ?? 0) }
    }
}

/// One plan action's track record, worked out from the data.
nonisolated struct ActionRecord: Sendable {
    let action: CarePlan.Action
    var tried = 0
    var helped = 0
    var confirmable: Bool { action.seenBy != nil }
    var ratio: Double { tried > 0 ? Double(helped) / Double(tried) : -1 }
}

nonisolated enum ActionHistory {
    static let lowDay = 80.0          // below "Close to your usual"
    static let helpWindow = 7         // days to get back

    /// Whether the data shows the action done on a day, and the value that shows it.
    static func done(_ a: CarePlan.Action, table: FeatureTable, day: Day) -> Double? {
        switch a.seenBy {
        case F.mindfulMin?:
            if let v = table.value(F.mindfulMin, day), v > 0 { return v }
        case F.daylightMin?:
            if let v = table.value(F.daylightMin, day) ?? table.value(F.daylightWalkMin, day), v >= 20 { return v }
        case F.steps?:
            if let v = table.value(F.steps, day), let u = Baseline.usual(F.steps, in: table, for: day), v >= u.median { return v }
        default: break
        }
        return nil
    }

    /// Times an action was done on a day below usual, and how often Steadiness came back
    /// to "close to usual" within 7 days. One count per week at most, so a run of days is one try.
    static func records(plan: CarePlan, history: [StepDay], table: FeatureTable, before end: Day) -> [String: ActionRecord] {
        var steadiness: [Day: Double] = [:]
        for d in history { if let s = d.result.steadiness { steadiness[d.day] = s } }
        var out: [String: ActionRecord] = [:]
        for a in plan.actions {
            var r = ActionRecord(action: a)
            var lastCounted: Day?
            for d in history where d.day < end {
                guard let s = steadiness[d.day], s < lowDay, done(a, table: table, day: d.day) != nil else { continue }
                if let l = lastCounted, d.day - l < helpWindow { continue }
                lastCounted = d.day
                r.tried += 1
                let back = Day.range(d.day + 1, min(d.day + helpWindow + 1, end + 1)).contains { (steadiness[$0] ?? 0) >= lowDay }
                if back { r.helped += 1 }
            }
            out[a.key] = r
        }
        return out
    }
}

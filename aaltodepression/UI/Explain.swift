import Foundation

/// Words for the numbers: labels for derived parts and the one-line "what moved" summary.
enum Explain {
    /// Title and format for a score part, including parts the engine derives itself.
    static func info(_ key: String) -> (title: String, format: ValueFormat) {
        switch key {
        case Scorer.sleep3Key: ("Sleep, last 3 nights", .hoursMinutes)
        case Scorer.wakeSpreadKey: ("Wake time varied by", .hoursMinutes)
        case Scorer.bedSpreadKey: ("Bedtime varied by", .hoursMinutes)
        case Scorer.midpointKey: ("Middle of sleep, last 3 nights", .clockAfter18)
        default:
            if let i = FeatureCatalog.byKey[key] { (i.title, i.format) } else { (key, .decimal(1, "")) }
        }
    }

    /// How today sits against the usual day, without a verdict.
    static func headline(_ day: StepDay) -> String {
        guard let s = day.result.steadiness else { return "Not enough data for this day" }
        guard let b = day.baselineDay else { return "Still learning your usual" }
        if s >= b - 5 { return "Close to your usual" }
        if s >= b - 15 { return "A little further from your usual" }
        return "Further from your usual than most days"
    }

    /// The single part that pulled the day down most, as one plain sentence.
    static func biggestGap(_ day: StepDay) -> String? {
        let r = day.result
        guard let s = r.steadiness, let b = day.baselineDay, s < b - 5 else { return nil }
        var worst: (cost: Double, kind: ScoreKind, part: ScorePart?)?
        for (kind, score) in r.scores {
            let cost = (100 - score) * kind.weight
            if worst == nil || cost > worst!.cost {
                worst = (cost, kind, r.parts[kind]?.min { $0.points < $1.points })
            }
        }
        guard let w = worst else { return nil }
        if w.kind == .daylight {
            return "Mostly daylight: \(Format.value(r.scores[.daylight]! / 100 * r.daylightTarget, .minutes)) outside, aiming for \(Format.value(r.daylightTarget, .minutes))."
        }
        guard let p = w.part, let u = p.usual else { return "Mostly \(w.kind.title.lowercased())." }
        let i = info(p.key)
        let what = i.title.lowercased() == w.kind.title.lowercased() ? "" : i.title.lowercased() + " "
        return "Mostly \(w.kind.title.lowercased()): \(what)\(Format.value(p.value, i.format)), usually \(Format.value(u.median, i.format))."
    }
}

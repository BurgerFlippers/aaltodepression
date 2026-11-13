import Foundation

nonisolated enum ScoreKind: String, CaseIterable, Sendable, Identifiable {
    case sleep, rhythm, movement, daylight, places, body

    var id: String { rawValue }

    var weight: Double {
        switch self {
        // Sleep and rhythm carry most: within-person sleep changes lead next-day affect more than
        // the reverse (Triantafillou 2019), and regularity predicts outcomes beyond duration
        // (Windred 2024; Matcham 2024). Body signals have the weakest within-person evidence.
        case .sleep: 0.30
        case .rhythm: 0.25
        case .movement: 0.20
        case .daylight: 0.10
        case .places: 0.10
        case .body: 0.05
        }
    }

    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .rhythm: "Rhythm"
        case .movement: "Movement"
        case .daylight: "Daylight"
        case .places: "Places"
        case .body: "Body"
        }
    }
}

/// One feature's contribution to a score, kept so the app can explain itself.
nonisolated struct ScorePart: Sendable {
    let key: String
    let value: Double
    let usual: Usual?
    let points: Double
}

nonisolated struct DayResult: Sendable {
    let day: Day
    var scores: [ScoreKind: Double] = [:]
    var parts: [ScoreKind: [ScorePart]] = [:]
    var dayScore: Double?
    /// Sum of the weights of the scores that were available (0...1).
    var coverage: Double = 0
    var likelyIll = false
    var travelling = false
    var daylightTarget: Double = 30
    /// Rhythm inputs: standard deviation in hours of wake and bedtime over the last 7 days.
    var wakeSD: Double?
    var bedtimeSD: Double?
    /// Daylight came from steps in daylight hours, not from Apple Watch.
    var daylightEstimated = false
    /// Rhythm parts: name, today's value, usual, points.
    var rhythmParts: [ScorePart] = []
}

nonisolated struct Scorer: Sendable {
    let table: FeatureTable
    /// Home time zone identifier, used for the travelling flag.
    let homeTimeZone: String
    /// Places is hidden when location is off.
    let locationEnabled: Bool

    func evaluate(_ day: Day) -> DayResult {
        var r = DayResult(day: day)

        func part(_ key: String, oneSided: Bool) -> ScorePart? {
            guard let x = table.value(key, day), let u = Baseline.usual(key, in: table, for: day) else { return nil }
            let p = oneSided ? Baseline.atLeast(x, u) : Baseline.closeness(x, u)
            return ScorePart(key: key, value: x, usual: u, points: p)
        }

        func record(_ kind: ScoreKind, _ parts: [ScorePart?]) {
            let ps = parts.compactMap { $0 }
            guard !ps.isEmpty else { return }
            r.parts[kind] = ps
            r.scores[kind] = ps.map(\.points).reduce(0, +) / Double(ps.count)
        }

        // Sleep: last night, plus the last three nights together, because short nights add up
        // (Van Dongen 2003) and a single good night does not undo two short ones.
        var debt: ScorePart?
        let nights = table.values(F.sleepHours, from: day - 2, to: day + 1)
        if nights.count >= 2, let u = Baseline.usual(F.sleepHours, in: table, for: day) {
            let mean = nights.reduce(0, +) / Double(nights.count)
            debt = ScorePart(key: Scorer.sleep3Key, value: mean, usual: u, points: Baseline.atLeast(mean, u))
        }
        record(.sleep, [part(F.sleepHours, oneSided: false), part(F.bedtime, oneSided: false),
                        part(F.wake, oneSided: false), part(F.awakeMin, oneSided: false), debt])

        // Rhythm: compared with the person's own regularity, not a fixed number of hours.
        let week = (day - 6, day + 1)
        r.wakeSD = Self.sd(table.values(F.wake, from: week.0, to: week.1))
        r.bedtimeSD = Self.sd(table.values(F.bedtime, from: week.0, to: week.1))
        let w = Baseline.window(for: day)
        func spreadPart(_ key: String, _ sd: Double?) -> ScorePart? {
            guard let sd else { return nil }
            let usualSD = Self.sd(table.values(key, from: w.from, to: w.to))
            let points: Double
            if let usualSD {
                // As regular as usual (or more) is full; each extra usual-spread costs 60 points.
                let allowed = max(usualSD, 0.25) * 1.25
                points = sd <= allowed ? 100 : max(0, 100 - (sd - allowed) / max(usualSD, 0.25) * 60)
            } else {
                points = min(100, max(0, (2.0 - sd) / 1.5 * 100))
            }
            return ScorePart(key: key == F.wake ? Scorer.wakeSpreadKey : Scorer.bedSpreadKey, value: sd,
                             usual: usualSD.map { Usual(median: $0, mad: 0) }, points: points)
        }
        // Sleep midpoint over the last three nights against the usual midpoint: a drift later shows here first.
        var midpoint: ScorePart?
        let mids = Day.range(day - 2, day + 1).compactMap { d -> Double? in
            guard let b = table.value(F.bedtime, d), let wk = table.value(F.wake, d) else { return nil }
            return (b + wk + 6) / 2
        }
        let usualMids = Day.range(w.from, w.to).compactMap { d -> Double? in
            guard let b = table.value(F.bedtime, d), let wk = table.value(F.wake, d) else { return nil }
            return (b + wk + 6) / 2
        }
        if mids.count >= 2, let u = Baseline.usual(usualMids) {
            let m = mids.reduce(0, +) / Double(mids.count)
            let uu = Usual(median: u.median, mad: max(u.mad, 0.25))
            midpoint = ScorePart(key: Scorer.midpointKey, value: m, usual: uu, points: Baseline.closeness(m, uu))
        }
        // Listening late at night, before sleep: less than usual is fine.
        var lateListening: ScorePart?
        if let x = table.value(F.nightListeningMin, day), let u = Baseline.usual(F.nightListeningMin, in: table, for: day) {
            lateListening = ScorePart(key: F.nightListeningMin, value: x, usual: u,
                                      points: x <= u.median ? 100 : Baseline.closeness(x, Usual(median: u.median, mad: max(u.mad, 5))))
        }
        let rp = [spreadPart(F.wake, r.wakeSD), spreadPart(F.bedtime, r.bedtimeSD), midpoint, lateListening].compactMap { $0 }
        if !rp.isEmpty {
            r.rhythmParts = rp
            r.parts[.rhythm] = rp
            r.scores[.rhythm] = rp.map(\.points).reduce(0, +) / Double(rp.count)
        }

        // Hours with movement come from hourly Health steps, which go back years; Core Motion's
        // still hours only cover the last week, so they never build a usual.
        record(.movement, [part(F.steps, oneSided: true), part(F.exerciseMin, oneSided: true),
                           part(F.walkingSpeed, oneSided: false), part(F.activeHours, oneSided: true)])

        // Daylight: a fair target that shrinks in a Finnish winter.
        if let len = table.value(F.dayLengthH, day), len < 8 {
            r.daylightTarget = max(15, 30 * len / 8)
        }
        if let minutes = table.value(F.daylightMin, day) {
            r.scores[.daylight] = min(100, minutes / r.daylightTarget * 100)
        } else if let minutes = table.value(F.daylightWalkMin, day) {
            // No Apple Watch daylight: estimate from steps between sunrise and sunset.
            r.scores[.daylight] = min(100, minutes / r.daylightTarget * 100)
            r.daylightEstimated = true
        }

        if locationEnabled {
            record(.places, [part(F.awayHours, oneSided: true), part(F.placesVisited, oneSided: true)])
        }

        record(.body, [part(F.restingHR, oneSided: false), part(F.hrv, oneSided: false),
                       part(F.wristTemp, oneSided: false), part(F.respRate, oneSided: false)])

        // Day score: weighted mean of what is available, renormalised.
        let available = r.scores
        let totalWeight = available.keys.map(\.weight).reduce(0, +)
        r.coverage = totalWeight
        if totalWeight > 0 {
            r.dayScore = available.map { $0.key.weight * $0.value }.reduce(0, +) / totalWeight
        }

        // Context flags. Never shown as health claims.
        if let hr = table.value(F.restingHR, day), let u = Baseline.usual(F.restingHR, in: table, for: day), hr >= u.median + 5 {
            r.likelyIll = true
        }
        if let t = table.value(F.wristTemp, day), let u = Baseline.usual(F.wristTemp, in: table, for: day), t >= u.median + 0.5 {
            r.likelyIll = true
        }
        if let tz = table.text(F.timeZone, day), tz != homeTimeZone(for: day) {
            r.travelling = true
        }
        if let km = table.value(F.maxKmFromHome, day), km > 100 {
            r.travelling = true
        }
        return r
    }

    /// The most common sleep time zone in the baseline window, else the configured home.
    private func homeTimeZone(for day: Day) -> String {
        let w = Baseline.window(for: day)
        var counts: [String: Int] = [:]
        for d in Day.range(w.from, w.to) {
            if let tz = table.text(F.timeZone, d) { counts[tz, default: 0] += 1 }
        }
        return counts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key ?? homeTimeZone
    }

    static let sleep3Key = "sleep3", wakeSpreadKey = "wakeSpread", bedSpreadKey = "bedSpread", midpointKey = "midpoint"

    static func sd(_ xs: [Double]) -> Double? {
        guard xs.count >= 4 else { return nil }
        let mean = xs.reduce(0, +) / Double(xs.count)
        let v = xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count - 1)
        return v.squareRoot()
    }
}

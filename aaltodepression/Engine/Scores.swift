import Foundation

nonisolated enum ScoreKind: String, CaseIterable, Sendable, Identifiable {
    case sleep, rhythm, movement, daylight, places, body

    var id: String { rawValue }

    var weight: Double {
        switch self {
        case .sleep: 0.30
        case .rhythm: 0.20
        case .movement: 0.20
        case .daylight: 0.10
        case .places: 0.10
        case .body: 0.10
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

        record(.sleep, [part(F.sleepHours, oneSided: false), part(F.bedtime, oneSided: false),
                        part(F.wake, oneSided: false), part(F.awakeMin, oneSided: false)])

        // Rhythm: how regular wake and bedtime were over the last 7 days.
        let week = (day - 6, day + 1)
        r.wakeSD = Self.sd(table.values(F.wake, from: week.0, to: week.1))
        r.bedtimeSD = Self.sd(table.values(F.bedtime, from: week.0, to: week.1))
        let rhythmParts = [r.wakeSD, r.bedtimeSD].compactMap { $0 }.map { sd in
            min(100, max(0, (2.0 - sd) / 1.5 * 100))
        }
        if !rhythmParts.isEmpty {
            r.scores[.rhythm] = rhythmParts.reduce(0, +) / Double(rhythmParts.count)
        }

        record(.movement, [part(F.steps, oneSided: true), part(F.exerciseMin, oneSided: true),
                           part(F.walkingSpeed, oneSided: false), part(F.stillHours, oneSided: false)])

        // Daylight: a fair target that shrinks in a Finnish winter.
        if let len = table.value(F.dayLengthH, day), len < 8 {
            r.daylightTarget = max(15, 30 * len / 8)
        }
        if let minutes = table.value(F.daylightMin, day) {
            r.scores[.daylight] = min(100, minutes / r.daylightTarget * 100)
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

    static func sd(_ xs: [Double]) -> Double? {
        guard xs.count >= 4 else { return nil }
        let mean = xs.reduce(0, +) / Double(xs.count)
        let v = xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count - 1)
        return v.squareRoot()
    }
}

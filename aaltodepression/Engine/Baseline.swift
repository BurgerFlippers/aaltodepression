import Foundation

/// A person's own usual for one feature: median and MAD over the baseline window.
nonisolated struct Usual: Sendable, Equatable {
    let median: Double
    let mad: Double
}

nonisolated enum Baseline {
    /// Baseline days are the 28 days before the current 7-day window starts,
    /// so a week of change cannot pull the usual towards itself.
    static let windowDays = 28
    static let recentDays = 7
    static let minimumDays = 7

    static func window(for day: Day) -> (from: Day, to: Day) {
        let to = day - (recentDays - 1)
        return (to - windowDays, to)
    }

    static func usual(_ xs: [Double]) -> Usual? {
        guard xs.count >= minimumDays else { return nil }
        let s = xs.sorted()
        let m = median(s)
        let dev = xs.map { abs($0 - m) }.sorted()
        return Usual(median: m, mad: max(median(dev), 1e-6))
    }

    static func usual(_ key: String, in table: FeatureTable, for day: Day) -> Usual? {
        let w = window(for: day)
        guard let u = usual(table.values(key, from: w.from, to: w.to)) else { return nil }
        // A very steady week (or whole-number counts) can give a MAD near zero, which would
        // turn a tiny change into a zero score. The floor keeps one small step from looking big.
        return Usual(median: u.median, mad: max(u.mad, madFloor[key] ?? 1e-6))
    }

    /// Smallest change worth noticing, per feature (in the feature's own unit).
    static let madFloor: [String: Double] = [
        "sleepHours": 0.15, "bedtime": 0.1, "wake": 0.1, "awakeMin": 3,
        "steps": 250, "exerciseMin": 3, "walkingSpeed": 0.02, "stillHours": 0.25,
        "awayHours": 0.25, "placesVisited": 0.5,
        "restingHR": 1, "hrv": 2, "wristTemp": 0.05, "respRate": 0.2,
        "daylightMin": 3, "mindfulMin": 1, "activeHours": 1, "nightListeningMin": 5, "deepMin": 5, "remMin": 5, "sleepEfficiency": 0.02, "flights": 2, "standMin": 10, "standHours": 1, "activeEnergy": 25, "workoutMin": 5, "headphoneMin": 10, "homeHours": 0.5, "maxKmFromHome": 1, "locationEntropy": 0.1, "calendarEvents": 1, "eventHours": 0.5, "photosTaken": 1, "envSound": 2, "heartRate": 2, "heartRateMin": 2, "heartRateMax": 5, "walkingHR": 2, "bodyMass": 0.3, "basalEnergy": 20, "spo2": 0.005, "uvExposure": 0.3, "toothbrushing": 0.5, "breathingDisturbances": 0.5, "walkRunDistance": 0.2, "cyclingDistance": 1, "automotiveHours": 0.25, "photosAwayFromHome": 1, "screenTimeSelf": 0.5,
    ]

    static func median(_ sorted: [Double]) -> Double {
        let n = sorted.count
        return n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }

    // MARK: Scoring helpers (0...100, 100 = your usual or better)

    /// Two-sided: being far off in either direction lowers the score.
    static func closeness(_ x: Double, _ u: Usual) -> Double {
        let z = abs(x - u.median) / (1.4826 * u.mad)
        return max(0, 100 - z * 25)
    }

    /// One-sided: more than usual is fine.
    static func atLeast(_ x: Double, _ u: Usual) -> Double {
        x >= u.median ? 100 : closeness(x, u)
    }
}

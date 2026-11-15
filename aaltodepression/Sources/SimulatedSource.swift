import Foundation

/// Simulated history for demos and for people whose devices log little (for example no food logs).
/// The 60-day demo person from `DemoSource`, moved so that the last day is `end`, plus food and water logs.
/// It never writes to Health.
nonisolated enum SimulatedSource {
    static func table(endingOn end: Day, homeTimeZone: String = TimeZone.current.identifier) -> FeatureTable {
        let source = DemoSource.table()
        let offset = end - DemoSource.day(DemoSource.dayCount - 1)
        var t = FeatureTable()
        for (key, series) in source.numbers {
            for (day, value) in series { t.set(key, day + offset, value) }
        }
        for (key, series) in source.texts {
            for (day, value) in series {
                // The demo person lives in Helsinki; keep "home" as this phone's time zone so no day reads as travel.
                t.setText(key, day + offset, key == F.timeZone && value == DemoSource.homeTimeZone ? homeTimeZone : value)
            }
        }
        for n in 0..<DemoSource.dayCount {
            let day = DemoSource.day(n) + offset
            let drift = n >= 45 ? min(1, 0.75 + Double(n - 45) * 0.25) : 0
            // Meals get smaller and less regular as the routine slips; logged on most days, like a real person.
            guard noise(n, 1) < 0.85 - drift * 0.25 else { continue }
            let energy = 2150 - drift * 650 + (noise(n, 2) - 0.5) * 300
            t.set(F.dietaryEnergy, day, energy.rounded())
            t.set(F.dietaryProtein, day, (energy * 0.045 + (noise(n, 3) - 0.5) * 12).rounded())
            t.set(F.dietaryCarbs, day, (energy * 0.115 + (noise(n, 4) - 0.5) * 30).rounded())
            t.set(F.dietaryFat, day, (energy * 0.036 + (noise(n, 5) - 0.5) * 10).rounded())
            t.set(F.dietaryWater, day, (1700 - drift * 600 + (noise(n, 6) - 0.5) * 400).rounded())
        }
        return t
    }

    /// Deterministic 0..<1 noise per (day, salt).
    private static func noise(_ n: Int, _ salt: Int) -> Double {
        let x = sin(Double(n) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}

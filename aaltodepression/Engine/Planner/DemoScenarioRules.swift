import Foundation

/// An explicitly simulated history for judging. It never writes to Health or changes live records.
/// Load changes actual inputs to the existing scorer, rather than assigning a score or a support step.
nonisolated enum DemoScenarioRules {
    static func table(ending day: Day, load: Double, source: FeatureTable) -> FeatureTable {
        let load = load.isFinite ? min(1, max(0, load)) : 0
        let usualSleep = min(9, max(6, Baseline.usual(F.sleepHours, in: source, for: day)?.median ?? 8))
        let usualSteps = min(12000, max(3000, Baseline.usual(F.steps, in: source, for: day)?.median ?? 6000))
        // The demo compresses a sustained change into one gesture, not one bad measurement.
        let changedDays = load >= 0.8 ? 18 : 7
        var result = FeatureTable()
        for d in Day.range(day - 90, day + 1) {
            let variation = Double((d.jdn % 5) - 2)
            let change = d > day - changedDays ? load : 0
            result.set(F.sleepHours, d, usualSleep + variation * 0.06 - change * 0.9)
            result.set(F.bedtime, d, 5 + variation * 0.04 + change * 0.6)
            result.set(F.wake, d, 7 + variation * 0.04 + change * 0.6)
            result.set(F.steps, d, max(0, usualSteps + variation * 90 - change * 1500).rounded())
            result.set(F.exerciseMin, d, max(0, 25 + variation - change * 18))
            result.set(F.daylightMin, d, max(0, 35 + variation - change * 18))
            result.set(F.activeHours, d, max(0, 8 - change * 6))
        }
        return result
    }
}

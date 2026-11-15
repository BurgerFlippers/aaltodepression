import Foundation

/// Presentation feedback for the judging bar, separate from Health scores and support rules.
nonisolated struct BesideRoutineFeedback {
    let categoryCount: Int

    init(day: Day, marks: [String: ItemMark]) {
        let categories = Set(marks.compactMap { key, mark -> Pillar? in
            let parts = key.split(separator: "|")
            guard mark.status == .done, parts.count >= 3, Int(parts[0]) == day.jdn else { return nil }
            return Pillar(rawValue: String(parts[1]))
        })
        categoryCount = min(6, categories.count)
    }

    /// Each distinct category shifts the display 1.5 percentage points towards green (max 9).
    /// Repeated taps and multiple tasks in the same category never stack extra credit.
    var adjustment: Double { Double(categoryCount) * 0.015 }
    func position(from base: Double) -> Double { max(0.01, base - adjustment) }
}

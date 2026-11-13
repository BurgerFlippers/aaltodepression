import Foundation

/// One value per feature per day. Missing means unknown, never zero.
nonisolated struct FeatureTable: Sendable {
    private(set) var numbers: [String: [Day: Double]] = [:]
    private(set) var texts: [String: [Day: String]] = [:]

    init() {}

    mutating func set(_ key: String, _ day: Day, _ value: Double?) {
        guard let value, value.isFinite else { return }
        numbers[key, default: [:]][day] = value
    }

    mutating func setText(_ key: String, _ day: Day, _ value: String?) {
        guard let value, !value.isEmpty else { return }
        texts[key, default: [:]][day] = value
    }

    func value(_ key: String, _ day: Day) -> Double? { numbers[key]?[day] }
    func text(_ key: String, _ day: Day) -> String? { texts[key]?[day] }

    /// Values for the days in [from, to), skipping unknown days.
    func values(_ key: String, from: Day, to: Day) -> [Double] {
        guard let series = numbers[key] else { return [] }
        return Day.range(from, to).compactMap { series[$0] }
    }

    var keys: Set<String> { Set(numbers.keys).union(texts.keys) }

    func dayCount(_ key: String) -> Int { (numbers[key]?.count ?? 0) + (texts[key]?.count ?? 0) }

    func lastDay(_ key: String, onOrBefore day: Day) -> Day? {
        let a = numbers[key]?.keys.filter { $0 <= day }.max()
        let b = texts[key]?.keys.filter { $0 <= day }.max()
        switch (a, b) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    var firstDay: Day? { (numbers.values.flatMap(\.keys) + texts.values.flatMap(\.keys)).min() }
    var lastDay: Day? { (numbers.values.flatMap(\.keys) + texts.values.flatMap(\.keys)).max() }

    /// A copy that only contains days on or before `day` (used to replay the demo).
    func truncated(through day: Day) -> FeatureTable {
        var t = FeatureTable()
        t.numbers = numbers.mapValues { $0.filter { $0.key <= day } }.filter { !$0.value.isEmpty }
        t.texts = texts.mapValues { $0.filter { $0.key <= day } }.filter { !$0.value.isEmpty }
        return t
    }

    mutating func merge(_ other: FeatureTable) {
        for (k, s) in other.numbers { numbers[k, default: [:]].merge(s) { _, new in new } }
        for (k, s) in other.texts { texts[k, default: [:]].merge(s) { _, new in new } }
    }
}

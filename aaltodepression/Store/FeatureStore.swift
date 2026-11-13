import Foundation
import SwiftData

/// One stored value per feature per day: the local feature store.
@Model
final class DailyFeature {
    @Attribute(.unique) var id: String   // "key|day"
    var key: String
    var day: Int          // Julian day number
    var value: Double?
    var text: String?

    init(key: String, day: Int, value: Double?, text: String?) {
        self.id = "\(key)|\(day)"; self.key = key; self.day = day; self.value = value; self.text = text
    }
}

@MainActor
enum FeatureStore {
    static func load(_ context: ModelContext) -> FeatureTable {
        var t = FeatureTable()
        for f in (try? context.fetch(FetchDescriptor<DailyFeature>())) ?? [] {
            t.set(f.key, Day(jdn: f.day), f.value)
            t.setText(f.key, Day(jdn: f.day), f.text)
        }
        return t
    }

    /// Upserts every value in the table.
    static func save(_ table: FeatureTable, _ context: ModelContext) {
        var existing: [String: DailyFeature] = [:]
        for f in (try? context.fetch(FetchDescriptor<DailyFeature>())) ?? [] { existing["\(f.key)|\(f.day)"] = f }
        for (key, series) in table.numbers {
            for (day, v) in series {
                if let f = existing["\(key)|\(day.jdn)"] { f.value = v }
                else { context.insert(DailyFeature(key: key, day: day.jdn, value: v, text: nil)) }
            }
        }
        for (key, series) in table.texts {
            for (day, v) in series {
                if let f = existing["\(key)|\(day.jdn)"] { f.text = v }
                else { context.insert(DailyFeature(key: key, day: day.jdn, value: nil, text: v)) }
            }
        }
        try? context.save()
    }
}

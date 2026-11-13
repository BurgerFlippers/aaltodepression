import Foundation

/// The nurse's plan. In the demo it comes from plan_perttu.json instead of a QR code.
nonisolated struct CarePlan: Codable, Sendable, Equatable {
    struct Action: Codable, Sendable, Equatable, Identifiable {
        let key: String
        let title: String
        /// Feature that can confirm the action happened, if any.
        let seenBy: String?
        var id: String { key }
    }

    let patientName: String
    let nurseName: String
    let earlySigns: [String]
    let actions: [Action]
    let friendName: String
    let friendMessage: String
    let startDate: String
    let months: Int

    static func load(from data: Data) throws -> CarePlan {
        try JSONDecoder().decode(CarePlan.self, from: data)
    }
}

nonisolated struct SuggestedAction: Sendable {
    let action: CarePlan.Action
    /// Today's value of the feature that can confirm the action, if known.
    let todayValue: Double?
    let usual: Usual?
}

nonisolated enum ActionPicker {
    /// Picks the action with the best "helped" record that the data can confirm.
    /// Untried confirmable actions come next, actions only the person can report come last.
    static func pick(plan: CarePlan, table: FeatureTable, day: Day, records: [String: ActionRecord]) -> SuggestedAction? {
        let ranked = plan.actions.enumerated().sorted { a, b in
            func rank(_ x: (offset: Int, element: CarePlan.Action)) -> (Int, Double, Int, Int) {
                let r = records[x.element.key]
                let group = x.element.seenBy == nil ? 2 : ((r?.tried ?? 0) > 0 ? 0 : 1)
                return (group, -(r?.ratio ?? -1), -(r?.tried ?? 0), x.offset)
            }
            return rank(a) < rank(b)
        }
        guard let a = ranked.first?.element else { return nil }
        let key = a.seenBy
        return SuggestedAction(action: a, todayValue: key.flatMap { table.value($0, day) },
                               usual: key.flatMap { Baseline.usual($0, in: table, for: day) })
    }
}

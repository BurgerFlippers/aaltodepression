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
    /// Picks one action, preferring ones the data can confirm and that are furthest below usual.
    static func pick(plan: CarePlan, table: FeatureTable, day: Day) -> SuggestedAction? {
        var best: (score: Double, s: SuggestedAction)?
        for (i, a) in plan.actions.enumerated() {
            var score = 1000.0 + Double(i)   // unconfirmable actions come last, in plan order
            var today: Double?
            var usual: Usual?
            if let key = a.seenBy {
                today = table.value(key, day)
                usual = Baseline.usual(key, in: table, for: day)
                if let x = today, let u = usual {
                    // Lower than usual = more useful to suggest. Score is the robust z (negative = below).
                    score = (x - u.median) / (1.4826 * u.mad) + Double(i) * 0.01
                } else if usual != nil {
                    score = 0 + Double(i) * 0.01
                } else {
                    score = 500 + Double(i)
                }
            }
            let s = SuggestedAction(action: a, todayValue: today, usual: usual)
            if best == nil || score < best!.score { best = (score, s) }
        }
        return best?.s
    }
}

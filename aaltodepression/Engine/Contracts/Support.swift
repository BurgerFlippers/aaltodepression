import Foundation

/// Practical help the person chooses once. These are not diagnoses or inferred needs.
nonisolated enum SupportTopic: String, Codable, Sendable, CaseIterable, Identifiable {
    case groceries, pharmacy, cleaning, social
    var id: String { rawValue }
    var title: String {
        switch self { case .groceries: "Grocery shopping"; case .pharmacy: "Pharmacy visits"; case .cleaning: "Home cleaning"; case .social: "Social contact" }
    }
    var helpKind: HelpKind {
        switch self { case .groceries: .groceryRun; case .pharmacy: .pharmacyRun; case .cleaning: .homeCleaning; case .social: .doSomethingFun }
    }
}

nonisolated struct SupportPreferences: Codable, Sendable, Equatable {
    var personID: String = ""
    var topics: Set<SupportTopic> = Set(SupportTopic.allCases)
    /// Used by the explicit automatic-message demo, not by missing-checkmark rules.
    var automaticDemo = false
    /// Who could help with each topic, keyed by `SupportTopic.rawValue`. Falls back to `personID`.
    var topicPeople: [String: String] = [:]

    func person(for topic: SupportTopic) -> String { topicPeople[topic.rawValue] ?? personID }
}

nonisolated extension SupportPreferences {
    // Older saved preferences have no `topicPeople`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        personID = try c.decodeIfPresent(String.self, forKey: .personID) ?? ""
        topics = try c.decodeIfPresent(Set<SupportTopic>.self, forKey: .topics) ?? Set(SupportTopic.allCases)
        automaticDemo = try c.decodeIfPresent(Bool.self, forKey: .automaticDemo) ?? false
        topicPeople = try c.decodeIfPresent([String: String].self, forKey: .topicPeople) ?? [:]
    }
}

nonisolated struct ReachOutPrompt: Sendable, Identifiable, Equatable {
    let pillar: Pillar
    let topic: SupportTopic
    let contact: Contact?
    let title: String
    let explanation: String
    var id: String { "reachout|\(pillar.rawValue)" }
}

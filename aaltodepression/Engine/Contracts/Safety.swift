import Foundation

/// The C-SSRS screener questions (past month), in the order they can be asked.
nonisolated enum SafetyQuestion: String, Codable, Sendable, CaseIterable {
    case wishDead            // Q1
    case suicidalThoughts    // Q2
    case method              // Q3
    case intent              // Q4
    case plan                // Q5
    case behavior            // Q6
    case behaviorRecent      // Q6 follow-up: within the past 3 months
}

/// Where the answers lead. Never shown as a risk level; each maps to a help screen.
nonisolated enum SafetyOutcome: String, Codable, Sendable {
    /// No thoughts of suicide: thank, offer something small.
    case noThoughts
    /// Passive or non-specific thoughts: talk to your care team within a day.
    case talkSoon
    /// Thoughts with a method, or past behaviour: contact care today.
    case contactCareToday
    /// Intent, a plan or recent behaviour: get help now (112 first).
    case urgent
}

nonisolated enum SafetyStep: Sendable, Equatable {
    /// "Thank you for telling us. We ask everyone this on a heavy day."
    case bridge
    case ask(SafetyQuestion)
    case done(SafetyOutcome)
}

nonisolated struct CrisisLine: Sendable, Identifiable, Equatable {
    let name: String
    let number: String
    let note: String
    var id: String { number }
}

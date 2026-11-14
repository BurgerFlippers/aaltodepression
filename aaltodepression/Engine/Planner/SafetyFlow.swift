import Foundation

/// The C-SSRS screener as a small state machine. Order and branching follow the screener:
/// Q1 and Q2 always; Q3–Q5 only if Q2 is yes; Q6 always; Q6 follow-up only if Q6 is yes.
/// The data can make the planner ask earlier; it never answers, skips or scores anything.
nonisolated struct SafetyFlow: Sendable, Equatable {
    private(set) var step: SafetyStep = .bridge
    private(set) var answers: [SafetyQuestion: Bool] = [:]

    init() {}

    /// From the bridge screen to the first question.
    mutating func begin() {
        guard step == .bridge else { return }
        step = .ask(.wishDead)
    }

    mutating func answer(_ yes: Bool) {
        guard case .ask(let q) = step else { return }
        answers[q] = yes
        step = Self.next(after: q, answers: answers)
    }

    var outcome: SafetyOutcome? {
        if case .done(let o) = step { return o }
        return nil
    }

    static func next(after q: SafetyQuestion, answers: [SafetyQuestion: Bool]) -> SafetyStep {
        switch q {
        case .wishDead: return .ask(.suicidalThoughts)
        case .suicidalThoughts: return answers[q] == true ? .ask(.method) : .ask(.behavior)
        case .method: return .ask(.intent)
        case .intent: return .ask(.plan)
        case .plan: return .ask(.behavior)
        case .behavior: return answers[q] == true ? .ask(.behaviorRecent) : .done(outcome(answers))
        case .behaviorRecent: return .done(outcome(answers))
        }
    }

    /// The screener's usual triage, mapped to help screens. Never shown as a level.
    static func outcome(_ a: [SafetyQuestion: Bool]) -> SafetyOutcome {
        if a[.intent] == true || a[.plan] == true || (a[.behavior] == true && a[.behaviorRecent] == true) { return .urgent }
        if a[.method] == true || a[.behavior] == true { return .contactCareToday }
        if a[.wishDead] == true || a[.suicidalThoughts] == true { return .talkSoon }
        return .noThoughts
    }
}

/// Words for the safety flow.
/// WORKING DRAFT: English wording follows the public C-SSRS screener. A clinician must review all
/// of this, and phone numbers and opening hours must be checked, before anyone real uses it.
nonisolated enum SafetyCopy {
    static let reviewedByClinician = false

    static let bridgeTitle = "Thank you for telling us."
    static let bridgeBody = "We ask everyone a few questions on a heavy day. Your answers stay on this phone."
    static let dataNote = "Phone data cannot tell what you are thinking. That is why we ask."
    static let timeframe = "In the past month:"

    static func text(_ q: SafetyQuestion) -> String {
        switch q {
        case .wishDead: "Have you wished you were dead or wished you could go to sleep and not wake up?"
        case .suicidalThoughts: "Have you actually had any thoughts of killing yourself?"
        case .method: "Have you been thinking about how you might do this?"
        case .intent: "Have you had these thoughts and had some intention of acting on them?"
        case .plan: "Have you started to work out or worked out the details of how to kill yourself? Do you intend to carry out this plan?"
        case .behavior: "Have you ever done anything, started to do anything, or prepared to do anything to end your life?"
        case .behaviorRecent: "Was this within the past three months?"
        }
    }

    static func title(_ o: SafetyOutcome) -> String {
        switch o {
        case .noThoughts: "Thank you for answering."
        case .talkSoon: "Thank you for telling us. Thoughts like these are worth talking about."
        case .contactCareToday: "Please contact your care team today."
        case .urgent: "Get help now. You don't have to be alone with this."
        }
    }

    static func body(_ o: SafetyOutcome, clinic: String) -> String {
        let place = clinic.isEmpty ? "your care team" : clinic
        switch o {
        case .noThoughts:
            return "Today can stay light. A minute of slow breathing or ten minutes outside might help."
        case .talkSoon:
            return "Please get in touch with \(place) within the next day. You can also call the crisis helpline any time."
        case .contactCareToday:
            return "Call \(place) today. If you can't reach them, call the medical helpline 116 117 or the crisis helpline."
        case .urgent:
            return "Call 112 now. Ask someone to come and be with you, and move anything you could hurt yourself with out of reach."
        }
    }

    /// Finland. Check numbers and hours before any real use.
    static let lines: [CrisisLine] = [
        .init(name: "Emergency", number: "112", note: "Always, when life is in danger"),
        .init(name: "MIELI Crisis Helpline (Finnish)", number: "09 2525 0111", note: "24/7"),
        .init(name: "MIELI Crisis Helpline (Swedish)", number: "09 2525 0112", note: "Limited hours"),
        .init(name: "MIELI Crisis Helpline (English)", number: "09 2525 0116", note: "Limited hours"),
        .init(name: "Medical helpline", number: "116 117", note: "Out-of-hours advice and emergency duty"),
    ]

    /// Lines to show for an outcome, most urgent first.
    static func lines(for o: SafetyOutcome) -> [CrisisLine] {
        switch o {
        case .urgent: lines
        case .contactCareToday: [lines[4], lines[1], lines[0]]
        case .talkSoon, .noThoughts: [lines[1], lines[0]]
        }
    }
}

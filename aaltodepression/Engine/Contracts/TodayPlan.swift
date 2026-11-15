import Foundation

nonisolated enum ItemSize: Int, Codable, Sendable, Comparable {
    case tiny = 0, small = 1, normal = 2
    static func < (a: ItemSize, b: ItemSize) -> Bool { a.rawValue < b.rawValue }

    var smaller: ItemSize? { ItemSize(rawValue: rawValue - 1) }
}

nonisolated enum ItemStatus: String, Codable, Sendable {
    case open, done, skipped
}

/// Who marked an item done. Sensors and Health mean the person did not have to tap anything.
nonisolated enum DoneBy: String, Codable, Sendable {
    case person, sensors, health
}

/// One row on today's list.
nonisolated struct PlanItem: Codable, Sendable, Identifiable, Equatable {
    /// Stable for the day, e.g. "2461334|meds|m1|480".
    let id: String
    let pillar: Pillar
    var title: String
    var detail: String?
    var size: ItemSize
    /// Minutes after midnight, if the item belongs to a time.
    var time: Int?
    var status: ItemStatus = .open
    var doneBy: DoneBy?
    /// Plain words for what confirmed it, e.g. "Your phone saw a 15-minute walk".
    var evidence: String?
    /// The person can swipe it smaller ("Make it smaller").
    var canShrink: Bool = false
    /// Grocery list attached to a shopping item.
    var groceries: [GroceryItem]? = nil
}

nonisolated enum PlateGroup: String, Codable, Sendable, CaseIterable {
    case vegetables, protein, carbs, staples

    var title: String {
        switch self {
        case .vegetables: "Vegetables, fruit and berries (half the plate)"
        case .protein: "Protein (a quarter)"
        case .carbs: "Whole grains and potatoes (a quarter)"
        case .staples: "Cupboard basics"
        }
    }
}

nonisolated struct GroceryItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    var name: String
    var group: PlateGroup
    var id: String { "\(group.rawValue)|\(name)" }
}

/// A suggestion that goes to a close person. In the prototype it is never really sent.
nonisolated struct ContactSuggestion: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let contact: Contact
    let kind: HelpKind
    /// What the contact would receive. Never mentions health.
    let message: String
    /// What the person sees: why now, in plain words.
    let reason: String
    let day: Day
}

nonisolated struct SocialSuggestion: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let contact: Contact?
    let activity: String
    /// Draft the person can send themselves.
    let message: String
    let suggestedDay: Day
    let reason: String
}

nonisolated struct ClinicNudge: Codable, Sendable, Equatable {
    let reason: String
    let clinicName: String
    let phone: String
}

/// One situation card on Today. The screen shows the first one only.
nonisolated enum Card: Codable, Sendable, Identifiable, Equatable {
    /// Ask the safety questions now (opens the safety flow, never answered from a notification).
    case safetyCheck
    /// Signs worth telling the clinic about.
    case clinic(ClinicNudge)
    /// Food or shopping did not happen: a close person gets a concrete suggestion.
    case askForHelp(ContactSuggestion)
    /// Several harder days in the data: a close person is told a call would be welcome.
    case callSignal(ContactSuggestion)
    /// Good stretch: plan something nice with someone.
    case social(SocialSuggestion)

    var id: String {
        switch self {
        case .safetyCheck: "safety"
        case .clinic: "clinic"
        case .askForHelp(let s): "help|\(s.id)"
        case .callSignal(let s): "call|\(s.id)"
        case .social(let s): "social|\(s.id)"
        }
    }
}

/// The reward for one day: a thread for each pillar touched. Nothing is ever taken away.
nonisolated struct DayReward: Codable, Sendable, Equatable {
    let day: Day
    /// Pillars with at least one done item.
    let threads: Set<Pillar>
    /// The check-in itself counts as a thread.
    let checkedIn: Bool
    /// All four basics done (food, movement, sleep, medication when there is any).
    let star: Bool
    /// Asking for help, receiving help or meeting someone ties a gold knot.
    let goldKnots: Int
    /// A short line to celebrate, or nil.
    let message: String?
}

/// Everything Today needs, worked out by `TodayBuilder`.
nonisolated struct TodayPlan: Sendable, Equatable {
    let day: Day
    let capacity: Capacity
    let headline: String
    let items: [PlanItem]
    let cards: [Card]
    let needsCheckIn: Bool
    /// Ask "Did you get to the shop?" today.
    let asksAboutGroceries: Bool
    /// Ask the optional screen-time questions (QuestionCatalog.screenTimeQuestions) about yesterday.
    var asksAboutScreenTime: Bool = false
    /// A plan with someone from the last three days to ask "Did you get to meet?" about (answerSocial).
    var asksAboutSocial: SocialPlan? = nil
    /// Coming plans with someone, soonest first.
    var upcomingPlans: [SocialPlan] = []
    let reward: DayReward
    /// Things the planner has learned about this person, shown in plain words.
    let insights: [String]
    var reachOutPrompt: ReachOutPrompt? = nil
}

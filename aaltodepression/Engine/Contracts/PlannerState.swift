import Foundation

/// A tap on a plan item, kept by item id.
nonisolated struct ItemMark: Codable, Sendable, Equatable {
    /// Nil when the person only changed the size; then sensors can still confirm the item.
    var status: ItemStatus?
    var at: Date
    /// Set when the person made the item smaller.
    var size: ItemSize?
}

nonisolated enum MessageStatus: String, Codable, Sendable {
    /// Waiting for the person's tap (askEachTime) or for the 08–20 window.
    case pending
    case sent
    /// The contact answered (simulated in the prototype).
    case replied
    case cancelled
}

/// A message to a close person. In the prototype nothing leaves the phone.
nonisolated struct OutgoingMessage: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var day: Day
    var createdAt: Date
    var contactID: String
    var contactName: String
    var kind: HelpKind
    var text: String
    var status: MessageStatus
    var simulatedReply: String?
    /// askEachTime: the person tapped Send outside 08–20; it goes out when the window opens.
    var confirmed: Bool?
}

/// Something nice planned with someone during a good stretch.
nonisolated struct SocialPlan: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var day: Day
    var contactName: String?
    var activity: String
    /// Asked the day after: nil until answered.
    var met: Bool?
}

/// Everything the planner remembers. Stored as one JSON file on the phone.
nonisolated struct PlannerState: Codable, Sendable, Equatable {
    var setup: PlannerSetup
    /// Check-ins by Julian day number.
    var checkIns: [Int: CheckIn] = [:]
    /// Taps on plan items by item id.
    var marks: [String: ItemMark] = [:]
    var outbox: [OutgoingMessage] = []
    var socialPlans: [SocialPlan] = []
    /// Days the social card was offered (shown or dismissed), by Julian day number.
    var socialOfferedDays: Set<Int> = []
    /// Days the safety questions were asked. The answers themselves are not kept.
    var safetyAskedDays: Set<Int> = []
    /// Cards the person closed with "Not now", by card id → Julian day.
    var dismissedCards: [String: Int] = [:]
    /// Last day each chore was done, by chore id → Julian day.
    var choreDone: [String: Int] = [:]
    /// "Did you get to the shop today?" answers by Julian day. Kept apart from the check-in,
    /// so answering from a notification never stands in for how the person feels.
    var groceryAnswers: [Int: Bool] = [:]
    /// Days the safety questions led to "talk soon" or more. Only the day is kept, never the answers;
    /// it keeps that day's list light.
    var heavySafetyDays: Set<Int> = []
    /// Each day's reward as it grew. Rows only ever gain threads; nothing is unpicked later.
    var rewards: [Int: DayReward] = [:]
    /// Every answer given (check-in, shop question, follow-ups), newest last. Never safety answers.
    var answerLog: [AnswerRecord] = []
    /// Screen time the person reported, by the Julian day it is about (usually yesterday).
    var screenTime: [Int: ScreenTimeReport] = [:]

    init(setup: PlannerSetup) { self.setup = setup }

    func checkIn(on day: Day) -> CheckIn? { checkIns[day.jdn] }

    // Tolerant decoding: fields added later are simply empty in older files.
    enum CodingKeys: String, CodingKey {
        case setup, checkIns, marks, outbox, socialPlans, socialOfferedDays, safetyAskedDays, dismissedCards
        case choreDone, groceryAnswers, heavySafetyDays, rewards, answerLog, screenTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        setup = try c.decode(PlannerSetup.self, forKey: .setup)
        checkIns = try c.decodeIfPresent([Int: CheckIn].self, forKey: .checkIns) ?? [:]
        marks = try c.decodeIfPresent([String: ItemMark].self, forKey: .marks) ?? [:]
        outbox = try c.decodeIfPresent([OutgoingMessage].self, forKey: .outbox) ?? []
        socialPlans = try c.decodeIfPresent([SocialPlan].self, forKey: .socialPlans) ?? []
        socialOfferedDays = try c.decodeIfPresent(Set<Int>.self, forKey: .socialOfferedDays) ?? []
        safetyAskedDays = try c.decodeIfPresent(Set<Int>.self, forKey: .safetyAskedDays) ?? []
        dismissedCards = try c.decodeIfPresent([String: Int].self, forKey: .dismissedCards) ?? [:]
        choreDone = try c.decodeIfPresent([String: Int].self, forKey: .choreDone) ?? [:]
        groceryAnswers = try c.decodeIfPresent([Int: Bool].self, forKey: .groceryAnswers) ?? [:]
        heavySafetyDays = try c.decodeIfPresent(Set<Int>.self, forKey: .heavySafetyDays) ?? []
        rewards = try c.decodeIfPresent([Int: DayReward].self, forKey: .rewards) ?? [:]
        answerLog = try c.decodeIfPresent([AnswerRecord].self, forKey: .answerLog) ?? []
        screenTime = try c.decodeIfPresent([Int: ScreenTimeReport].self, forKey: .screenTime) ?? [:]
    }
}

/// One day's screen time as the person reported it.
nonisolated struct ScreenTimeReport: Codable, Sendable, Equatable {
    var hours: Double
    /// Used the phone in bed after lights out; nil if not answered.
    var phoneInBed: Bool?
    /// True when typed exactly from iOS Settings → Screen Time, false for a rough range.
    var exact: Bool
}

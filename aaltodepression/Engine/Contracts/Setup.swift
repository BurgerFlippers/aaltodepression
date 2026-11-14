import Foundation

/// Who the person is to the contact. Used only for wording.
nonisolated enum Relation: String, Codable, Sendable, CaseIterable, Identifiable {
    case parent, sibling, partner, friend, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .parent: "Parent"
        case .sibling: "Sibling"
        case .partner: "Partner"
        case .friend: "Friend"
        case .other: "Someone close"
        }
    }
}

/// What a contact can be asked to do.
nonisolated enum HelpKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case inviteToEat, groceryRun, shopTogether, call, doSomethingFun, pharmacyRun, homeCleaning
    var id: String { rawValue }

    var title: String {
        switch self {
        case .inviteToEat: "Invite them to eat"
        case .groceryRun: "Pick up a few groceries"
        case .shopTogether: "Go shopping together"
        case .call: "Give them a call"
        case .doSomethingFun: "Do something nice together"
        case .pharmacyRun: "Help with a pharmacy visit"
        case .homeCleaning: "Help with cleaning at home"
        }
    }
}

/// A close person the planner may send a suggestion to.
nonisolated struct Contact: Codable, Sendable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var phone: String
    var relation: Relation
    var canHelpWith: Set<HelpKind>
    /// The contact has said yes to getting suggestions. Only agreed contacts are messaged.
    var agreed: Bool = true
}

nonisolated struct Medication: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var name: String
    /// Dose times in minutes after midnight, e.g. 480 = 08:00.
    var times: [Int]
}

/// A must-do that comes back every few days: laundry, bills, cleaning.
nonisolated struct Chore: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var title: String
    var everyDays: Int
}

/// How suggestions to contacts go out.
nonisolated enum HelpConsent: String, Codable, Sendable, CaseIterable {
    /// The suggestion goes out right away; the person sees it and can cancel within a few minutes.
    case sendRightAway
    /// The person confirms every suggestion with one tap.
    case askEachTime
}

/// Everything the person sets once in onboarding and can change in Settings.
nonisolated struct PlannerSetup: Codable, Sendable, Equatable {
    var personName: String
    /// Minutes after midnight.
    var wakeTime: Int = 7 * 60
    var bedtime: Int = 22 * 60 + 30
    var checkInTime: Int = 7 * 60 + 30
    /// ISO weekdays (1 = Monday) when the person usually shops.
    var shoppingWeekdays: Set<Int> = [2, 6]
    var contacts: [Contact] = []
    var medications: [Medication] = []
    var chores: [Chore] = []
    var helpConsent: HelpConsent = .sendRightAway
    var supportPreferences: SupportPreferences? = nil
    var clinicName: String = ""
    var clinicPhone: String = ""
    /// Small things that usually feel good, picked in onboarding (behavioural activation seeds).
    var goodThings: [String] = []
    /// Ask "How long on your phone yesterday?" in the morning (bonus, optional).
    var asksScreenTime: Bool = true

    /// Minutes before bedtime when the wind-down starts.
    var windDownLead: Int = 45
    var windDownTime: Int { (bedtime - windDownLead + 1440) % 1440 }

    init(personName: String, wakeTime: Int = 7 * 60, bedtime: Int = 22 * 60 + 30, checkInTime: Int = 7 * 60 + 30,
         shoppingWeekdays: Set<Int> = [2, 6], contacts: [Contact] = [], medications: [Medication] = [], chores: [Chore] = [],
         helpConsent: HelpConsent = .sendRightAway, clinicName: String = "", clinicPhone: String = "",
         goodThings: [String] = [], asksScreenTime: Bool = true, windDownLead: Int = 45, supportPreferences: SupportPreferences? = nil) {
        self.personName = personName; self.wakeTime = wakeTime; self.bedtime = bedtime; self.checkInTime = checkInTime
        self.shoppingWeekdays = shoppingWeekdays; self.contacts = contacts; self.medications = medications; self.chores = chores
        self.supportPreferences = supportPreferences
        self.helpConsent = helpConsent; self.clinicName = clinicName; self.clinicPhone = clinicPhone
        self.goodThings = goodThings; self.asksScreenTime = asksScreenTime; self.windDownLead = windDownLead
    }

    // Tolerant decoding: a field added later gets its default instead of wiping the saved setup.
    enum CodingKeys: String, CodingKey {
        case personName, wakeTime, bedtime, checkInTime, shoppingWeekdays, contacts, medications, chores
        case helpConsent, clinicName, clinicPhone, goodThings, asksScreenTime, windDownLead, supportPreferences
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PlannerSetup(personName: "")
        personName = try c.decodeIfPresent(String.self, forKey: .personName) ?? d.personName
        wakeTime = try c.decodeIfPresent(Int.self, forKey: .wakeTime) ?? d.wakeTime
        bedtime = try c.decodeIfPresent(Int.self, forKey: .bedtime) ?? d.bedtime
        checkInTime = try c.decodeIfPresent(Int.self, forKey: .checkInTime) ?? d.checkInTime
        shoppingWeekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .shoppingWeekdays) ?? d.shoppingWeekdays
        contacts = try c.decodeIfPresent([Contact].self, forKey: .contacts) ?? []
        medications = try c.decodeIfPresent([Medication].self, forKey: .medications) ?? []
        chores = try c.decodeIfPresent([Chore].self, forKey: .chores) ?? []
        supportPreferences = try c.decodeIfPresent(SupportPreferences.self, forKey: .supportPreferences)
        helpConsent = try c.decodeIfPresent(HelpConsent.self, forKey: .helpConsent) ?? d.helpConsent
        clinicName = try c.decodeIfPresent(String.self, forKey: .clinicName) ?? ""
        clinicPhone = try c.decodeIfPresent(String.self, forKey: .clinicPhone) ?? ""
        goodThings = try c.decodeIfPresent([String].self, forKey: .goodThings) ?? []
        asksScreenTime = try c.decodeIfPresent(Bool.self, forKey: .asksScreenTime) ?? d.asksScreenTime
        windDownLead = try c.decodeIfPresent(Int.self, forKey: .windDownLead) ?? d.windDownLead
    }
}

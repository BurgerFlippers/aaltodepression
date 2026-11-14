import Foundation

nonisolated enum NetworkRole: String, Codable, CaseIterable, Identifiable {
    case close = "Lähimmäinen"
    case friend = "Ystävä"
    var id: String { rawValue }
    var title: String { self == .close ? "Loved one" : "Friend" }
    var explanation: String {
        self == .close ? "Practical help with food, groceries and home." : "Company for walks, coffee and everyday moments."
    }
}

nonisolated struct EverydayPerson: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var phone: String
    var role: NetworkRole = .friend
}

nonisolated struct EverydayProfile: Codable {
    var name = ""
    var gender = "Prefer not to say"
    var age = ""
    var weight = ""
    var height = ""
    var usesMedication = false
    var medicationHour = 8
    var wakeHour = 8
    var bedtimeHour = 22
    var wakeMinute: Int? = nil
    var bedtimeMinute: Int? = nil
    var medicationMinute: Int? = nil
}

nonisolated enum EverydayTaskKind: String, Codable, CaseIterable, Identifiable {
    case food, movement, medication, sleep
    var id: String { rawValue }
    var title: String {
        switch self {
        case .food: "Something simple to eat"
        case .movement: "A little movement"
        case .medication: "Your medication, your instructions"
        case .sleep: "Rest and sleep"
        }
    }
    var category: String {
        switch self { case .food: "Food"; case .movement: "Movement"; case .medication: "Medication"; case .sleep: "Sleep" }
    }
    var symbol: String {
        switch self { case .food: "fork.knife"; case .movement: "figure.walk"; case .medication: "pills"; case .sleep: "moon.stars" }
    }
    var detail: String {
        switch self {
        case .food: "A sandwich, yoghurt and fruit are one easy option. Choose a meal that suits you."
        case .movement: "A few minutes outside, if that works for you. With your permission, your iPhone can notice movement for you."
        case .medication: "Follow your own medication instructions. Only mark this as taken if you have taken it as instructed."
        case .sleep: "Make a little room for rest. Sleep recorded in Apple Health can appear here automatically. Phone inactivity alone does not confirm sleep."
        }
    }
}

nonisolated enum HouseholdKind: String, Codable, CaseIterable, Identifiable {
    case groceries, laundry
    var id: String { rawValue }
    var question: String { self == .groceries ? "Do you have food for tomorrow?" : "Do you have clean clothes for the next few days?" }
    var label: String { self == .groceries ? "Food at home" : "Clean clothes" }
    var interval: TimeInterval { self == .groceries ? 3 * 86400 : 7 * 86400 }
}

nonisolated struct HouseholdAnswer: Codable {
    var date: Date
    var needsHelp: Bool
}

nonisolated struct SupportDraft: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date = Date()
    var personID: String
    var reason: HouseholdKind
    var text: String
}

nonisolated struct EverydayState: Codable {
    var completedSetup = false
    var profile = EverydayProfile()
    var people: [EverydayPerson] = []
    var taskDay = ""
    var completed: Set<EverydayTaskKind> = []
    var deferred: Set<EverydayTaskKind> = []
    var household: [String: HouseholdAnswer] = [:]
    var supportDemoEnabled = false
    var supportDrafts: [SupportDraft] = []
    var motionEnabled: Bool? = nil
    var healthSleepEnabled: Bool? = nil
    var movementReading: EverydayMovementReading? = nil
    var sleepReading: EverydaySleepReading? = nil
    var ignoredMovementDay: String? = nil
    var ignoredSleepDay: String? = nil
}

nonisolated struct EverydayMovementReading: Codable, Sendable {
    var date: Date
    var steps: Int
}

nonisolated struct EverydaySleepReading: Codable, Sendable {
    var start: Date
    var end: Date
    var minutes: Int
}

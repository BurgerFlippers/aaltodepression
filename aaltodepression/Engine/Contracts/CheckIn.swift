import Foundation

// Contract between the planner engine (backend) and the screens (frontend).
// Additive changes only: new fields get defaults, nothing is renamed or removed without agreement.

/// The six things the planner keeps an eye on.
nonisolated enum Pillar: String, Codable, Sendable, CaseIterable, Identifiable {
    case food, movement, sleep, social, meds, chores

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food"
        case .movement: "Movement"
        case .sleep: "Sleep"
        case .social: "People"
        case .meds: "Medication"
        case .chores: "Must-dos"
        }
    }

    /// The four basics a doctor asked the app to support every day.
    static let basics: [Pillar] = [.food, .movement, .sleep, .meds]
}

/// Words the person can tap in the check-in. Several can be picked.
nonisolated enum Feeling: String, Codable, Sendable, CaseIterable, Identifiable {
    case calm, good, tired, low, anxious

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .good: "Good"
        case .tired: "Tired"
        case .low: "Low"
        case .anxious: "Anxious or restless"
        }
    }
}

/// "How is your energy today?"
nonisolated enum Energy: Int, Codable, Sendable, CaseIterable, Comparable, Identifiable {
    case low = 1, some = 2, plenty = 3

    var id: Int { rawValue }
    static func < (a: Energy, b: Energy) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .low: "Not much"
        case .some: "Some"
        case .plenty: "Plenty"
        }
    }
}

/// "Is there food at home for the next couple of days?"
nonisolated enum FoodAtHome: String, Codable, Sendable, CaseIterable, Identifiable {
    case enough, runningLow, empty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .enough: "Yes, enough"
        case .runningLow: "Running low"
        case .empty: "Hardly anything"
        }
    }
}

/// The daily check-in. About 15 seconds of taps, no typing.
nonisolated struct CheckIn: Codable, Sendable, Equatable {
    var day: Day
    var at: Date
    /// 1 = very bad ... 5 = very good.
    var mood: Int
    var energy: Energy
    var feelings: Set<Feeling> = []
    var foodAtHome: FoodAtHome?

    init(day: Day, at: Date, mood: Int, energy: Energy, feelings: Set<Feeling> = [], foodAtHome: FoodAtHome? = nil) {
        self.day = day; self.at = at; self.mood = min(5, max(1, mood)); self.energy = energy
        self.feelings = feelings; self.foodAtHome = foodAtHome
    }
}

/// How much the day can hold. Never shown as a number or a label of the person.
nonisolated enum Capacity: Int, Codable, Sendable, Comparable {
    case low = 0, ok = 1, good = 2
    static func < (a: Capacity, b: Capacity) -> Bool { a.rawValue < b.rawValue }
}

extension Day {
    /// ISO weekday: 1 = Monday ... 7 = Sunday. Julian day 0 was a Monday.
    nonisolated var isoWeekday: Int { ((jdn % 7) + 7) % 7 + 1 }
}

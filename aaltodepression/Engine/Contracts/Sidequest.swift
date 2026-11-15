import Foundation

nonisolated enum SidequestCategory: String, Codable, Sendable {
    case sleep, movement, nutrition, social, medicine
    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .movement: "Move"
        case .nutrition: "Eat"
        case .social: "Social"
        case .medicine: "Medicine"
        }
    }
}

nonisolated struct SidequestVersion: Codable, Equatable, Sendable {
    var title: String
    var instruction: String
    var minutes: Int
}

nonisolated struct Sidequest: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var category: SidequestCategory
    var regular: SidequestVersion
    var smaller: SidequestVersion

    var canInvite: Bool {
        category == .social || ["food-favour", "shared-meal", "pharmacy-company", "walk-talk", "colour-walk", "park-explorer", "new-view"].contains(id)
    }

    var invitation: String {
        switch id {
        case "tea-invite": "Fancy a short visit or a cup of tea together? No big plans needed."
        case "food-favour", "shared-meal": "Would you like to have something easy to eat together? A ready meal is fine."
        case "pharmacy-company": "Could you keep me company on a pharmacy visit?"
        case "thank-person": "Thanks for being there. I appreciate you."
        case "send-photo": "I noticed this and thought of you. How are you doing?"
        case "voice-hello": "Hey, just wanted to say hello. How is your day going?"
        case "send-song": "This song made me think of you. How are you doing?"
        case "walk-talk", "colour-walk", "park-explorer", "new-view": "Fancy a short walk or a catch-up together? We can keep it easy."
        default: "Fancy a quick catch-up? It would be nice to hear from you."
        }
    }
}

/// A frozen daily offer. Separate from routine marks, Health scores and support decisions.
nonisolated struct SidequestDay: Codable, Equatable, Sendable {
    var options: [Sidequest]
    var reason: String
    var signalDay: Day?
    var startsSmall: Bool
    var selectedID: String?
    var useSmaller = false
    var startedAt: Date?
    var completedAt: Date?
    var reminderAt: Date?
    var selectionReadings: [String: Double]?
    /// Extra options marked done after the chosen one was completed. Optional so older saved days still decode.
    var alsoDoneIDs: [String]?

    var progress: SidequestProgress {
        guard selected != nil else { return .notSelected }
        if completedAt != nil { return .completed }
        return startedAt == nil ? .selected : .inProgress
    }

    var selected: Sidequest? { options.first { $0.id == selectedID } }
    var version: SidequestVersion? { selected.map { useSmaller ? $0.smaller : $0.regular } }

    mutating func choose(_ id: String) {
        guard completedAt == nil, options.contains(where: { $0.id == id }) else { return }
        selectedID = id
        useSmaller = startsSmall
    }

    mutating func makeSmaller() {
        guard selected != nil, completedAt == nil else { return }
        useSmaller = true
    }

    @discardableResult mutating func start(at date: Date) -> Bool {
        guard selected != nil, startedAt == nil, completedAt == nil else { return false }
        startedAt = date
        return true
    }

    @discardableResult mutating func complete(at date: Date) -> Bool {
        guard selected != nil, completedAt == nil else { return false }
        if startedAt == nil { startedAt = date }
        completedAt = date
        return true
    }

    func isDone(_ id: String) -> Bool { (id == selectedID && completedAt != nil) || (alsoDoneIDs ?? []).contains(id) }

    /// Doing more is optional: only after the chosen option is done, once per option.
    @discardableResult mutating func completeAnother(_ id: String) -> Bool {
        guard completedAt != nil, id != selectedID, options.contains(where: { $0.id == id }), !isDone(id) else { return false }
        alsoDoneIDs = (alsoDoneIDs ?? []) + [id]
        return true
    }
}

nonisolated enum SidequestProgress: String, Sendable {
    case notSelected, selected, inProgress, completed
    var title: String {
        switch self {
        case .notSelected: "Not selected"
        case .selected: "Selected · not started"
        case .inProgress: "In progress"
        case .completed: "Completed"
        }
    }
}

import Foundation

/// Texts that go to close people. They ask for something concrete and never say why:
/// no health words, no mood, no "the app noticed".
nonisolated enum MessageTemplates {
    static func help(_ kind: HelpKind, contact: Contact, person: String, groceries: [GroceryItem] = []) -> String {
        switch kind {
        case .inviteToEat:
            return "Hi \(contact.name)! \(person) would love some company today. Could you invite them over to eat, or bring something to share? (Sent at \(person)'s request.)"
        case .groceryRun:
            let list = groceries.prefix(6).map(\.name).joined(separator: ", ")
            let tail = list.isEmpty ? "" : " A few basics would do: \(list)."
            return "Hi \(contact.name)! Could you pick up a few groceries for \(person) on your way home today?\(tail) (Sent at \(person)'s request.)"
        case .shopTogether:
            return "Hi \(contact.name)! Would you go grocery shopping with \(person) today or tomorrow? Company would be nice. (Sent at \(person)'s request.)"
        case .call:
            return "Hi \(contact.name)! \(person) would be glad to hear from you. A call this evening would suit well. (Sent at \(person)'s request.)"
        case .doSomethingFun:
            return "Hi \(contact.name)! Fancy doing something together this week? A walk, a coffee or a film? – \(person)"
        }
    }

    static func social(activity: String, contact: Contact?, day: Day, today: Day) -> String {
        let when = day == today ? "today" : day == today + 1 ? "tomorrow" : weekdayName(day)
        let hi = contact.map { "Hi \($0.name)! " } ?? "Hi! "
        return "\(hi)Would you like to \(activity) \(when)? Around 3 or 5 pm could work."
    }

    /// Simulated replies for the demo. Kind and warm, never about health.
    static func simulatedReply(_ kind: HelpKind) -> String {
        switch kind {
        case .inviteToEat: "Of course! Come over at six, I'm making soup."
        case .groceryRun: "Sure! I'll bring them by after six and we can eat together."
        case .shopTogether: "Yes, let's go tomorrow after work. I'll pick you up."
        case .call: "I'll call you tonight!"
        case .doSomethingFun: "Sounds great, let's do it!"
        }
    }

    static func weekdayName(_ day: Day) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day.isoWeekday - 1]
    }
}

/// Last line of defence: a message to a contact must not carry health words.
nonisolated enum HealthWordFilter {
    static let blocked = [
        "depress", "tms", "magnetic", "mood", "anxi", "suicid", "self-harm", "kill", "relapse", "mental",
        "therap", "psychiatr", "medic", "diagnos", "not coping", "can't cope", "crisis", "sad", "unwell",
        "symptom", "treatment", "nurse", "clinic", "the app noticed", "data",
    ]

    /// Names are left out of the check, so "Isadora" is not mistaken for "sad".
    static func isClean(_ text: String, ignoring names: [String] = []) -> Bool {
        var t = text.lowercased()
        for n in names where !n.isEmpty { t = t.replacingOccurrences(of: n.lowercased(), with: " ") }
        return !blocked.contains { t.contains($0) }
    }

    /// The text, or nil when it must not be sent.
    static func clean(_ text: String, ignoring names: [String] = []) -> String? {
        isClean(text, ignoring: names) ? text : nil
    }
}

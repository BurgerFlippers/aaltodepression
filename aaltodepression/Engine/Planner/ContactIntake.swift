import Foundation

/// Turns a picked or typed person into a planner contact. The app never reads the address book:
/// the system picker hands over only the people the person picks (name and one phone number).
nonisolated enum ContactIntake {
    /// Sensible first help kinds by relation; the person can change them.
    static func defaultHelp(for r: Relation) -> Set<HelpKind> {
        switch r {
        case .parent: [.inviteToEat, .call]
        case .sibling, .partner: [.inviteToEat, .groceryRun, .shopTogether, .call]
        case .friend: [.call, .doSomethingFun, .shopTogether]
        case .other: [.call]
        }
    }

    /// Country code used for numbers typed in the national form ("040 …"). Finland for the prototype.
    static let defaultCountryCode = "358"

    /// One canonical form, so "040 123 4567", "+358 40 123 4567" and "00358401234567" are the same person.
    static func normalized(_ phone: String) -> String {
        var digits = ""
        var plus = false
        for ch in phone {
            if ch == "+" && digits.isEmpty { plus = true }
            if ch.isASCII && ch.isNumber { digits.append(ch) }
        }
        if plus { return "+" + digits }
        if digits.hasPrefix("00") { return "+" + digits.dropFirst(2) }
        if digits.hasPrefix("0") { return "+" + defaultCountryCode + digits.dropFirst() }
        return digits
    }

    /// A new contact starts as not agreed: in the real app the first message is an invitation.
    static func contact(name: String, phone: String, relation: Relation = .friend) -> Contact {
        Contact(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespaces), phone: phone,
                relation: relation, canHelpWith: defaultHelp(for: relation), agreed: false)
    }

    /// Adds people not already on the list (matched by phone number). Returns how many were added.
    @discardableResult
    static func add(_ picked: [(name: String, phone: String)], to setup: inout PlannerSetup) -> Int {
        var added = 0
        for p in picked where !normalized(p.phone).isEmpty && !p.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let n = normalized(p.phone)
            guard !setup.contacts.contains(where: { normalized($0.phone) == n }) else { continue }
            setup.contacts.append(contact(name: p.name, phone: p.phone))
            added += 1
        }
        return added
    }

    /// What still blocks a contact from getting suggestions, in plain words; nil when ready.
    static func problem(_ c: Contact) -> String? {
        if c.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Add a name." }
        if normalized(c.phone).count < 5 { return "Add a phone number." }
        if c.canHelpWith.isEmpty { return "Pick at least one kind of help." }
        if !c.agreed { return "Waiting for them to agree." }
        return nil
    }
}

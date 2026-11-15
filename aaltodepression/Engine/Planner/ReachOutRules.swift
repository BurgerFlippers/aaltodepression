import Foundation

/// A gentle user-facing invitation after two active days with an unmarked category.
/// Absence of logging never becomes evidence that the person did not eat, sleep or take medicine.
nonisolated enum ReachOutRules {
    static func prompt(_ ctx: PlannerContext) -> ReachOutPrompt? {
        let preferences = ctx.state.setup.supportPreferences ?? SupportPreferences()
        let pairs: [(Pillar, SupportTopic, String)] = [(.food, .groceries, "A hand with meals?"),
            (.meds, .pharmacy, "A hand with a pharmacy visit?"), (.chores, .cleaning, "A little help at home?"),
            (.social, .social, "Some company this week?"), (.movement, .social, "A little company for a walk?"),
            (.sleep, .social, "Would talking to someone help?")]
        for (pillar, topic, title) in pairs where preferences.topics.contains(topic) {
            // A default Medicine box alone does not establish that the person uses medicine.
            if pillar == .meds, ctx.state.setup.medications.isEmpty,
               !ctx.state.marks.contains(where: { entry in
                   let pieces = entry.key.split(separator: "|")
                   return pieces.count > 2 && pieces[1] == Pillar.meds.rawValue && (Int(pieces[0]) ?? Int.max) <= ctx.day.jdn && entry.value.status == .done
               }) { continue }
            let id = "reachout|\(pillar.rawValue)"
            if let dismissed = ctx.state.dismissedCards[id], ctx.day.jdn - dismissed >= 0, ctx.day.jdn - dismissed < 3 { continue }
            let days = [ctx.day - 1, ctx.day - 2]
            guard days.allSatisfy({ active($0, state: ctx.state) && !completed(pillar, on: $0, ctx: ctx) }) else { continue }
            // Completing today's category resolves this prompt immediately.
            guard !completed(pillar, on: ctx.day, ctx: ctx) else { continue }
            let preferred = ctx.state.setup.contacts.first { $0.id == preferences.personID }
            let contact = preferred ?? ctx.state.setup.contacts.first { topic == .social ? $0.relation == .friend : $0.relation != .friend } ?? ctx.state.setup.contacts.first
            return ReachOutPrompt(pillar: pillar, topic: topic, contact: contact, title: title,
                                  explanation: "This category hasn't been marked on two days when you used Beside. You may simply not have logged it. Reaching out is your choice.")
        }
        return nil
    }
    private static func active(_ day: Day, state: PlannerState) -> Bool {
        state.checkIn(on: day) != nil || state.marks.contains { $0.key.hasPrefix("\(day.jdn)|") && $0.value.status == .done }
    }
    private static func completed(_ pillar: Pillar, on day: Day, ctx: PlannerContext) -> Bool {
        let prefix = "\(day.jdn)|\(pillar.rawValue)|"
        let marks = ctx.state.marks.filter { $0.key.hasPrefix(prefix) }
        if marks.contains(where: { $0.value.status == .done }) { return true }
        // A deliberate undo takes precedence over sensor-based completion.
        if marks.contains(where: { $0.value.status != nil }) { return false }
        if pillar == .movement { return (ctx.table.value(F.steps, day) ?? -1) >= 500 }
        if pillar == .sleep { return (ctx.table.value(F.sleepHours, day) ?? -1) > 0 }
        return false
    }

    /// Explicit judging demonstration only. Reuses existing agreement, rate-limit and message rules.
    static func automaticDemo(_ topic: SupportTopic, ctx: PlannerContext) -> ContactSuggestion? {
        guard let preferences = ctx.state.setup.supportPreferences, preferences.automaticDemo,
              preferences.topics.contains(topic) else { return nil }
        var state = ctx.state
        state.setup.contacts = state.setup.contacts.filter { $0.id == preferences.personID }
        state.outbox = state.outbox.filter { $0.day <= ctx.day }
        let demoContext = PlannerContext(day: ctx.day, now: ctx.now, state: state, table: ctx.table, history: Array(ctx.steps.values))
        return InterventionRules.suggestion(demoContext, kinds: [topic.helpKind], reason: "An agreed practical support request, shown in the automatic-message demo.")
    }
}

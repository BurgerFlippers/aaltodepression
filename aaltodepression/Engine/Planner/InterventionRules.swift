import Foundation

/// When the planner steps in. Transparent rules, no model:
/// 1. Safety: "anxious" or the lowest mood opens the safety questions (once a day, never from a notification).
/// 2. Food help: no food at home or no shop today → a close person gets a concrete suggestion.
/// 3. Call signal: harder days in the data or check-ins → a close person hears a call would be welcome.
/// 4. Clinic: early signs in the data are worth telling the care team about (rests a week after "Not now").
/// 5. Social: a good stretch → plan something nice with someone.
nonisolated enum InterventionRules {
    /// Messages go out between these times only (minutes after midnight); later ones wait for the morning.
    static let sendWindow = (8 * 60)...(20 * 60)
    static let maxHelpPerWeek = 2
    static let sameContactGapDays = 3
    static let callSignalGapDays = 3
    static let socialGapDays = 7
    /// After "Not now", the clinic card rests this many days.
    static let clinicRestDays = 7
    /// "Low" without "anxious" asks the safety questions again only after this many days.
    static let lowOnlySafetyGapDays = 3

    static func cards(_ ctx: PlannerContext, capacity: Capacity, items: [PlanItem]) -> [Card] {
        var out: [Card] = []
        if needsSafetyCheck(ctx) { out.append(.safetyCheck) }
        let help = foodHelp(ctx, capacity: capacity)
        if let s = help { out.append(.askForHelp(s)) }
        // One person contacted a day is enough: no call signal next to food help.
        let helpedToday = ctx.state.outbox.contains { $0.day == ctx.day && $0.status != .cancelled }
        if help == nil, !helpedToday, let s = callSignal(ctx) { out.append(.callSignal(s)) }
        if let c = clinicNudge(ctx) { out.append(.clinic(c)) }
        if let s = social(ctx, capacity: capacity) { out.append(.social(s)) }
        return out.filter { card in
            guard let dismissed = ctx.state.dismissedCards[card.id] else { return true }
            if case .clinic = card { return ctx.day.jdn - dismissed >= clinicRestDays }
            return dismissed != ctx.day.jdn
        }
    }

    // MARK: 1. Safety

    /// Data signals that make the planner ask sooner. They never answer or decide anything.
    static func sensitivitySignals(_ ctx: PlannerContext) -> [String] {
        var out: [String] = []
        if shortSleepNights(ctx.table, through: ctx.day) >= 3 { out.append("sleep much shorter than usual for three nights") }
        if (ctx.yesterday?.step ?? .steady) >= .nudge { out.append("days have been off your usual") }
        if let v = ctx.table.value(F.stateOfMindValence, ctx.day), v <= -0.6 { out.append("a very unpleasant State of Mind in Health") }
        return out
    }

    static func needsSafetyCheck(_ ctx: PlannerContext) -> Bool {
        guard let c = ctx.checkIn, !ctx.state.safetyAskedDays.contains(ctx.day.jdn) else { return false }
        if c.feelings.contains(.anxious) || c.mood == 1 { return true }
        // "Low" alone asks only when the data also points the same way, and not every day.
        if c.feelings.contains(.low) || c.mood == 2 {
            let askedRecently = Day.range(ctx.day - (lowOnlySafetyGapDays - 1), ctx.day).contains { ctx.state.safetyAskedDays.contains($0.jdn) }
            return !askedRecently && !sensitivitySignals(ctx).isEmpty
        }
        return false
    }

    // MARK: 4. Clinic

    static func clinicNudge(_ ctx: PlannerContext) -> ClinicNudge? {
        let setup = ctx.state.setup
        guard !setup.clinicPhone.isEmpty else { return nil }
        var reason: String?
        if shortSleepNights(ctx.table, through: ctx.day) >= 3 {
            reason = "Your sleep has changed over the last few nights."
        } else if missedMedicationDays(ctx) >= 2 {
            reason = "Medication hasn't been marked for two days."
        } else if let y = ctx.yesterday, y.step == .reachOut, let since = y.since, ctx.day - since >= 7 {
            reason = "Your days have been different from your usual for a while."
        }
        guard let r = reason else { return nil }
        let who = setup.clinicName.isEmpty ? "Your clinic" : setup.clinicName.capitalizedFirst
        return ClinicNudge(reason: r + " \(who) would be glad to hear how you are doing.",
                           clinicName: setup.clinicName, phone: setup.clinicPhone)
    }

    /// Nights in the last three with sleep more than two of the person's usual spreads below their usual.
    static func shortSleepNights(_ table: FeatureTable, through day: Day) -> Int {
        Day.range(day - 2, day + 1).filter { d in
            guard let h = table.value(F.sleepHours, d), let u = Baseline.usual(F.sleepHours, in: table, for: d) else { return false }
            return h < u.median - 2 * 1.4826 * u.mad
        }.count
    }

    /// Of the last two full days, how many had a medication dose left unmarked (and not logged in Health).
    static func missedMedicationDays(_ ctx: PlannerContext) -> Int {
        let meds = ctx.state.setup.medications
        let perDay = meds.map(\.times.count).reduce(0, +)
        guard perDay > 0 else { return 0 }
        return [ctx.day - 1, ctx.day - 2].filter { d in
            // Only count days the person was using the planner.
            guard ctx.state.checkIn(on: d) != nil else { return false }
            // The same per-dose view as the list: Health confirms the earliest doses, taps the rest.
            let dayCtx = PlannerContext(day: d, now: 23 * 60, state: ctx.state, table: ctx.table, history: [])
            let doses = TodayBuilder.medicationItems(dayCtx).map { TodayBuilder.apply(ctx.state.marks[$0.id], to: $0) }
            return doses.contains { $0.status != .done }
        }.count
    }

    // MARK: 2. Food help

    static func foodHelp(_ ctx: PlannerContext, capacity: Capacity) -> ContactSuggestion? {
        guard let c = ctx.checkIn else { return nil }
        let noShop = ctx.groceriesDone == false
        let noFood = c.foodAtHome == .empty
        guard noShop || noFood || c.foodAtHome == .runningLow && capacity == .low else { return nil }
        let kind: HelpKind = noFood ? .inviteToEat : .groceryRun
        let reason = noFood ? "There's hardly any food at home." : noShop ? "The shop didn't happen today." : "Food is running low and today is heavy."
        return suggestion(ctx, kinds: [kind, .groceryRun, .inviteToEat, .shopTogether], reason: reason,
                          groceries: GroceryPlanner.list(for: .low))
    }

    // MARK: 3. Call signal

    static func callSignal(_ ctx: PlannerContext) -> ContactSuggestion? {
        let step = ctx.yesterday?.step ?? .steady
        let low = CapacityEstimator.lowDays(state: ctx.state, through: ctx.day, days: 4, steps: ctx.steps)
        guard step >= .nudge || low >= 3 else { return nil }
        if let c = ctx.checkIn, c.mood >= 4 { return nil }
        let recent = ctx.state.outbox.contains { $0.kind == .call && $0.status != .cancelled && ctx.day - $0.day < callSignalGapDays }
        guard !recent else { return nil }
        let reason = low >= 3 ? "The last few days have been heavy." : "Your days have been off your usual for a while."
        return suggestion(ctx, kinds: [.call], reason: reason + " A call from someone close might help.")
    }

    // MARK: 5. Social

    static func social(_ ctx: PlannerContext, capacity: Capacity) -> SocialSuggestion? {
        guard capacity == .good, !ctx.heavyDay, (ctx.checkIn?.mood ?? 0) >= 4 else { return nil }
        guard CapacityEstimator.goodStreak(state: ctx.state, through: ctx.day, steps: ctx.steps) >= 3 else { return nil }
        let lastOffer = ctx.state.socialOfferedDays.filter { $0 < ctx.day.jdn }.max()
        if let l = lastOffer, ctx.day.jdn - l < socialGapDays { return nil }
        if ctx.state.socialPlans.contains(where: { $0.day >= ctx.day }) { return nil }
        let contact = rotation(ctx, kinds: [.doSomethingFun, .call, .inviteToEat]).first
        let activities = ["go for a walk", "have a coffee", "see a film", "eat together"]
        let activity = activities[((ctx.day.jdn / 7) % activities.count + activities.count) % activities.count]
        // The lightest coming day: the first of the next three days that is not a shopping day.
        let day = [ctx.day + 1, ctx.day + 2, ctx.day + 3].first { !ctx.state.setup.shoppingWeekdays.contains($0.isoWeekday) } ?? ctx.day + 1
        return SocialSuggestion(id: "\(ctx.day.jdn)", contact: contact, activity: activity,
                                message: MessageTemplates.social(activity: activity, contact: contact, day: day, today: ctx.day),
                                suggestedDay: day, reason: "You've had a steady few days. Nice time with someone helps keep it that way.")
    }

    // MARK: - Contacts

    /// Agreed contacts who can help with one of `kinds`, least recently messaged first.
    static func rotation(_ ctx: PlannerContext, kinds: [HelpKind]) -> [Contact] {
        let last: [String: Int] = ctx.state.outbox.filter { $0.status != .cancelled }
            .reduce(into: [:]) { m, msg in m[msg.contactID] = max(m[msg.contactID] ?? Int.min, msg.day.jdn) }
        return ctx.state.setup.contacts
            .filter { $0.agreed && !$0.canHelpWith.isDisjoint(with: kinds) && !$0.phone.isEmpty }
            .sorted { (last[$0.id] ?? Int.min, $0.name) < (last[$1.id] ?? Int.min, $1.name) }
    }

    static func suggestion(_ ctx: PlannerContext, kinds: [HelpKind], reason: String, groceries: [GroceryItem] = []) -> ContactSuggestion? {
        // Already handled today: a message for one of these kinds exists, including one the person
        // cancelled. A cancelled message is never offered again that day, to the same person or anyone else.
        if ctx.state.outbox.contains(where: { $0.day == ctx.day && kinds.contains($0.kind) }) { return nil }
        let thisWeek = ctx.state.outbox.filter { $0.status != .cancelled && $0.kind != .doSomethingFun && ctx.day - $0.day < 7 }
        guard thisWeek.count < maxHelpPerWeek else { return nil }
        for contact in rotation(ctx, kinds: kinds) {
            let recent = ctx.state.outbox.contains { $0.contactID == contact.id && $0.status != .cancelled && ctx.day - $0.day < sameContactGapDays }
            if recent { continue }
            guard let kind = kinds.first(where: { contact.canHelpWith.contains($0) }) else { continue }
            let text = MessageTemplates.help(kind, contact: contact, person: ctx.state.setup.personName, groceries: groceries)
            guard let clean = HealthWordFilter.clean(text, ignoring: [contact.name, ctx.state.setup.personName]) else { continue }
            return ContactSuggestion(id: "\(ctx.day.jdn)|\(kind.rawValue)|\(contact.id)", contact: contact, kind: kind,
                                     message: clean, reason: reason, day: ctx.day)
        }
        return nil
    }
}

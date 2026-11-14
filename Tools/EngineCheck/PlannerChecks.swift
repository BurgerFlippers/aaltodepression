import Foundation

// Planner scenarios on Demo user's synthetic days. Each check names what the product promises.

func plannerChecks(table: FeatureTable, history: [StepDay]) -> [String] {
    var failures: [String] = []
    func expect(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }

    func plan(_ n: Int, minutes: Int = 17 * 60 + 30, state: PlannerState? = nil) -> TodayPlan {
        let d = DemoSource.day(n)
        let s = state ?? DemoPlannerSource.state(through: n, includeToday: true)
        return TodayBuilder.build(PlannerContext(day: d, now: minutes, state: s, table: table.truncated(through: d), history: history))
    }
    func kinds(_ p: TodayPlan) -> [String] { p.cards.map { $0.id.split(separator: "|").first.map(String.init) ?? $0.id } }

    expect(Day(year: 2026, month: 9, day: 30).isoWeekday == 3, "2026-09-30 should be a Wednesday")

    print("\nPlanner, day by day (capacity, items done/total, cards):")
    for n in [10, 22, 31, 39, 46, 50, 52, 55, 59] {
        let p = plan(n)
        let done = p.items.filter { $0.status == .done }.count
        print(String(format: "%4d", n), "cap \(p.capacity)", "items \(done)/\(p.items.count)", kinds(p), p.reward.star ? "★" : "")
    }

    // A steady day: an ordinary list, nothing to step in about.
    let p10 = plan(10)
    expect(p10.cards.isEmpty, "day 10: a steady day should have no cards, got \(kinds(p10))")
    expect(p10.items.contains { $0.pillar == .meds && $0.doneBy == .health }, "day 10: medication should be confirmed from Health")
    expect(p10.items.contains { $0.pillar == .movement && $0.doneBy == .sensors }, "day 10: movement should be confirmed by sensors")

    // Good stretch → social suggestion, with a draft that names the friend.
    let p22 = plan(22)
    expect(p22.capacity == .good, "day 22: capacity should be good")
    if case .social(let s)? = p22.cards.first(where: { if case .social = $0 { true } else { false } }) {
        expect(s.contact != nil && s.suggestedDay > DemoSource.day(22), "day 22: social suggestion needs a contact and a coming day")
    } else { failures.append("day 22: expected a social suggestion, got \(kinds(p22))") }

    // A cold makes the day lighter but does not escalate.
    let p31 = plan(31)
    expect(p31.capacity == .low, "day 31: a tired cold day should be low")
    expect(!p31.items.contains { $0.pillar == .chores }, "day 31: no chores on a low day")
    expect(p31.items.first { $0.pillar == .movement }?.size == .tiny, "day 31: movement should be the tiny fresh-air walk")
    expect(!kinds(p31).contains("social") && !kinds(p31).contains("call"), "day 31: no social or call signal during a cold")

    // No social suggestions once the days get heavy.
    for n in 45...59 { expect(!kinds(plan(n)).contains("social"), "day \(n): no social suggestion during the drift") }

    // Shop skipped → a close person gets a concrete, health-free suggestion.
    let p50 = plan(50)
    if case .askForHelp(let s)? = p50.cards.first(where: { if case .askForHelp = $0 { true } else { false } }) {
        expect([.groceryRun, .inviteToEat, .shopTogether].contains(s.kind), "day 50: help should be about food")
        expect(HealthWordFilter.isClean(s.message, ignoring: [s.contact.name, "Demo user"]), "day 50: message must not carry health words")
        expect(s.contact.canHelpWith.contains(s.kind), "day 50: contact must have agreed to this kind of help")
    } else { failures.append("day 50: expected a food help card, got \(kinds(p50))") }

    // Once handled, the help card does not repeat the same day.
    var s50 = DemoPlannerSource.state(through: 50, includeToday: true)
    if case .askForHelp(let s)? = p50.cards.first(where: { if case .askForHelp = $0 { true } else { false } }) {
        s50.queue(s, now: 17 * 60 + 30, at: Date(), simulateReply: true)
        expect(!kinds(plan(50, state: s50)).contains("help"), "day 50: help card should go once a message exists")
        expect(s50.outbox.last?.status == .sent, "day 50: within 08–20 the message should go right away")
        // Cancelled stays cancelled: the card does not come back and queueing again does nothing.
        var c50 = s50
        if let id = c50.outbox.last?.id { c50.cancel(messageID: id) }
        expect(!kinds(plan(50, state: c50)).contains("help"), "day 50: a cancelled help message must not be offered again")
        c50.queue(s, now: 17 * 60 + 40, at: Date(), simulateReply: false)
        expect(c50.outbox.filter { $0.status != .cancelled }.isEmpty, "day 50: a cancelled message must not be queued again")
        var late = DemoPlannerSource.state(through: 50, includeToday: true)
        late.queue(s, now: 22 * 60, at: Date(), simulateReply: false)
        expect(late.outbox.last?.status == .pending, "day 50: after 20:00 the message should wait for the morning")
        late.releasePending(day: DemoSource.day(51), now: 8 * 60 + 5, simulateReply: false)
        expect(late.outbox.last?.status == .sent, "day 51: a waiting message goes out when the window opens")
        var ask = DemoPlannerSource.state(through: 50, includeToday: true)
        ask.setup.helpConsent = .askEachTime
        ask.queue(s, now: 21 * 60, at: Date(), simulateReply: false)
        ask.confirm(messageID: s.id, now: 21 * 60, simulateReply: false)
        expect(ask.outbox.last?.status == .pending, "askEachTime: Send at 21:00 waits for the morning")
        ask.releasePending(day: DemoSource.day(53), now: 9 * 60, simulateReply: false)
        expect(ask.outbox.last?.status == .cancelled, "a message still waiting two days later is dropped, not sent late")
    }

    // "Anxious" → safety questions first, once a day.
    let p52 = plan(52)
    expect(p52.cards.first == .safetyCheck, "day 52: safety check should be the first card, got \(kinds(p52))")
    var s52 = DemoPlannerSource.state(through: 52, includeToday: true)
    s52.markSafetyAsked(day: DemoSource.day(52))
    expect(!plan(52, state: s52).cards.contains(.safetyCheck), "day 52: safety check only once a day")
    expect(!plan(46).cards.contains(.safetyCheck), "day 46: tired alone must not open the safety questions")

    // Drift in the data → a close person hears a call would be welcome.
    let p55 = plan(55)
    expect(kinds(p55).contains("call"), "day 55: expected a call signal, got \(kinds(p55))")

    // Rate limit: at most two help messages a week.
    var busy = DemoPlannerSource.state(through: 55, includeToday: true)
    for (i, c) in DemoPlannerSource.setup.contacts.prefix(2).enumerated() {
        busy.outbox.append(OutgoingMessage(id: "x\(i)", day: DemoSource.day(54), createdAt: Date(), contactID: c.id, contactName: c.name,
                                           kind: .groceryRun, text: "", status: .sent))
    }
    expect(!kinds(plan(55, state: busy)).contains("help"), "day 55: no third help message in a week")

    // Every template is clean for every kind.
    for k in HelpKind.allCases {
        let c = Contact(id: "t", name: "Isadora", phone: "1", relation: .friend, canHelpWith: [k])
        let m = MessageTemplates.help(k, contact: c, person: "Demo user", groceries: GroceryPlanner.regular)
        expect(HealthWordFilter.isClean(m, ignoring: ["Isadora", "Demo user"]), "template \(k) carries a blocked word")
    }
    expect(!HealthWordFilter.isClean("Demo user is depressed"), "filter should block health words")

    // Safety flow follows the C-SSRS screener branching.
    func run(_ answers: [Bool]) -> (SafetyOutcome?, [SafetyQuestion]) {
        var f = SafetyFlow(); f.begin()
        var asked: [SafetyQuestion] = []
        for a in answers {
            guard case .ask(let q) = f.step else { break }
            asked.append(q); f.answer(a)
        }
        return (f.outcome, asked)
    }
    expect(run([false, false, false]).0 == .noThoughts, "safety: all no → noThoughts")
    expect(run([false, false, false]).1 == [.wishDead, .suicidalThoughts, .behavior], "safety: Q2 no skips to Q6")
    expect(run([true, false, false]).0 == .talkSoon, "safety: wish to be dead only → talkSoon")
    expect(run([true, true, true, false, false, false]).0 == .contactCareToday, "safety: method without intent → contactCareToday")
    expect(run([true, true, false, true, false, false]).0 == .urgent, "safety: intent → urgent")
    expect(run([false, false, true, true]).0 == .urgent, "safety: recent behaviour → urgent")
    expect(run([false, false, true, false]).0 == .contactCareToday, "safety: past behaviour → contactCareToday")
    expect(SafetyCopy.lines(for: .urgent).first?.number == "112", "safety: 112 comes first when urgent")

    // Reward: nothing is ever taken away; a star needs all four basics.
    var full = DemoPlannerSource.state(through: 10, includeToday: true)
    for item in plan(10, state: full).items where item.status != .done { full.mark(item, .done, at: Date()) }
    expect(plan(10, state: full).reward.star, "day 10: all basics done should give a star")
    expect(plan(50, state: s50).reward.goldKnots == 0, "day 50: no gold knot before the reply")
    if let id = s50.outbox.last?.id { s50.markReplied(messageID: id) }
    expect(plan(50, state: s50).reward.goldKnots == 1, "day 50: a reply ties a gold knot")

    // A grocery answer never stands in for a check-in.
    var g = DemoPlannerSource.state(through: 50)
    g.answerGroceries(false, day: DemoSource.day(50))
    expect(plan(50, state: g).needsCheckIn, "a grocery answer must not count as a check-in")

    // After a heavy safety outcome the day stays light and there is no social card.
    var heavy = DemoPlannerSource.state(through: 22, includeToday: true)
    heavy.recordSafetyOutcome(.talkSoon, day: DemoSource.day(22))
    let ph = plan(22, state: heavy)
    expect(ph.capacity == .low && !kinds(ph).contains("social"), "heavy safety day: low capacity and no social card")

    // Rewards are never unpicked: a chore done again later keeps the earlier row's thread.
    var rug = DemoPlannerSource.state(through: 39, includeToday: true)
    if let chore = plan(39, state: rug).items.first(where: { $0.pillar == .chores }) {
        rug.mark(chore, .done, at: Date())
        rug.keep(plan(39, state: rug).reward)
        let later = TodayBuilder.itemID(DemoSource.day(43), .chores, String(chore.id.split(separator: "|")[2]))
        rug.mark(id: later, pillar: .chores, .done, at: Date())
        expect(plan(39, state: rug).reward.threads.contains(.chores), "day 39: chore thread must survive a later redo")
        rug.keep(Rewards.day(DemoSource.day(39), items: [], state: rug))
        expect(rug.rewards[DemoSource.day(39).jdn]?.threads.contains(.chores) == true, "kept rewards only grow")
    } else { failures.append("day 39: expected a chore on the list") }

    // Shrinking keeps the sensors' confirmation.
    var sh = DemoPlannerSource.state(through: 10, includeToday: true)
    if let move = plan(10, state: sh).items.first(where: { $0.pillar == .movement }), move.doneBy == .sensors {
        sh.shrink(move, at: Date())
        let after = plan(10, state: sh).items.first { $0.pillar == .movement }
        expect(after?.status == .done && after?.doneBy == .sensors, "shrinking must not undo what sensors saw")
    }

    // Shrinking is one step at a time and stops at the smallest size.
    var small = DemoPlannerSource.state(through: 22, includeToday: true)
    if let move = plan(22, state: small).items.first(where: { $0.pillar == .movement }) {
        small.shrink(move, at: Date())
        expect(plan(22, state: small).items.first { $0.pillar == .movement }?.size == move.size.smaller, "shrink goes one size down")
    }

    let insights = plan(44).insights
    print("\nInsights by day 44:", insights.isEmpty ? "none yet" : insights.joined(separator: " | "))
    return failures
}

import Foundation

func reachOutChecks() -> [String] {
    var failures: [String] = []
    func check(_ condition: Bool, _ message: String) { if !condition { failures.append("Reach-out: " + message) } }
    let day = Day(year: 2026, month: 11, day: 14)
    let contact = Contact(id: "close", name: "Alex", phone: "+358000000000", relation: .other, canHelpWith: [.groceryRun, .pharmacyRun, .homeCleaning], agreed: false)
    var setup = PlannerSetup(personName: "Sam", contacts: [contact], helpConsent: .askEachTime)
    setup.supportPreferences = SupportPreferences(personID: contact.id, topics: [.groceries], automaticDemo: false)
    var state = PlannerState(setup: setup)
    func context(_ s: PlannerState, table: FeatureTable = FeatureTable()) -> PlannerContext {
        PlannerContext(day: day, now: 18 * 60, state: s, table: table, history: [])
    }
    check(ReachOutRules.prompt(context(state)) == nil, "no suggestion from silent / unused days")
    for d in [day - 1, day - 2] {
        state.mark(id: TodayBuilder.itemID(d, .movement, "move"), pillar: .movement, .done, at: d.start())
    }
    let prompt = ReachOutRules.prompt(context(state))
    check(prompt?.pillar == .food && prompt?.contact?.id == contact.id, "two active days offer user-led food contact, even without automatic recipient agreement")
    check(state.outbox.isEmpty, "producing a prompt never queues a message")
    state.dismissedCards[prompt!.id] = day.jdn
    check(ReachOutRules.prompt(context(state)) == nil, "Not now suppresses the prompt")
    state.dismissedCards.removeAll()
    state.mark(id: TodayBuilder.itemID(day - 1, .food, "meal"), pillar: .food, .done, at: (day - 1).start())
    check(ReachOutRules.prompt(context(state)) == nil, "a completed prior-day category breaks the missing-mark run")
    state.marks.removeValue(forKey: TodayBuilder.itemID(day - 1, .food, "meal"))
    state.mark(id: TodayBuilder.itemID(day, .food, "meal"), pillar: .food, .done, at: day.start())
    check(ReachOutRules.prompt(context(state)) == nil, "today's completion resolves the prompt")
    state.marks.removeValue(forKey: TodayBuilder.itemID(day, .food, "meal"))
    state.setup.supportPreferences?.topics = [.pharmacy]
    check(ReachOutRules.prompt(context(state)) == nil, "a default medicine box does not infer medicine use")
    state.setup.supportPreferences?.topics = [.cleaning]
    check(ReachOutRules.prompt(context(state))?.topic == .cleaning, "only enabled support topics are offered")
    state.setup.supportPreferences?.topics = [.groceries]
    check(ReachOutRules.automaticDemo(.groceries, ctx: context(state)) == nil, "automatic demo requires opt-in")
    state.setup.supportPreferences?.automaticDemo = true
    check(ReachOutRules.automaticDemo(.groceries, ctx: context(state)) == nil, "automatic demo requires recipient agreement")
    state.setup.contacts[0].agreed = true
    let automatic = ReachOutRules.automaticDemo(.groceries, ctx: context(state))
    check(automatic?.contact.id == contact.id, "agreed automatic demo reuses the preferred contact")
    check(ReachOutRules.automaticDemo(.pharmacy, ctx: context(state)) == nil, "unselected topic cannot be messaged")
    if let automatic {
        state.queue(automatic, now: 18 * 60, at: day.start(), simulateReply: true)
        state.cancel(messageID: automatic.id)
        check(ReachOutRules.automaticDemo(.groceries, ctx: context(state)) == nil, "cancelled request is not offered again")
    }
    for topic in SupportTopic.allCases {
        let text = MessageTemplates.help(topic.helpKind, contact: contact, person: "Sam")
        check(HealthWordFilter.isClean(text, ignoring: [contact.name, "Sam"]), "automatic templates contain no health readings or diagnoses")
        check(!MessageTemplates.reachOut(topic, contact: contact).isEmpty, "every support topic has an optional first-person draft")
    }
    let old = Data("{\"personName\":\"Sam\"}".utf8)
    check((try? JSONDecoder().decode(PlannerSetup.self, from: old))?.supportPreferences == nil, "older setup data decodes with no automatic consent")
    print("Reach-out checks: \(failures.isEmpty ? "passed" : "FAILED")")
    return failures
}

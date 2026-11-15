import Foundation

func demoScenarioChecks() -> [String] {
    var failures: [String] = []
    var count = 0
    func check(_ condition: Bool, _ description: String) {
        count += 1
        if !condition { failures.append("Demo scenario: " + description) }
    }
    let day = Day(year: 2026, month: 11, day: 15)
    var source = FeatureTable()
    source.set(F.steps, day, 4321)
    func history(_ load: Double) -> (FeatureTable, [StepDay]) {
        let table = DemoScenarioRules.table(ending: day, load: load, source: source)
        return (table, StepEngine.run(table: table, through: day, homeTimeZone: "Europe/Helsinki", locationEnabled: false))
    }
    let steady = history(0), yellow = history(0.6), red = history(1)
    check(steady.1.last?.step == .steady, "zero load stays steady")
    check(yellow.1.last?.step == .nudge, "medium load enters the real nudge stage")
    check(red.1.last?.step == .reachOut, "high load enters the real reach-out stage")
    check((steady.1.last?.result.steadiness ?? 0) > (red.1.last?.result.steadiness ?? 100), "slider changes real calculated scores")
    check(source.value(F.steps, day) == 4321 && source.keys.count == 1, "source readings are unchanged")
    check(red.0.value(F.phq9, day) == nil && red.0.value(F.dietaryEnergy, day) == nil, "no invented nutrition or clinical assessments")
    check(history(.nan).0.value(F.steps, day) == steady.0.value(F.steps, day), "invalid input safely becomes steady scenario")
    var setup = PlannerSetup(personName: "Demo")
    let contact = Contact(id: "test-contact", name: "Test friend", phone: "+358400000000", relation: .friend, canHelpWith: [.call], agreed: true)
    setup.contacts = [contact]
    setup.helpConsent = .askEachTime
    var state = PlannerState(setup: setup)
    func suggestion(_ state: PlannerState) -> ContactSuggestion? {
        InterventionRules.callSignal(PlannerContext(day: day, now: 18 * 60, state: state, table: yellow.0, history: yellow.1))
    }
    let candidate = suggestion(state)
    check(candidate?.contact.id == contact.id, "changed history produces the selected agreed contact suggestion")
    state.setup.contacts[0].agreed = false
    check(suggestion(state) == nil, "unagreed contact never receives a prepared request")
    state.setup.contacts[0].agreed = true
    if let candidate {
        let message = state.queue(candidate, now: 18 * 60, at: day.start(), simulateReply: false)
        check(message?.status == .pending && message?.simulatedReply == nil, "automatic preparation is not an actual send or a simulated reply")
        check(suggestion(state) == nil, "a prepared request prevents another automatic request")
        if let message { state.cancel(messageID: message.id) }
        check(suggestion(state) == nil, "cancellation does not silently trigger a replacement")
    }
    print("Demo scenario: \(count) checks, \(failures.count) failures")
    return failures
}

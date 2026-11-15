import Foundation

func sidequestChecks() -> [String] {
    var failures: [String] = []
    var count = 0
    func check(_ condition: Bool, _ message: String) {
        count += 1
        if !condition { failures.append("Sidequest: " + message) }
    }
    let day = Day(year: 2026, month: 11, day: 15)
    func signal(_ scores: [ScoreKind: Double], on date: Day? = nil, ill: Bool = false) -> StepDay {
        var result = DayResult(day: date ?? day - 1)
        result.scores = scores
        result.likelyIll = ill
        return StepDay(result: result, baselineDay: 85, isDrift: true, driftDaysInLastWeek: 5, step: .nudge, since: day - 2)
    }
    func offer(_ scores: [ScoreKind: Double]) -> SidequestDay {
        SidequestRules.make(day: day, signal: signal(scores), hasMedication: false)
    }
    let fallback = SidequestRules.make(day: day, signal: nil, hasMedication: false)
    check(fallback.options.count == 3 && Set(fallback.options.map(\.id)).count == 3, "exactly three distinct fallback options")
    check(fallback.signalDay == nil && !fallback.options.contains { $0.category == .medicine }, "missing data stays unknown; no assumed medication use")
    let sleep = offer([.sleep: 35, .movement: 90])
    check(sleep.options.count == 3 && sleep.options.allSatisfy { $0.category == .sleep }, "lowest sleep score guides all three options")
    check(sleep.startsSmall, "heavy signal starts with smaller tasks")
    let movement = offer([.sleep: 90, .movement: 60])
    check(movement.options.allSatisfy { $0.category == .movement } && !movement.startsSmall, "movement focus with regular tasks")
    let mixed = offer([.sleep: 40, .movement: 50])
    check(mixed.options.filter { $0.category == .sleep }.count == 2 && mixed.options.filter { $0.category == .movement }.count == 1, "two struggling categories receive a two-plus-one mix")
    let rhythm = offer([.sleep: 95, .rhythm: 30, .movement: 80])
    check(rhythm.options.allSatisfy { $0.category == .sleep }, "rhythm changes map to sleep support")
    check(offer([.body: 5, .places: 5]).signalDay == nil, "body and location alone cannot invent a routine-category need")
    let stale = SidequestRules.make(day: day, signal: signal([.sleep: 10], on: day - 3), hasMedication: false)
    check(stale.signalDay == nil, "stale signals cannot drive the offer")
    let future = SidequestRules.make(day: day, signal: signal([.sleep: 10], on: day + 1), hasMedication: false)
    check(future.signalDay == nil, "future data cannot leak into a historical demo day")
    check(offer([.sleep: .nan, .movement: .infinity]).signalDay == nil, "non-finite scores are ignored")
    let illness = SidequestRules.make(day: day, signal: signal([.movement: 90], ill: true), hasMedication: false)
    check(illness.startsSmall, "illness keeps the task small")
    check(offer([.sleep: 35, .movement: 90]) == sleep, "daily generation is deterministic")
    check(SidequestRules.catalog.allSatisfy { $0.smaller.minutes <= $0.regular.minutes && !$0.smaller.instruction.isEmpty }, "every task includes a genuine smaller version")
    check(Set(SidequestRules.catalog.map(\.id)).count == SidequestRules.catalog.count, "catalog IDs are unique")
    var selected = movement
    check(!selected.complete(at: day.start()), "cannot complete before choosing")
    selected.choose("invalid")
    check(selected.selected == nil, "invalid IDs are ignored")
    selected.choose(selected.options[0].id)
    selected.makeSmaller()
    check(selected.useSmaller && selected.version == selected.selected?.smaller, "smaller action changes the saved version")
    check(selected.complete(at: day.start()) && !selected.complete(at: day.start()), "completion is idempotent")
    let completed = selected
    selected.choose(selected.options[1].id)
    check(selected == completed, "completion locks the daily win")
    var state = PlannerState(setup: PlannerSetup(personName: "QA"))
    state.sidequests[day.jdn] = selected
    state.sidequests[(day + 1).jdn] = fallback
    do {
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PlannerState.self, from: encoded)
        check(decoded.sidequests[day.jdn] == selected && decoded.sidequests[(day + 1).jdn]?.completedAt == nil, "choice, size and completion round-trip without crossing days")
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacy.removeValue(forKey: "sidequests")
        let migrated = try JSONDecoder().decode(PlannerState.self, from: JSONSerialization.data(withJSONObject: legacy))
        check(migrated.sidequests.isEmpty && migrated.setup == state.setup, "older planner files decode without losing profile")
    } catch { failures.append("Sidequest persistence: \(error)") }
    check(state.marks.isEmpty && state.outbox.isEmpty, "sidequest completion does not complete routine goals or queue messages")
    check(SidequestCategory.nutrition.title == "Eat", "five public categories use Eat rather than Nutrition")
    for category in [SidequestCategory.sleep, .movement, .nutrition, .social, .medicine] {
        check(SidequestRules.catalog.filter { $0.category == category }.count >= 6, "six tasks available for \(category.title)")
    }
    check(SidequestRules.catalog.count == 30, "thirty curated tasks in the five categories")
    check(SidequestRules.catalog.filter(\.canInvite).allSatisfy { !$0.invitation.isEmpty }, "every contact action has a ready invitation")
    selected.reminderAt = day.start().addingTimeInterval(3600)
    if let data = try? JSONEncoder().encode(selected), let restored = try? JSONDecoder().decode(SidequestDay.self, from: data) {
        check(restored.reminderAt == selected.reminderAt, "reminder survives persistence")
    } else { failures.append("Sidequest: reminder serialization failed") }
    var lifecycle = movement
    check(lifecycle.progress == .notSelected && !lifecycle.start(at: day.start()), "no start or progress before a choice")
    lifecycle.choose(lifecycle.options[0].id)
    check(lifecycle.progress == .selected, "legacy selected records remain ready to start")
    check(lifecycle.start(at: day.start()) && lifecycle.progress == .inProgress, "start directly records an in-progress challenge")
    check(!lifecycle.start(at: day.start().addingTimeInterval(60)), "a second start cannot reset the recorded start time")
    check(lifecycle.complete(at: day.start().addingTimeInterval(300)) && lifecycle.progress == .completed, "completion preserves the start and records the completed status")
    if let encoded = try? JSONEncoder().encode(lifecycle), let restored = try? JSONDecoder().decode(SidequestDay.self, from: encoded) {
        check(restored.startedAt == day.start() && restored.progress == .completed, "start and completion persist independently")
    } else { failures.append("Sidequest: lifecycle serialization failed") }
    var observed = movement
    observed.choose(observed.options[0].id)
    _ = observed.start(at: day.start().addingTimeInterval(8 * 3600))
    observed.selectionReadings = [F.steps: 100]
    var readings = FeatureTable()
    readings.set(F.steps, day - 1, 9000)
    check(SidequestEvidenceRules.description(offer: observed, on: day, readings: readings).contains("unverified"), "another day's activity cannot verify a task")
    readings.set(F.steps, day, 100)
    check(SidequestEvidenceRules.description(offer: observed, on: day, readings: readings).contains("unverified"), "unchanged totals provide no new evidence")
    readings.set(F.steps, day, 500)
    check(SidequestEvidenceRules.description(offer: observed, on: day, readings: readings).contains("not completion"), "increased steps support movement without claiming task completion")
    check(observed.completedAt == nil, "selection and passive clues never create a manual completion")
    observed.selectionReadings = nil
    check(SidequestEvidenceRules.description(offer: observed, on: day, readings: readings).contains("unverified"), "missing selection baseline never defaults to zero")
    observed.selectionReadings = [F.steps: .nan]
    check(SidequestEvidenceRules.description(offer: observed, on: day, readings: readings).contains("unverified"), "invalid selection baseline stays unknown")
    print("Sidequests: \(count) checks, \(failures.count) failures")
    return failures
}

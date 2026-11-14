import Foundation

// Checks for tracking (sleep, activity, places), questions and answers, contact intake and the
// notification plan. Each message names what the product promises.

func backendChecks(table full: FeatureTable) -> [String] {
    var failures: [String] = []
    func expect(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }
    func snap(_ n: Int, minutes: Int = 17 * 60 + 30) -> TrackingSnapshot {
        let d = DemoSource.day(n)
        return TrackingBuilder.snapshot(table: full.truncated(through: d), day: d, minutes: minutes, locationEnabled: true)
    }

    // Tracking: drift days show up against the person's own usual.
    let s50 = snap(50)
    expect(s50.sleep.duration.comparison == .below, "tracking day 50: sleep should be below usual")
    expect(s50.sleep.shortNights == 3, "tracking day 50: three short nights in a row")
    expect(s50.activity.stepsSoFar.comparison == .below, "tracking day 50: steps so far below usual")
    expect(s50.places.timeAtHome.comparison == .above, "tracking day 50: more time at home than usual")
    expect(s50.sleep.trend.count == 28 && s50.activity.trend.count == 28, "tracking: 28-day trends")
    expect(s50.activity.hourlySteps.count == 24, "tracking: 24 hourly step values")
    let s31 = snap(31)
    expect(s31.sleep.duration.comparison == .usual, "tracking day 31: the cold doesn't make sleep look off")
    let s10 = snap(10)
    expect(s10.sleep.duration.comparison == .unknown && s10.sleep.duration.value != nil,
           "tracking day 10: a value but no usual yet (first weeks)")
    // Morning steps are compared with the usual by the same hour, not with whole days.
    let morning = snap(50, minutes: 9 * 60)
    expect(morning.activity.stepsSoFar.title == "Steps by 09:00", "tracking: steps compared by time of day")
    expect(morning.activity.hourlySteps[9...].allSatisfy { $0 == nil }, "tracking: no hourly steps after now")
    // Before the first steps of the day: zero so far, still compared with the usual by that hour.
    let early = snap(50, minutes: 6 * 60 + 30)
    expect(early.activity.stepsSoFar.value == 0 && early.activity.stepsSoFar.usualText != nil,
           "tracking: early morning shows 0 steps so far with a usual, not the whole day")
    // Running totals are not compared with whole days while the day is going on.
    expect(s50.activity.exercise.comparison == .unknown && s50.activity.exercise.title.hasSuffix("so far"),
           "tracking: partial-day exercise is not compared with whole days")
    expect(s50.activity.activeHours.title.hasPrefix("Hours with movement by"), "tracking: active hours compared by time of day")
    expect(s50.activity.trend.last?.day == DemoSource.day(49), "tracking: the steps trend ends with the last complete day")
    let fullDay = snap(50, minutes: 24 * 60)
    expect(fullDay.activity.exercise.comparison != .unknown && fullDay.activity.trend.last?.day == DemoSource.day(50),
           "tracking: a finished day is compared in full")
    // No data is unknown, never zero.
    let empty = TrackingBuilder.snapshot(table: FeatureTable(), day: DemoSource.day(5), minutes: 600, locationEnabled: false)
    expect(empty.sleep.coverage == .none && empty.activity.coverage == .none, "tracking: no data → coverage none")
    expect(empty.sleep.duration.text == "–" && empty.sleep.duration.comparison == .unknown, "tracking: missing value shows –")
    expect(!empty.places.locationEnabled, "tracking: location off is reported")
    print("\nTracking, day 50:", s50.sleep.headline, "|", s50.activity.headline, "|", s50.places.headline)

    // Questions: one generic shape, answers become the same check-in.
    let d = DemoSource.day(50)
    let answers: [String: Answer] = ["mood": .number(2), "energy": .option(0), "feelings": .options([3, 4]), "foodAtHome": .option(2)]
    if let c = QuestionCatalog.checkIn(from: answers, day: d, at: Date()) {
        expect(c.mood == 2 && c.energy == .low && c.feelings == [.low, .anxious] && c.foodAtHome == .empty, "questions: answers map to the check-in")
        expect(QuestionCatalog.answers(for: c) == answers, "questions: check-in maps back to the same answers")
    } else { failures.append("questions: a full set of answers should make a check-in") }
    expect(QuestionCatalog.checkIn(from: ["mood": .number(3)], day: d, at: Date()) == nil, "questions: energy is required")
    expect(QuestionCatalog.checkIn(from: ["mood": .number(9), "energy": .option(1)], day: d, at: Date()) == nil, "questions: mood outside 1–5 is refused")
    expect(QuestionCatalog.checkIn.count == 4, "questions: the check-in has four questions")
    var logged = PlannerState(setup: DemoPlannerSource.setup)
    logged.log(answers.merging(["safety.wishDead": .yes(true)]) { a, _ in a }, day: d, at: Date())
    expect(Set(logged.answerLog.map(\.id)).count == logged.answerLog.count, "questions: every logged answer has its own id")
    let noFeelings = CheckIn(day: d, at: Date(), mood: 3, energy: .some)
    expect(QuestionCatalog.answers(for: noFeelings)["feelings"] == nil, "questions: skipped feelings are not an answer")
    expect(logged.answerLog.count == 4 && !logged.answerLog.contains { $0.questionID.hasPrefix("safety.") },
           "questions: the answer log never keeps safety answers")

    // Contact intake: picked people start as not agreed, duplicates by phone are skipped.
    var setup = DemoPlannerSource.setup
    let before = setup.contacts.count
    let added = ContactIntake.add([("Kate Bell", "+358 40 000 0009"), ("Sanna again", "+358400000001"), ("", "123")], to: &setup)
    expect(added == 1 && setup.contacts.count == before + 1, "contacts: one new, one duplicate, one empty")
    expect(setup.contacts.last?.agreed == false, "contacts: a picked contact waits for agreement")
    expect(ContactIntake.problem(setup.contacts.last!) == "Waiting for them to agree.", "contacts: says what blocks a contact")
    var formats = PlannerSetup(personName: "x")
    let n = ContactIntake.add([("A", "040 123 4567"), ("A again", "+358 40 123 4567"), ("A third", "00358401234567")], to: &formats)
    expect(n == 1, "contacts: national, international and 00 forms are the same number")
    expect(NotificationPlan.daily(for: DemoPlannerSource.setup).allSatisfy { NotificationPlan.isDailyPlan(Substring($0.id)) },
           "notifications: every daily-plan id is recognised for replacement")
    expect(!NotificationPlan.isDailyPlan("later.m1.480") && !NotificationPlan.isDailyPlan("now.sent.x"),
           "notifications: one-off reminders are kept when the plan is replaced")

    // Notification plan: what goes on the lock screen.
    let plan = NotificationPlan.daily(for: DemoPlannerSource.setup)
    let s = DemoPlannerSource.setup
    expect(plan.count == 1 + s.medications.flatMap(\.times).count + s.shoppingWeekdays.count + 1, "notifications: check-in, doses, shop days, wind-down")
    let medNames = s.medications.map(\.name)
    expect(!plan.contains { n in medNames.contains { n.body.contains($0) || n.title.contains($0) } }, "notifications: never name a medicine")
    // "Medicine time" is allowed; diagnosis, mood and treatment words are not.
    let lockScreenBlocked = ["depress", "anxi", "suicid", "mood", "mental", "therap", "tms", "relapse", "nurse", "clinic"]
    expect(!plan.contains { n in lockScreenBlocked.contains { (n.title + " " + n.body).lowercased().contains($0) } },
           "notifications: no diagnosis, mood or treatment words on the lock screen")
    expect(plan.filter { $0.category == .shop }.allSatisfy { $0.time == 17 * 60 && $0.weekday != nil }, "notifications: shop question at 17:00 on shop days")
    return failures
}


// Bonus: screen time from the person's own answers.
func screenTimeChecks(table full: FeatureTable) -> [String] {
    var failures: [String] = []
    func expect(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }

    // Answers: exact minutes win over the range; nothing usable is refused.
    let exact = QuestionCatalog.screenTimeReport(from: ["screenTime": .option(1), "screenTimeExact": .number(195), "phoneInBed": .yes(true)])
    expect(exact?.hours == 3.25 && exact?.exact == true && exact?.phoneInBed == true, "screen time: exact minutes win over the range")
    expect(QuestionCatalog.screenTimeReport(from: ["screenTime": .option(3)])?.hours == 5, "screen time: a range maps to hours")
    expect(QuestionCatalog.screenTimeReport(from: [:]) == nil, "screen time: no answers, no report")
    if case .numeric(let r, let step, let unit) = QuestionCatalog.screenTimeExact.kind {
        expect(r == 0...960 && step == 15 && unit == "min", "questions: numeric kind carries range, step and unit")
    } else { failures.append("questions: screen time exact should be numeric") }

    // Answers become signals, tracking compares them with the person's own usual.
    let n = 55, d = DemoSource.day(n)
    let s = DemoPlannerSource.state(through: n, includeToday: true)
    var t = full.truncated(through: d)
    t.merge(s.selfReportTable())
    let st = TrackingBuilder.snapshot(table: t, day: d, minutes: 17 * 60 + 30, locationEnabled: true).screenTime
    expect(st?.hours.value != nil && st?.hours.comparison == .above, "screen time day 55: more than the usual during the drift")
    expect((st?.phoneInBedNights ?? 0) >= 3, "screen time day 55: phone in bed most nights")
    print("Screen time, day 55:", st?.headline ?? "–", "| in bed \(st?.phoneInBedNights ?? 0) of \(st?.answeredNights ?? 0)")

    // The evening wind-down picks the phone as the one step, and the morning question is asked once.
    let plan = TodayBuilder.build(PlannerContext(day: d, now: 17 * 60 + 30, state: s, table: t, history: []))
    expect(plan.items.first { $0.pillar == .sleep }?.detail?.contains("phone") == true, "screen time: wind-down suggests leaving the phone out")
    expect(!plan.asksAboutScreenTime, "screen time: not asked again once yesterday is answered")
    var unanswered = s
    unanswered.screenTime[(d - 1).jdn] = nil
    expect(TodayBuilder.build(PlannerContext(day: d, now: 600, state: unanswered, table: t, history: [])).asksAboutScreenTime,
           "screen time: asked in the morning when yesterday is missing")
    var off = unanswered
    off.setup.asksScreenTime = false
    expect(!TodayBuilder.build(PlannerContext(day: d, now: 600, state: off, table: t, history: [])).asksAboutScreenTime,
           "screen time: never asked when switched off")

    // Old saved setups without the new field still load.
    let old = #"{"personName":"A","contacts":[]}"#.data(using: .utf8)!
    let decoded = try? JSONDecoder().decode(PlannerSetup.self, from: old)
    expect(decoded?.personName == "A" && decoded?.asksScreenTime == true, "setup: older saved setups still load")
    return failures
}

// The demo exactly as the phone shows it: the day opens before the check-in, the presenter taps Done
// on the prefilled check-in, and the day's story appears.
func demoStoryChecks(table full: FeatureTable, history: [StepDay]) -> [String] {
    var failures: [String] = []
    func expect(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }
    func afterCheckIn(_ n: Int) -> (TodayPlan, PlannerState) {
        var s = DemoPlannerSource.state(through: n)          // as Planner.demo opens it
        if let c = DemoPlannerSource.checkIn(n) { s.record(c) }
        let d = DemoSource.day(n)
        var t = full.truncated(through: d)
        t.merge(s.selfReportTable())
        return (TodayBuilder.build(PlannerContext(day: d, now: 17 * 60 + 30, state: s, table: t, history: history)), s)
    }
    func kinds(_ p: TodayPlan) -> [String] { p.cards.map { $0.id.split(separator: "|").first.map(String.init) ?? $0.id } }

    expect(kinds(afterCheckIn(22).0).contains("social"), "demo 22: prefilled check-in brings the social card")
    let p31 = afterCheckIn(31).0
    expect(p31.capacity == .low && p31.cards.isEmpty, "demo 31: a light day and no cards")
    expect(kinds(afterCheckIn(50).0).first == "help", "demo 50: prefilled check-in brings the food help card first")
    expect(afterCheckIn(52).0.cards.first == .safetyCheck, "demo 52: prefilled check-in brings the safety card first")
    expect(kinds(afterCheckIn(55).0).contains("call"), "demo 55: prefilled check-in brings the call signal")

    // Social follow-up: a plan made on day 22 for a coming day is asked about afterwards.
    var (p22, s22) = afterCheckIn(22)
    if case .social(let sug)? = p22.cards.first(where: { if case .social = $0 { true } else { false } }) {
        s22.acceptSocial(sug, today: DemoSource.day(22))
        p22 = TodayBuilder.build(PlannerContext(day: DemoSource.day(22), now: 1050, state: s22, table: full.truncated(through: DemoSource.day(22)), history: history))
        expect(p22.upcomingPlans.contains { $0.id == sug.id }, "social: an accepted plan shows under upcoming plans")
        let later = sug.suggestedDay + 1
        let pl = TodayBuilder.build(PlannerContext(day: later, now: 600, state: s22, table: full.truncated(through: later), history: history))
        expect(pl.asksAboutSocial?.id == sug.id, "social: the day after, the app asks whether you met")
    } else { failures.append("demo 22: no social suggestion to accept") }
    return failures
}

import Foundation
import Observation

/// The planner service the screens talk to. Holds the state, rebuilds today's plan after every
/// change and saves. All rules live in Engine/Planner; this class only wires them to the app.
///
/// Wiring (integrator): create one `Planner` in AppModel, call `refresh(...)` whenever the feature
/// table or history changes and when the app becomes active, and route notification responses to
/// `handle(_:deliveredAt:)`. Screens read `today`, `messagesToday`, `openMessages`, `safety`, `rug`
/// and call the action methods.
@MainActor @Observable
final class Planner {
    private(set) var state: PlannerState
    private(set) var today: TodayPlan?
    /// The safety questions while they are open; nil otherwise.
    private(set) var safety: SafetyFlow?
    let isDemo: Bool

    private let store: PlannerStore
    private var table = FeatureTable()
    /// The table as it came in, before the person's own answers (screen time) were added.
    @ObservationIgnored private var sensorTable = FeatureTable()
    /// Called after any change, so `Backend` can rebuild tracking with new answers.
    @ObservationIgnored var onChange: (() -> Void)?

    /// Sensor data plus the person's own answers, as one table.
    func withAnswers(_ t: FeatureTable) -> FeatureTable {
        var merged = t
        merged.merge(state.selfReportTable())
        return merged
    }
    private var history: [StepDay] = []
    private var day = Day(Date())
    private var minutes = 12 * 60

    init(store: PlannerStore = .live, setup: PlannerSetup? = nil, isDemo: Bool = false) {
        self.store = store
        self.isDemo = isDemo
        self.state = store.load() ?? PlannerState(setup: setup ?? PlannerSetup(personName: ""))
    }

    /// A planner filled with Demo user's synthetic days, for the Demo tab and previews.
    /// The demo day opens on the check-in; `minutes` is the demo clock (17:30 by default).
    static func demo(day n: Int, minutes: Int = 17 * 60 + 30) -> Planner {
        let p = Planner(store: .memory, setup: DemoPlannerSource.setup, isDemo: true)
        p.state = DemoPlannerSource.state(through: n)
        let table = DemoSource.table()
        let history = StepEngine.run(table: table, through: DemoSource.day(n), homeTimeZone: DemoSource.homeTimeZone, locationEnabled: true)
        p.refresh(day: DemoSource.day(n), minutes: minutes, table: table.truncated(through: DemoSource.day(n)), history: history)
        return p
    }

    var setup: PlannerSetup { state.setup }
    var isSetUp: Bool { !state.setup.personName.isEmpty }
    var currentDay: Day { day }
    /// Messages to close people created today (sent, waiting, answered or cancelled).
    var messagesToday: [OutgoingMessage] { state.outbox.filter { $0.day == day }.sorted { $0.createdAt < $1.createdAt } }
    /// Messages still waiting, from any day: the screen shows them so they can be sent or cancelled.
    var openMessages: [OutgoingMessage] { state.outbox.filter { $0.status == .pending }.sorted { $0.createdAt < $1.createdAt } }
    /// Rewards for the last four weeks, oldest first, for the rug. Worked out once per change.
    private(set) var rug: [DayReward] = []
    var weekSummary: String { Rewards.week(ending: day, rewards: Array(rug.suffix(7))) }
    /// Crisis lines for "I need help now", which opens without any questions.
    var crisisLines: [CrisisLine] { SafetyCopy.lines }

    // MARK: - Inputs

    func refresh(day: Day, now: Date = Date(), table: FeatureTable, history: [StepDay]) {
        refresh(day: day, minutes: Self.minutes(of: now), table: table, history: history)
    }

    func refresh(day: Day, minutes: Int, table: FeatureTable, history: [StepDay]) {
        self.day = day
        self.minutes = minutes
        self.sensorTable = table
        self.table = withAnswers(table)
        self.history = history
        state.releasePending(day: day, now: minutes, simulateReply: isDemo)
        rebuild(autoSend: false)
        save()
    }

    // MARK: - Setup

    func updateSetup(_ s: PlannerSetup) {
        state.setup = s
        save()
        rebuild(autoSend: false)
        if !isDemo { scheduleReminders(for: s) }
    }

    /// One scheduling at a time, in order, so a quick second change never leaves stale reminders.
    @ObservationIgnored private var scheduling: Task<Void, Never>?

    private func scheduleReminders(for s: PlannerSetup) {
        let previous = scheduling
        scheduling = Task {
            await previous?.value
            // An erased planner (no name) keeps no daily reminders at all.
            if s.personName.isEmpty { await PlannerNotifications.removeDailyPlan() }
            else { await PlannerNotifications.schedule(for: s) }
        }
    }

    /// Adds people from the system contact picker (no Contacts permission needed). Returns how many were new.
    @discardableResult
    func addContacts(_ picked: [(name: String, phone: String)]) -> Int {
        var s = state.setup
        let n = ContactIntake.add(picked, to: &s)
        if n > 0 { updateSetup(s) }
        return n
    }

    /// Every answer given so far, newest last (the demo shows this; safety answers are never kept).
    var answerLog: [AnswerRecord] { state.answerLog }
    /// All messages to close people, newest first.
    var outbox: [OutgoingMessage] { state.outbox.sorted { $0.createdAt > $1.createdAt } }
    /// Demo: also show a local notification each time a (simulated) message goes out.
    var notifySimulatedSends = false

    /// Deletes everything the planner stored and starts over with `setup`.
    func eraseAll(keeping setup: PlannerSetup? = nil) {
        store.erase()
        if !isDemo { scheduleReminders(for: setup ?? PlannerSetup(personName: "")) }
        state = PlannerState(setup: setup ?? PlannerSetup(personName: ""))
        safety = nil
        if !isDemo { save() }
        rebuild(autoSend: false)
    }

    // MARK: - Check-in and answers

    func checkIn(mood: Int, energy: Energy, feelings: Set<Feeling>, foodAtHome: FoodAtHome?) {
        syncClock()
        let c = CheckIn(day: day, at: now, mood: mood, energy: energy, feelings: feelings, foodAtHome: foodAtHome)
        record(c, answers: QuestionCatalog.answers(for: c))
    }

    private func record(_ c: CheckIn, answers: [String: Answer]) {
        state.record(c)
        state.log(answers, day: day, at: now)
        rebuild(autoSend: true)
        save()
        if !isDemo { Task { await StateOfMindWriter.save(c) } }
    }

    /// The check-in from generic answers (`QuestionCatalog.checkIn` questions, keyed by question id).
    /// Returns false when mood or energy is missing.
    @discardableResult
    func submitCheckIn(_ answers: [String: Answer]) -> Bool {
        syncClock()
        guard let c = QuestionCatalog.checkIn(from: answers, day: day, at: now) else { return false }
        // Log exactly what was answered (a skipped optional question stays unlogged).
        record(c, answers: answers)
        return true
    }

    /// Bonus, screen time about yesterday from `QuestionCatalog.screenTimeQuestions` answers.
    /// Returns false when nothing usable was answered.
    @discardableResult
    func answerScreenTime(_ answers: [String: Answer]) -> Bool {
        syncClock()
        guard let r = QuestionCatalog.screenTimeReport(from: answers) else { return false }
        state.recordScreenTime(r, day: day - 1)
        state.log(answers, day: day, at: now)
        table = withAnswers(sensorTable)
        rebuild(autoSend: false)
        save()
        return true
    }

    /// "Did you get to the shop today?" In the app, help the person agreed to send goes out right away.
    /// From a notification nothing is sent: the help card waits until the app is opened.
    func answerGroceries(_ done: Bool, fromNotification: Bool = false) {
        syncClock()
        state.answerGroceries(done, day: day)
        state.log([QuestionCatalog.groceries.id: .yes(done)], day: day, at: now)
        rebuild(autoSend: !fromNotification)
        save()
    }

    // MARK: - List

    /// Freeze today's offers. An unchosen fallback can gain real Health context later.
    func prepareSidequests(signal: StepDay?, replaceUnchosen: Bool = false) {
        let offer = SidequestRules.make(day: day, signal: signal, hasMedication: !setup.medications.isEmpty)
        if var existing = state.sidequests[day.jdn] {
            let refreshed = existing.options.map { saved in SidequestRules.catalog.first { $0.id == saved.id } ?? saved }
            if refreshed != existing.options {
                existing.options = refreshed
                state.sidequests[day.jdn] = existing
                save()
            }
            guard existing.selectedID == nil, existing.completedAt == nil,
                  replaceUnchosen || existing.signalDay == nil && offer.signalDay != nil,
                  existing != offer else { return }
        }
        state.sidequests[day.jdn] = offer
        save()
    }

    func chooseSidequest(_ id: String, on expectedDay: Day) {
        syncClock()
        guard day == expectedDay, var offer = state.sidequests[day.jdn] else { return }
        offer.choose(id)
        state.sidequests[day.jdn] = offer
        save()
    }

    @discardableResult func startSidequest(_ id: String, smaller: Bool, on expectedDay: Day, observations: [String: Double] = [:]) -> Bool {
        syncClock()
        guard day == expectedDay, var offer = state.sidequests[day.jdn],
              offer.completedAt == nil, offer.selectedID == nil || offer.selectedID == id else { return false }
        if offer.selectedID == nil { offer.choose(id) }
        offer.useSmaller = smaller || offer.startsSmall
        guard offer.start(at: now) else { return false }
        offer.selectionReadings = observations.filter { $0.value.isFinite }
        state.sidequests[day.jdn] = offer
        save()
        return true
    }

    func shrinkSidequest(on expectedDay: Day) {
        syncClock()
        guard day == expectedDay, var offer = state.sidequests[day.jdn] else { return }
        offer.makeSmaller()
        state.sidequests[day.jdn] = offer
        save()
    }

    func changeSidequest(on expectedDay: Day) {
        syncClock()
        guard day == expectedDay, var offer = state.sidequests[day.jdn], offer.completedAt == nil else { return }
        offer.selectedID = nil
        offer.startedAt = nil
        offer.selectionReadings = nil
        offer.useSmaller = false
        offer.reminderAt = nil
        if !isDemo { Task { await SidequestReminders.cancel(on: expectedDay) } }
        state.sidequests[day.jdn] = offer
        save()
    }

    @discardableResult func completeSidequest(on expectedDay: Day) -> Bool {
        syncClock()
        guard day == expectedDay, var offer = state.sidequests[day.jdn], offer.complete(at: now) else { return false }
        offer.reminderAt = nil
        state.sidequests[day.jdn] = offer
        if !isDemo { Task { await SidequestReminders.cancel(on: expectedDay) } }
        save()
        return true
    }

    @discardableResult func setSidequestReminder(_ date: Date?, on expectedDay: Day) -> Bool {
        syncClock()
        guard !isDemo, day == expectedDay, var offer = state.sidequests[day.jdn],
              offer.selected != nil, offer.completedAt == nil else { return false }
        offer.reminderAt = date
        state.sidequests[day.jdn] = offer
        save()
        return true
    }

    func mark(_ item: PlanItem, _ status: ItemStatus) {
        syncClock()
        state.mark(item, status, at: now)
        rebuild(autoSend: false)
        save()
    }

    func shrink(_ item: PlanItem) {
        syncClock()
        state.shrink(item, at: now)
        rebuild(autoSend: false)
        save()
    }

    // MARK: - Cards and messages

    func dismiss(_ card: Card) {
        syncClock()
        state.dismiss(card, day: day)
        rebuild(autoSend: false)
        save()
    }

    /// Sends (or, outside 08–20, queues) a suggestion to a close person. Simulated: nothing leaves the phone.
    @discardableResult
    func send(_ s: ContactSuggestion) -> OutgoingMessage? {
        syncClock()
        let m = state.queue(s, now: minutes, at: now, simulateReply: isDemo)
        // Tapping Send is the person's confirmation, also in askEachTime mode.
        if let m { state.confirm(messageID: m.id, now: minutes, simulateReply: isDemo) }
        rebuild(autoSend: false)
        save()
        return state.outbox.first { $0.id == m?.id }
    }

    func confirm(messageID: String) {
        syncClock()
        state.confirm(messageID: messageID, now: minutes, simulateReply: isDemo)
        rebuild(autoSend: false)
        save()
    }

    func cancel(messageID: String) {
        state.cancel(messageID: messageID)
        rebuild(autoSend: false)
        save()
    }

    /// Demo: the contact's (simulated) reply arrives.
    func receiveReply(messageID: String) {
        state.markReplied(messageID: messageID)
        rebuild(autoSend: false)
        save()
    }

    func acceptSocial(_ s: SocialSuggestion) {
        syncClock()
        state.acceptSocial(s, today: day)
        rebuild(autoSend: false)
        save()
    }

    func answerSocial(planID: String, met: Bool) {
        state.answerSocial(planID: planID, met: met)
        state.log([QuestionCatalog.metSomeone.id: .yes(met)], day: day, at: now)
        rebuild(autoSend: false)
        save()
    }

    func dismissReachOutPrompt(_ prompt: ReachOutPrompt) {
        syncClock()
        state.dismissedCards[prompt.id] = day.jdn
        rebuild(autoSend: false)
        save()
    }

    /// Advances the automatic-request scene in a sandbox. Never operates on the live planner.
    @discardableResult
    func demonstrateAutomaticSupport(_ topic: SupportTopic) -> OutgoingMessage? {
        guard isDemo, let suggestion = ReachOutRules.automaticDemo(topic, ctx: context) else { return nil }
        let message = state.queue(suggestion, now: minutes, at: now, simulateReply: true)
        if let message { state.confirm(messageID: message.id, now: minutes, simulateReply: true) }
        rebuild(autoSend: false)
        save()
        return state.outbox.first { $0.id == message?.id }
    }

    // MARK: - Safety

    /// Opens the safety questions (from the safety card).
    func startSafety() {
        syncClock()
        safety = SafetyFlow()
    }

    func safetyContinue() { safety?.begin() }

    func safetyAnswer(_ yes: Bool) {
        guard safety != nil else { return }
        // Asked once the first answer is given; leaving at the bridge keeps the card for later.
        state.markSafetyAsked(day: day)
        safety?.answer(yes)
        if let o = safety?.outcome { state.recordSafetyOutcome(o, day: day) }
        rebuild(autoSend: false)
        save()
    }

    /// Closes the flow. The answers are not stored; a heavy outcome keeps today's list light.
    func finishSafety() {
        safety = nil
        rebuild(autoSend: false)
    }

    // MARK: - Notifications

    /// Applies a notification action to the day the notification was delivered.
    func handle(_ action: PlannerNotificationAction, deliveredAt: Date = Date()) {
        let deliveredDay = isDemo ? day : Day(deliveredAt)
        switch action {
        case .medicationTaken(let medID, let time):
            state.mark(id: TodayBuilder.itemID(deliveredDay, .meds, "\(medID)|\(time)"), pillar: .meds, .done, at: deliveredAt)
            syncClock()
            rebuild(autoSend: false)
            save()
        case .groceries(let done):
            state.answerGroceries(done, day: deliveredDay)
            syncClock()
            rebuild(autoSend: false)
            save()
        case .open, .sidequest:
            break
        }
    }

    // MARK: - Private

    private static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 12) * 60 + (c.minute ?? 0)
    }

    /// Live planners act on the real clock, not the time of the last refresh. The demo keeps its own clock.
    private func syncClock() {
        guard !isDemo else { return }
        let date = Date()
        day = Day(date)
        minutes = Self.minutes(of: date)
    }

    private var now: Date {
        isDemo ? day.start().addingTimeInterval(TimeInterval(minutes * 60)) : Date()
    }

    private var context: PlannerContext {
        PlannerContext(day: day, now: minutes, state: state, table: table, history: history)
    }

    /// Rebuilds today. With `autoSend`, help that the person has agreed to send right away goes out now.
    private func rebuild(autoSend: Bool) {
        var plan = TodayBuilder.build(context)
        if autoSend, state.setup.helpConsent == .sendRightAway {
            var queued = false
            for card in plan.cards {
                switch card {
                case .askForHelp(let s), .callSignal(let s):
                    if state.queue(s, now: minutes, at: now, simulateReply: isDemo) != nil { queued = true }
                default: break
                }
            }
            if queued { plan = TodayBuilder.build(context) }
        }
        today = plan
        state.keep(plan.reward)
        announceNewSends()
        rug = rewards(days: 28)
    }

    /// Kept rows for past days (they only ever grow); rebuilt only when a day was never kept.
    private func rewards(days: Int) -> [DayReward] {
        Day.range(day - (days - 1), day + 1).map { d in
            if d == day, let r = today?.reward { return r }
            if let kept = state.rewards[d.jdn] { return kept }
            return TodayBuilder.reward(PlannerContext(day: d, now: 23 * 60, state: state, table: table, history: history))
        }
    }

    private func save() {
        if !isDemo { store.save(state) }
        onChange?()
    }

    /// Messages already announced, so each simulated send shows one notification.
    @ObservationIgnored private var announced: Set<String> = []

    private func announceNewSends() {
        let sent = state.outbox.filter { $0.status == .sent || $0.status == .replied }
        defer { announced.formUnion(sent.map(\.id)) }
        guard notifySimulatedSends else { return }
        for m in sent where !announced.contains(m.id) {
            Task { await PlannerNotifications.show(NotificationPlan.messageSent(m)) }
        }
    }
}

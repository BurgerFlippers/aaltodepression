import SwiftUI

// TEMPORARY backend testing area. Owned by backend, not the real design (see CLAUDE.md).
// Every page only calls the public backend API (Store/Planner.swift, Engine/, Sources/), so the
// frontend can build the real screens on the same calls and delete this folder afterwards.
// Opened from Settings → "Backend testing".

/// Shared state for the testing pages: which data the backend runs on, and the backend itself.
@MainActor @Observable
final class BackendLab {
    var useMyData = false { didSet { reload() } }
    var demoDay = 50 { didSet { reload() } }
    /// Moving the clock keeps what was done today; only a new day starts over.
    var clockHour = 17 { didSet { moveClock() } }
    /// The same object the frontend will own (Store/Backend.swift). Starts empty and cheap; the demo is
    /// built on first open (`attach`), not every time Settings draws.
    private(set) var backend = Backend(planner: Planner(store: .memory, isDemo: true))
    /// Signals the backend sees and the step engine's days, for the data pages.
    private(set) var table = FeatureTable()
    private(set) var history: [StepDay] = []
    /// Setup edits made on the demo, kept when the demo day changes.
    var demoSetup: PlannerSetup?
    @ObservationIgnored private weak var model: AppModel?

    var planner: Planner { backend.planner }
    var tracking: TrackingService { backend.tracking }
    /// Sensor signals plus the person's own answers (screen time), as the backend sees them.
    var signals: FeatureTable { planner.withAnswers(table) }
    /// The demo day's scripted check-in, used to prefill the check-in form so each story replays.
    var demoCheckIn: CheckIn? { useMyData ? nil : DemoPlannerSource.checkIn(demoDay) }
    var demoStory: String? {
        guard !useMyData else { return nil }
        switch demoDay {
        case 22: return "Day 22, good stretch: do the prefilled check-in → a card suggests something nice with Ville."
        case 31: return "Day 31, a cold: the prefilled check-in makes the list light; nothing escalates."
        case 50: return "Day 50, food running low on a heavy day: the prefilled check-in sends Sanna a suggestion (see Messages)."
        case 52: return "Day 52, anxious: the prefilled check-in opens the safety card first."
        case 55: return "Day 55, heavier days in the data: the check-in brings a call signal; see Sleep, Activity, Places."
        default: return nil
        }
    }
    var day: Day { useMyData ? Day(Date()) : DemoSource.day(demoDay) }

    func attach(_ model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        reload()
    }

    func reload() {
        if useMyData {
            if backend.isDemo { backend = Backend() }
            table = model?.table ?? FeatureTable()
            history = model?.history ?? []
            backend.refresh(table: table, history: history, locationEnabled: model?.location.isEnabled ?? false)
        } else {
            let full = DemoSource.table()
            table = full.truncated(through: day)
            history = StepEngine.run(table: full, through: day, homeTimeZone: DemoSource.homeTimeZone, locationEnabled: true)
            let notify = backend.planner.notifySimulatedSends
            backend = Backend.demo(day: demoDay, minutes: clockHour * 60 + 30)
            backend.planner.notifySimulatedSends = notify
            if let s = demoSetup { backend.planner.updateSetup(s) }
        }
    }

    func save(_ setup: PlannerSetup) {
        if !useMyData { demoSetup = setup }
        planner.updateSetup(setup)
    }

    /// Re-reads Health, Motion and Location through the app. Rebuilds only "My data"; the demo is kept.
    func readPhoneData() async {
        await model?.readEverything()
        if useMyData { reload() }
    }

    private func moveClock() {
        guard !useMyData else { return }
        backend.refresh(day: day, minutes: clockHour * 60 + 30, table: table, history: history, locationEnabled: true)
    }
}

struct BackendTestingView: View {
    @Environment(AppModel.self) private var model
    @State private var lab = BackendLab()

    var body: some View {
        @Bindable var lab = lab
        List {
            Section {
                Picker("Data", selection: $lab.useMyData) {
                    Text("Demo user").tag(false)
                    Text("My data").tag(true)
                }
                .pickerStyle(.segmented)
                if !lab.useMyData {
                    Stepper("Demo day \(lab.demoDay)", value: $lab.demoDay, in: 1...59)
                    Stepper("Clock \(String(format: "%02d:30", lab.clockHour))", value: $lab.clockHour, in: 6...23)
                    HStack {
                        ForEach([22, 31, 50, 52, 55], id: \.self) { d in
                            Button("\(d)") { lab.demoDay = d }.buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Data source")
            } footer: {
                Text(lab.useMyData
                     ? "Your own Health data and setup, saved on this phone. Messages are simulated; nothing is sent."
                     : "Demo user: 60 synthetic days. 22 good stretch · 31 cold · 50 food low · 52 anxious · 55 heavier days. A new day starts that day over; the clock keeps what you did.")
            }

            Section("Overview") {
                NavigationLink { CoveragePage() } label: { row("What the backend covers", "checklist", "The task board, item by item") }
                NavigationLink { IntegrationPage() } label: { row("Frontend integration", "puzzlepiece.extension", "One object, what each screen reads and calls") }
            }
            Section("Ask and set up") {
                NavigationLink { PermissionsPage(lab: lab) } label: { row("Permissions", "lock.shield", "backend.permissions · real iOS prompts") }
                NavigationLink { SetupPage(lab: lab) } label: { row("Setup", "person.2", "planner.setup · contacts, medication, must-dos, times") }
                NavigationLink { QuestionsPage(lab: lab) } label: { row("Questions and answers", "questionmark.bubble", "QuestionCatalog · generic questions, answer log") }
            }
            Section("Every day") {
                NavigationLink { DailyFlowPage(lab: lab) } label: { row("Daily flow", "sun.horizon", "planner.today · check-in, list, cards, reward") }
                NavigationLink { MessagesPage(lab: lab) } label: { row("Messages to contacts", "message", "planner.outbox · what would have been sent") }
                NavigationLink { RemindersPage(lab: lab) } label: { row("Reminders", "bell", "NotificationPlan · what goes on the lock screen") }
                NavigationLink { SafetyPage(lab: lab) } label: { row("Safety flow", "cross.case", "planner.safety · anxious → questions → help") }
            }
            Section {
                NavigationLink { SleepPage(lab: lab) } label: { row("Sleep", "bed.double", "tracking.sleep · last night against your usual") }
                NavigationLink { ActivityPage(lab: lab) } label: { row("Activity", "figure.walk", "tracking.activity · today so far, by the hour") }
                NavigationLink { PlacesPage(lab: lab) } label: { row("Places", "mappin.and.ellipse", "tracking.places · daily numbers, no coordinates") }
                NavigationLink { ScreenTimePage(lab: lab) } label: { row("Screen time (bonus)", "iphone", "tracking.snapshot.screenTime · your own answers") }
                NavigationLink { DataTypesPage(lab: lab) } label: { row("Data types", "tablecells", "Every input kind and signal, with live values") }
            } header: {
                Text("Tracking")
            } footer: {
                Text("Temporary screens to show and test the backend. Not the final design. Each row names what the frontend uses.")
            }
        }
        .navigationTitle("Backend testing")
        .onAppear { lab.attach(model) }
    }

    private func row(_ title: String, _ icon: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: icon) }
    }
}

// MARK: - Frontend integration

private struct IntegrationPage: View {
    private let rows: [(screen: String, reads: String, calls: String)] = [
        ("App start (AppModel)", "–", "let backend = Backend() · backend.refresh(table:history:locationEnabled:) after each Health read and on app activation"),
        ("Onboarding: permissions", "backend.permissions.status[kind], PermissionKind.title / .reason (refreshed by Backend)", "await backend.permissions.request(kind) or requestAll() · refresh()"),
        ("Onboarding: contacts", "planner.setup.contacts, ContactIntake.problem(contact)", "system picker → planner.addContacts([(name, phone)]); edit → planner.updateSetup(_)"),
        ("Onboarding: times, medication, must-dos, clinic", "planner.setup", "planner.updateSetup(_) (also schedules reminders)"),
        ("Home: check-in", "planner.today.needsCheckIn, QuestionCatalog.checkIn", "planner.submitCheckIn([questionID: Answer])"),
        ("Home: shop question", "planner.today.asksAboutGroceries", "planner.answerGroceries(_)"),
        ("Home: plans with people", "planner.today.upcomingPlans, planner.today.asksAboutSocial", "planner.acceptSocial(_) · planner.answerSocial(planID:met:)"),
        ("Home: screen time (bonus)", "planner.today.asksAboutScreenTime, QuestionCatalog.screenTimeQuestions", "planner.answerScreenTime([questionID: Answer])"),
        ("Home: today's list", "planner.today.items (title, detail, time, status, evidence, canShrink)", "planner.mark(item, .done/.skipped/.open) · planner.shrink(item)"),
        ("Home: one card", "planner.today.cards.first", "send(_) · dismiss(_) · acceptSocial(_) · startSafety()"),
        ("Home: messages", "planner.messagesToday, planner.openMessages", "confirm(messageID:) · cancel(messageID:)"),
        ("Safety sheet", "planner.safety?.step, SafetyCopy", "safetyContinue() · safetyAnswer(_) · finishSafety()"),
        ("Get help now", "planner.crisisLines", "– (no questions)"),
        ("Reward", "planner.today.reward, planner.rug, planner.weekSummary", "–"),
        ("Sleep / activity / places / screen time", "backend.tracking.sleep / .activity / .places / .snapshot?.screenTime (TrackedValue: text, usualText, comparison)", "–"),
        ("Notifications (app delegate)", "–", "PlannerNotifications.registerCategories() at launch · action(for:) → planner.handle(_:deliveredAt:)"),
        ("Settings: erase", "–", "planner.eraseAll()"),
    ]

    var body: some View {
        List {
            Section {
                Text("The frontend owns one `Backend` object. Every screen reads plain data from it and calls one method per tap. Nothing in Engine/ imports SwiftUI, so all of it is tested by Tools/engine-check.sh.")
                    .font(.callout)
            }
            ForEach(rows, id: \.screen) { r in
                Section(r.screen) {
                    LabeledContent("Reads") { Text(r.reads).font(.caption.monospaced()).multilineTextAlignment(.trailing) }
                    LabeledContent("Calls") { Text(r.calls).font(.caption.monospaced()).multilineTextAlignment(.trailing) }
                }
            }
            Section("Files") {
                Text("Engine/Contracts: the types screens use").font(.caption)
                Text("Engine/Planner, Engine/Tracking: rules and analysis (pure Swift)").font(.caption)
                Text("Store/Backend.swift, Planner.swift, Permissions.swift, PlannerNotifications.swift: services").font(.caption)
                Text("docs/BACKEND_API.md: the same guide as text").font(.caption)
            }
        }
        .navigationTitle("Frontend integration")
    }
}

// MARK: - Coverage

private struct CoveragePage: View {
    private enum Status { case done, simulated, later }
    private struct Item: Identifiable { let text: String; let how: String; let state: Status; var id: String { text } }

    private let groups: [(String, [Item])] = [
        ("Categories", [
            .init(text: "Food and grocery shopping", how: "Plate-model shopping list, easy plates on heavy days", state: .done),
            .init(text: "Movement", how: "Sized to the day; at least a breath of fresh air; sensors tick it", state: .done),
            .init(text: "Sleep", how: "Evening wind-down at a set time; sleep data from Health", state: .done),
            .init(text: "People", how: "Plans with friends in good stretches", state: .done),
            .init(text: "Medication", how: "Reminders; doses from Health on iOS 26", state: .done),
            .init(text: "Must-dos (laundry, bills)", how: "Come back every few days; none on a heavy day", state: .done),
        ]),
        ("From the phone", [
            .init(text: "Sleep data", how: "Duration, timing, regularity, wake time", state: .done),
            .init(text: "Activity data", how: "Steps, hourly steps, walking, exercise, walking speed", state: .done),
            .init(text: "HRV", how: "Plus resting heart rate, breathing rate, wrist temperature", state: .done),
            .init(text: "Location", how: "Daily numbers only: time at home, places, distance", state: .done),
            .init(text: "Contact people", how: "Picked with the system picker; no address book access", state: .done),
        ]),
        ("The person answers", [
            .init(text: "Grocery shopping", how: "Food at home + \"Did you get to the shop?\"", state: .done),
            .init(text: "Mood", how: "1–5 scale", state: .done),
            .init(text: "Coping / energy", how: "3-step scale plus feeling words", state: .done),
        ]),
        ("Interventions", [
            .init(text: "No food or no shop → contact gets a tip", how: "Invite to eat, pick up groceries, shop together", state: .simulated),
            .init(text: "Going well → plan something social", how: "After 3 good days, at most once a week", state: .done),
            .init(text: "Data alone → a call would be welcome", how: "Days off the person's usual, or heavy check-ins", state: .simulated),
            .init(text: "Suicidal thoughts → emergency numbers", how: "C-SSRS screener; wording needs clinician review", state: .done),
            .init(text: "Early signs → tell the clinic", how: "Short sleep, missed medication, long drift", state: .done),
        ]),
        ("Also", [
            .init(text: "Reward when things go well", how: "Rag rug: threads, stars, gold knots; nothing is unpicked", state: .done),
            .init(text: "Learns what helps this person", how: "Insights after 5+ examples; smaller list if often skipped", state: .done),
            .init(text: "Sleep, activity and places analysis", how: "Each value against the person's own 28-day usual, with trends", state: .done),
            .init(text: "Reminders", how: "Check-in, medicine times, shop question, wind-down; local only", state: .done),
            .init(text: "Screen time (bonus)", how: "Optional morning question or exact minutes from Settings; Apple doesn't let apps read it directly", state: .simulated),
            .init(text: "Real SMS to contacts", how: "Simulated in the prototype", state: .later),
            .init(text: "Crisis detection from sensors", how: "Never: the app asks instead", state: .later),
        ]),
    ]

    var body: some View {
        List {
            ForEach(groups, id: \.0) { title, items in
                Section(title) {
                    ForEach(items) { i in
                        HStack(alignment: .top) {
                            Image(systemName: i.state == .done ? "checkmark.circle.fill" : i.state == .simulated ? "circle.lefthalf.filled" : "minus.circle")
                                .foregroundStyle(i.state == .done ? Color.green : i.state == .simulated ? Color.orange : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(i.text)
                                Text(i.how).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                Label("Done in the backend", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Label("Works, sending is simulated", systemImage: "circle.lefthalf.filled").foregroundStyle(.orange)
                Label("Not in the prototype", systemImage: "minus.circle").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("What the backend covers")
    }
}

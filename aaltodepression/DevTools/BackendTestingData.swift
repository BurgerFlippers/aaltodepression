import SwiftUI
import UserNotifications

// TEMPORARY backend testing area (see BackendTestingView.swift).

// MARK: - Permissions

struct PermissionsPage: View {
    let lab: BackendLab
    @State private var reading = false

    var body: some View {
        let center = lab.backend.permissions
        List {
            Section {
                ForEach(PermissionKind.allCases) { kind in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(kind.title).font(.headline)
                            Spacer()
                            Button("Ask") { Task { await center.request(kind) } }.buttonStyle(.bordered)
                        }
                        Text(center.status[kind]?.text ?? "…").font(.callout).foregroundStyle(.tint)
                        Text(kind.reason).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                Button("Ask for all (onboarding order)") { Task { await center.requestAll() } }
            } header: {
                Text("backend.permissions")
            } footer: {
                Text("Real iOS prompts. A prompt shows only once; later answers are changed in the Settings app. Health never tells an app what was allowed, so it shows \"Asked\".")
            }
            Section {
                LabeledContent("Contacts", value: "No permission: system picker")
                LabeledContent("Not asked", value: "Calendar, photos, mic, camera, messages")
            }
            Section {
                Button {
                    reading = true
                    Task { await lab.readPhoneData(); reading = false }
                } label: {
                    HStack { Text("Read phone data now"); Spacer(); if reading { ProgressView() } }
                }
                .disabled(reading)
            } footer: {
                Text("Then switch Data source to \"My data\" and open Sleep, Activity, Places or Data types.")
            }
        }
        .navigationTitle("Permissions")
        .task { await center.refresh() }
        .refreshable { await center.refresh() }
    }
}

// MARK: - Reminders

struct RemindersPage: View {
    let lab: BackendLab
    @State private var pending: [String] = []

    var body: some View {
        let plan = NotificationPlan.daily(for: lab.planner.setup)
        List {
            Section {
                ForEach(plan) { n in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(n.title).font(.headline)
                            Spacer()
                            Text(PlanFormat.clock(n.time) + (n.weekday.map { " " + ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][$0 - 1] } ?? " daily"))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Text(n.body).font(.callout)
                        if let c = n.category {
                            Text(c == .medication ? "Buttons: Taken · Remind me in 30 min" : "Buttons: Yes · Not today")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions { Button("Show") { Task { await PlannerNotifications.show(n, after: 5) } }.tint(.blue) }
                }
            } header: {
                Text("NotificationPlan.daily(for: setup)")
            } footer: {
                Text("Swipe a row and tap Show, then lock the phone: it appears in 5 s. Texts never name a medicine or a feeling. The safety questions are never asked from a notification.")
            }
            Section {
                Button("Schedule all of these") {
                    PlannerNotifications.registerCategories()
                    Task { await PlannerNotifications.schedule(for: lab.planner.setup); await load() }
                }
                .disabled(!lab.useMyData)
                Button("Remove planner reminders", role: .destructive) {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pending)
                    Task { await load() }
                }
            } footer: {
                Text(lab.useMyData
                     ? "Buttons in a notification update the planner once the app delegate calls planner.handle(_:deliveredAt:) (see Frontend integration)."
                     : "Scheduling is off in the demo so the Demo user's medicine times never land on your phone. Use swipe → Show, or switch to My data.")
            }
            Section("Scheduled now (\(pending.count))") {
                if pending.isEmpty { Text("None").foregroundStyle(.secondary) }
                ForEach(pending, id: \.self) { Text($0).font(.caption.monospaced()) }
            }
        }
        .navigationTitle("Reminders")
        .task { await load() }
    }

    private func load() async {
        pending = await withCheckedContinuation { (c: CheckedContinuation<[String], Never>) in
            UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                c.resume(returning: reqs.map(\.identifier).filter { $0.hasPrefix(PlannerNotifications.prefix) }.sorted())
            }
        }
    }
}

// MARK: - Data types

struct DataTypesPage: View {
    let lab: BackendLab

    private struct Input: Identifiable {
        let name: String, kind: String, values: String, api: String
        var id: String { name }
    }

    private let inputs: [Input] = [
        .init(name: "Mood", kind: "Likert 1–5", values: "😞 … 😄", api: "Answer.number · CheckIn.mood"),
        .init(name: "Energy / coping", kind: "3-step scale", values: "Not much · Some · Plenty", api: "Answer.option · CheckIn.energy"),
        .init(name: "Feelings", kind: "Multi-select toggles", values: "Calm · Good · Tired · Low · Anxious or restless", api: "Answer.options · CheckIn.feelings"),
        .init(name: "Food at home", kind: "Single choice", values: "Yes, enough · Running low · Hardly anything", api: "Answer.option · CheckIn.foodAtHome"),
        .init(name: "Did you get to the shop?", kind: "Yes / no", values: "Shop days, in the app or from a notification", api: "Answer.yes · answerGroceries(_:)"),
        .init(name: "Safety questions", kind: "Yes / no, branching", values: "Up to 7, C-SSRS screener; never stored", api: "safetyAnswer(_:)"),
        .init(name: "Social follow-up", kind: "Yes / no", values: "Did you get to meet?", api: "answerSocial(planID:met:)"),
        .init(name: "Screen time, rough (bonus)", kind: "Single choice", values: "Under 1 h · 1–2 h · 2–4 h · 4–6 h · Over 6 h", api: "Answer.option · answerScreenTime(_:)"),
        .init(name: "Screen time, exact (bonus)", kind: "Number", values: "0–960 min in 15 min steps, from Settings → Screen Time", api: "Answer.number · AnswerKind.numeric"),
        .init(name: "Phone in bed (bonus)", kind: "Yes / no", values: "After lights out, yesterday", api: "Answer.yes · answerScreenTime(_:)"),
        .init(name: "List items", kind: "Tap / swipe", values: "Done · Not today · Make smaller · Undo", api: "mark(_:_:) · shrink(_:)"),
        .init(name: "Cards and messages", kind: "Buttons", values: "Send · Not now · Plan it · Cancel", api: "send · dismiss · acceptSocial · cancel"),
        .init(name: "Contact people", kind: "Picker + text + toggles", values: "Name, phone, relation, kinds of help, agreed", api: "addContacts · PlannerSetup.contacts"),
        .init(name: "Medication", kind: "Text + clock times", values: "Name, one or more dose times", api: "PlannerSetup.medications"),
        .init(name: "Must-dos", kind: "Text + interval", values: "Title, every 1–30 days", api: "PlannerSetup.chores"),
        .init(name: "Daily times", kind: "Clock", values: "Wake-up, check-in, bedtime", api: "PlannerSetup times (minutes)"),
        .init(name: "Shopping days", kind: "Weekday multi-select", values: "Mon–Sun", api: "PlannerSetup.shoppingWeekdays"),
        .init(name: "Suggestions to contacts", kind: "Single choice", values: "Send right away · Ask me each time", api: "PlannerSetup.helpConsent"),
        .init(name: "Clinic", kind: "Text", values: "Name, phone", api: "PlannerSetup.clinicName / clinicPhone"),
        .init(name: "Small good things", kind: "Free text list", values: "e.g. sauna, coffee on the balcony", api: "PlannerSetup.goodThings"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(inputs) { i in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text(i.name).font(.headline); Spacer(); Text(i.kind).font(.caption).foregroundStyle(.tint) }
                        Text(i.values).font(.caption)
                        Text(i.api).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("What the person enters (\(inputs.count))")
            }

            Section {
                derived("Capacity today", "\(lab.planner.today?.capacity ?? .ok)", "low · ok · good, from the check-in and the data; sizes the list")
                derived("Drift step (yesterday)", stepText, "steady · step 1 (5 of 7 days off the usual) · step 2 (10 more days)")
                derived("Steadiness (yesterday)", steadiness, "0–100 against the person's own 28-day usual")
                derived("Screen time yesterday (bonus)", lab.tracking.snapshot?.screenTime?.hours.text ?? "–", "your own answer, compared with your own usual")
                derived("Short nights in a row", "\(lab.tracking.sleep?.shortNights ?? 0) of 3", "clearly below the usual")
                derived("Movement seen today", movement, "exercise, workouts, minutes on foot, hours with 800+ steps")
                derived("Insights", "\(lab.planner.today?.insights.count ?? 0)", "\"seems to help\" lines after 5+ examples")
            } header: {
                Text("What the backend works out")
            }

            ForEach(SignalSource.allCases, id: \.self) { source in
                let rows = (FeatureCatalog.all + FeatureCatalog.selfReport).filter { $0.source == source }
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { info in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.title)
                                    Text("\(info.device.rawValue) · \(lab.signals.dayCount(info.key)) days\(info.note.map { " · \($0)" } ?? "")")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(latest(info)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("\(source.rawValue) (\(rows.count))")
                    }
                }
            }
        }
        .navigationTitle("Data types")
    }

    private func derived(_ title: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(title); Spacer(); Text(value).foregroundStyle(.tint) }
            Text(note).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var yesterday: StepDay? { lab.history.first { $0.day == lab.day - 1 } }
    private var stepText: String {
        switch yesterday?.step {
        case .steady?: "steady"
        case .nudge?: "step 1"
        case .reachOut?: "step 2"
        case nil: "–"
        }
    }
    private var steadiness: String { yesterday?.result.steadiness.map { "\(Int($0.rounded()))" } ?? "–" }
    private var movement: String {
        let m = lab.tracking.activity?.movementMinutes ?? 0
        return m > 0 ? "\(Int(m)) min" : "–"
    }

    /// Latest value on or before the day, in the signal's own unit.
    private func latest(_ info: SignalInfo) -> String {
        let t = lab.signals
        guard let d = t.lastDay(info.key, onOrBefore: lab.day) else { return "–" }
        if let text = t.text(info.key, d) { return text }
        return t.value(info.key, d).map { ValueText.format($0, info.format) } ?? "–"
    }
}

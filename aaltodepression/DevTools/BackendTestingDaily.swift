import SwiftUI

// TEMPORARY backend testing area (see BackendTestingView.swift). Type names start with "Lab"
// so they never clash with the frontend's own views.

struct DailyFlowPage: View {
    let lab: BackendLab
    @State private var showSafety = false
    @State private var showHelpNow = false

    var body: some View {
        let planner = lab.planner
        List {
            if let plan = planner.today {
                Section {
                    if let story = lab.demoStory { Label(story, systemImage: "theatermasks").font(.callout).foregroundStyle(.tint) }
                    Text(plan.headline).font(.headline)
                    LabeledContent("Capacity (internal, never shown)", value: "\(plan.capacity)")
                } footer: {
                    Text(lab.useMyData ? "Today, from your own data." : "Demo user, day \(lab.demoDay), clock \(String(format: "%02d:30", lab.clockHour)).")
                }
                if plan.needsCheckIn { LabCheckInSection(planner: planner, preset: lab.demoCheckIn) }
                if plan.asksAboutGroceries {
                    Section("Did you get to the shop today?") {
                        HStack {
                            Button("Yes") { planner.answerGroceries(true) }.buttonStyle(.borderedProminent)
                            Button("Not today") { planner.answerGroceries(false) }.buttonStyle(.bordered)
                        }
                    }
                }
                if plan.asksAboutScreenTime { LabScreenTimeSection(planner: planner) }
                if let p = plan.asksAboutSocial {
                    Section("Did you get to meet? (planner.today.asksAboutSocial)") {
                        Text("\(p.activity.capitalizedFirst)\(p.contactName.map { " with \($0)" } ?? "") on \(MessageTemplates.weekdayName(p.day))")
                        HStack {
                            Button("Yes") { planner.answerSocial(planID: p.id, met: true) }.buttonStyle(.borderedProminent)
                            Button("It moved") { planner.answerSocial(planID: p.id, met: false) }.buttonStyle(.bordered)
                        }
                    }
                }
                if !plan.upcomingPlans.isEmpty {
                    Section("Plans with people (planner.today.upcomingPlans)") {
                        ForEach(plan.upcomingPlans) { p in
                            Text("\(p.activity.capitalizedFirst)\(p.contactName.map { " with \($0)" } ?? "") · \(MessageTemplates.weekdayName(p.day))")
                        }
                    }
                }
                if !plan.cards.isEmpty {
                    Section("Cards (the real screen shows only the first)") {
                        ForEach(plan.cards) { card in LabCardRow(card: card, planner: planner, showSafety: $showSafety) }
                    }
                }
                let messages = (planner.openMessages + planner.messagesToday).reduce(into: [OutgoingMessage]()) { acc, m in
                    if !acc.contains(where: { $0.id == m.id }) { acc.append(m) }
                }
                if !messages.isEmpty {
                    Section("Messages to close people (simulated)") {
                        ForEach(messages) { m in LabMessageRow(message: m, planner: planner) }
                    }
                }
                Section {
                    ForEach(plan.items) { item in LabItemRow(item: item, planner: planner) }
                } header: {
                    Text("Today")
                } footer: {
                    Text("Tap to tick. Swipe left for \"Not today\" or \"Smaller\".")
                }
                Section("Reward") {
                    LabRewardView(reward: plan.reward, rug: planner.rug)
                    Text(planner.weekSummary).font(.footnote).foregroundStyle(.secondary)
                }
                if !plan.insights.isEmpty {
                    Section("What seems to help") {
                        ForEach(plan.insights, id: \.self) { Text($0).font(.callout) }
                    }
                }
                if !plan.needsCheckIn {
                    Section { LabCheckInSection(planner: planner, redo: true, preset: lab.demoCheckIn) }
                }
            } else {
                Text("Loading…")
            }
        }
        .navigationTitle("Daily flow")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("I need help now") { showHelpNow = true } }
        }
        .sheet(isPresented: $showSafety, onDismiss: { planner.finishSafety() }) { LabSafetySheet(planner: planner) }
        .sheet(isPresented: $showHelpNow) { LabHelpNowSheet(lines: planner.crisisLines, setup: planner.setup) }
    }
}

// MARK: - Check-in

struct LabCheckInSection: View {
    let planner: Planner
    var redo = false
    /// Demo: the day's scripted answers, so the story replays with one tap on Done.
    var preset: CheckIn? = nil
    @State private var open = false
    @State private var mood = 3
    @State private var energy: Energy = .some
    @State private var feelings: Set<Feeling> = []
    @State private var food: FoodAtHome = .enough

    var body: some View {
        if redo && !open {
            Button("Redo today's check-in") { open = true }
        } else {
            Section(redo ? "Check-in again" : preset == nil ? "Good morning. How is today feeling?" : "Check-in (prefilled with the demo day's answers)") {
                Picker("Mood", selection: $mood) {
                    ForEach(1...5, id: \.self) { Text(["😞", "🙁", "😐", "🙂", "😄"][$0 - 1]).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Energy", selection: $energy) {
                    ForEach(Energy.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ForEach(Feeling.allCases) { f in
                    Toggle(f.title, isOn: Binding(get: { feelings.contains(f) },
                                                  set: { if $0 { feelings.insert(f) } else { feelings.remove(f) } }))
                }
                Picker("Food at home", selection: $food) {
                    ForEach(FoodAtHome.allCases) { Text($0.title).tag($0) }
                }
                Button("Done") {
                    planner.checkIn(mood: mood, energy: energy, feelings: feelings, foodAtHome: food)
                    open = false
                }
                .buttonStyle(.borderedProminent)
            }
            .onAppear {
                guard let p = preset else { return }
                mood = p.mood; energy = p.energy; feelings = p.feelings; food = p.foodAtHome ?? .enough
            }
        }
    }
}

// MARK: - Cards

struct LabCardRow: View {
    let card: Card
    let planner: Planner
    @Binding var showSafety: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch card {
            case .safetyCheck:
                Text("A few questions, because today feels heavy").font(.headline)
                Button("Open the questions") { planner.startSafety(); showSafety = true }.buttonStyle(.borderedProminent)
            case .clinic(let c):
                Text("Tell your clinic").font(.headline)
                Text(c.reason)
                Text("Call \(c.phone)").font(.callout.monospacedDigit())
            case .askForHelp(let s), .callSignal(let s):
                Text(isCall ? "A call would be welcome" : "Ask \(s.contact.name) for a hand").font(.headline)
                Text(s.reason).foregroundStyle(.secondary)
                Text(s.message).font(.callout).padding(8).background(.quaternary, in: .rect(cornerRadius: 8))
                Button("Send to \(s.contact.name)") { planner.send(s) }.buttonStyle(.borderedProminent)
            case .social(let s):
                Text("Plan something nice").font(.headline)
                Text(s.reason).foregroundStyle(.secondary)
                Text(s.message).font(.callout).padding(8).background(.quaternary, in: .rect(cornerRadius: 8))
                Button("Plan it") { planner.acceptSocial(s) }.buttonStyle(.borderedProminent)
                Text("Planned items appear under \"Plans with people\" and on that day's list.").font(.caption2).foregroundStyle(.secondary)
            }
            if card != .safetyCheck {
                Button("Not now") { planner.dismiss(card) }.font(.callout)
            }
        }
        .padding(.vertical, 4)
    }

    private var isCall: Bool { if case .callSignal = card { true } else { false } }
}

// MARK: - Messages

struct LabMessageRow: View {
    let message: OutgoingMessage
    let planner: Planner

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("To \(message.contactName)", value: "\(message.status)")
            Text(message.text).font(.callout).padding(8).background(.tint.opacity(0.15), in: .rect(cornerRadius: 10))
            if let reply = message.simulatedReply, message.status == .replied {
                Text("\(message.contactName): \(reply)").font(.callout).padding(8)
                    .background(.quaternary, in: .rect(cornerRadius: 10))
            }
            HStack {
                if message.status == .pending { Button("Send") { planner.confirm(messageID: message.id) } }
                if message.status == .sent { Button("Simulate reply") { planner.receiveReply(messageID: message.id) } }
                if message.status == .pending || message.status == .sent {
                    Button("Cancel", role: .destructive) { planner.cancel(messageID: message.id) }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Items

struct LabItemRow: View {
    let item: PlanItem
    let planner: Planner

    var body: some View {
        Button {
            planner.mark(item, item.status == .done ? .open : .done)
        } label: {
            HStack(alignment: .top) {
                Image(systemName: item.status == .done ? "checkmark.circle.fill" : item.status == .skipped ? "minus.circle" : "circle")
                    .foregroundStyle(item.status == .done ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.title)
                        if let t = item.time { Text(PlanFormat.clock(t)).foregroundStyle(.secondary).monospacedDigit() }
                    }
                    if let d = item.detail { Text(d).font(.caption).foregroundStyle(.secondary) }
                    if let e = item.evidence { Text("✓ \(e)").font(.caption).foregroundStyle(.tint) }
                    if let g = item.groceries {
                        Text(g.map(\.name).joined(separator: ", ")).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("\(item.pillar.title) · \(String(describing: item.size))\(item.doneBy.map { " · by \($0)" } ?? "")")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Not today") { planner.mark(item, .skipped) }.tint(.gray)
            if item.canShrink { Button("Smaller") { planner.shrink(item) }.tint(.blue) }
        }
    }
}

// MARK: - Reward

struct LabRewardView: View {
    let reward: DayReward
    let rug: [DayReward]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Pillar.allCases) { p in
                    Text(p.title).font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(reward.threads.contains(p) ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1), in: .capsule)
                }
            }
            HStack {
                if reward.star { Text("★ All the basics") }
                if reward.goldKnots > 0 { Text("Gold knots: \(reward.goldKnots)") }
            }
            if let m = reward.message { Text(m).font(.callout) }
            // The last four weeks, one thin row per day; stronger with more threads, orange with a star.
            VStack(spacing: 2) {
                ForEach(rug, id: \.day) { r in
                    let n = r.threads.count + (r.checkedIn ? 1 : 0)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(r.star ? Color.orange : Color.accentColor.opacity(0.15 + 0.12 * Double(n)))
                        .frame(height: 3)
                }
            }
        }
    }
}

// MARK: - Safety

struct LabSafetySheet: View {
    let planner: Planner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                switch planner.safety?.step ?? .bridge {
                case .bridge:
                    Text(SafetyCopy.bridgeTitle).font(.title2.bold())
                    Text(SafetyCopy.bridgeBody)
                    Text(SafetyCopy.dataNote).font(.footnote).foregroundStyle(.secondary)
                    Button("Continue") { planner.safetyContinue() }.buttonStyle(.borderedProminent)
                case .ask(let q):
                    Text(SafetyCopy.timeframe).foregroundStyle(.secondary)
                    Text(SafetyCopy.text(q)).font(.title3)
                    HStack(spacing: 16) {
                        Button("Yes") { planner.safetyAnswer(true) }.frame(maxWidth: .infinity)
                        Button("No") { planner.safetyAnswer(false) }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                case .done(let o):
                    Text(SafetyCopy.title(o)).font(.title2.bold())
                    Text(SafetyCopy.body(o, clinic: planner.setup.clinicName))
                    LabCrisisLineList(lines: SafetyCopy.lines(for: o))
                }
                Spacer()
                Text("Working draft. Wording must be reviewed by a clinician before real use.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct LabHelpNowSheet: View {
    let lines: [CrisisLine]
    let setup: PlannerSetup
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Get help now").font(.title2.bold())
                Text("If your life is in danger, call 112.")
                LabCrisisLineList(lines: lines)
                if !setup.clinicPhone.isEmpty {
                    LabeledContent(setup.clinicName.isEmpty ? "Your clinic" : setup.clinicName.capitalizedFirst, value: setup.clinicPhone)
                }
                Spacer()
            }
            .padding()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct LabCrisisLineList: View {
    let lines: [CrisisLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines) { l in
                VStack(alignment: .leading) {
                    Text(l.name).font(.headline)
                    Text("\(l.number) · \(l.note)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Safety page

struct SafetyPage: View {
    let lab: BackendLab
    @State private var showSafety = false
    @State private var showHelpNow = false

    var body: some View {
        List {
            Section {
                Button("Start the safety questions") { lab.planner.startSafety(); showSafety = true }
                Button("I need help now (no questions)") { showHelpNow = true }
            } footer: {
                Text("Normally opened by the safety card on Today. Answers are never stored; only that the day was heavy, which keeps the list light.")
            }
            Section("When the questions open") {
                Text("Check-in has \"Anxious or restless\", or the lowest mood.")
                Text("\"Low\" or mood 2, and the data points the same way: three short nights, days off the usual, or a very unpleasant State of Mind.")
                Text("At most once a day, never from a notification. \"Low\" alone at most every three days.")
            }
            Section("Questions (C-SSRS screener, past month)") {
                ForEach(SafetyQuestion.allCases, id: \.self) { q in
                    Text(SafetyCopy.text(q)).font(.callout)
                }
            }
            Section("Where the answers lead") {
                ForEach([SafetyOutcome.noThoughts, .talkSoon, .contactCareToday, .urgent], id: \.self) { o in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SafetyCopy.title(o)).font(.headline)
                        Text(SafetyCopy.lines(for: o).map(\.number).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Safety flow")
        .sheet(isPresented: $showSafety, onDismiss: { lab.planner.finishSafety() }) { LabSafetySheet(planner: lab.planner) }
        .sheet(isPresented: $showHelpNow) { LabHelpNowSheet(lines: lab.planner.crisisLines, setup: lab.planner.setup) }
    }
}

/// The optional morning screen-time question, rendered with the generic question views.
struct LabScreenTimeSection: View {
    let planner: Planner
    @State private var answers: [String: Answer] = [:]

    var body: some View {
        Section {
            LabQuestionView(question: QuestionCatalog.screenTime, answer: $answers[QuestionCatalog.screenTime.id])
            LabQuestionView(question: QuestionCatalog.phoneInBed, answer: $answers[QuestionCatalog.phoneInBed.id])
            Button("Save") { planner.answerScreenTime(answers) }.disabled(answers.isEmpty)
        } header: {
            Text("Optional: yesterday's phone time")
        } footer: {
            Text("planner.today.asksAboutScreenTime · planner.answerScreenTime(_:). Can be switched off in Setup.")
        }
    }
}

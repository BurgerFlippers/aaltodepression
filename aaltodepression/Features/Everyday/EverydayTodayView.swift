import SwiftUI

struct EverydayTodayView: View {
    var showDayPicker = false
    @Environment(EverydayStore.self) private var store
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editBoxes = false
    @State private var selectedBox: BesideHomeBox?
    @State private var showHelp = false
    @State private var showMessages = false
    @State private var showCheckIn = false
    @State private var showSafety = false
    @State private var messagePersonID: String?
    @State private var messageTopic: SupportTopic?
    @State private var messagePrompt: ReachOutPrompt?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        let name = (presentation.backend.isDemo ? presentation.backend.planner.setup.personName : store.state.profile.name).trimmingCharacters(in: .whitespacesAndNewlines)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(name.isEmpty ? "Hi there." : "Hi, \(name).")
                                    .font(.system(size: 30, weight: .bold, design: .rounded)).accessibilityAddTraits(.isHeader)
                                if presentation.isDemoMode { Text(presentation.day.start().formatted(date: .abbreviated, time: .omitted)).font(.subheadline).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button { editBoxes = true } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }
                                .accessibilityLabel("Edit your boxes")
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                            ForEach(presentation.boxes) { box in categoryBox(box) }
                        }
                        if presentation.winCount > 0 { BesideWinsView() }
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Actions").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                            actionRow(title: presentation.checkIn == nil ? "How is everyday life going?" : "Your check-in", subtitle: presentation.checkIn == nil ? "A quick moment for yourself" : "Saved today · tap to update", color: EverydayStyle.peach) { showCheckIn = true }
                            if let card = presentation.backend.planner.today?.cards.first, case .safetyCheck = card {
                                plannerCard(card)
                            } else if let prompt = presentation.backend.planner.today?.reachOutPrompt, presentation.boxes.contains(where: { $0.pillar == prompt.pillar }) {
                                reachOutCard(prompt)
                            } else if let card = presentation.backend.planner.today?.cards.first { plannerCard(card) }
                            if presentation.backend.planner.today?.asksAboutGroceries == true {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(QuestionCatalog.groceries.prompt).font(.headline)
                                    HStack {
                                        Button("Yes") { presentation.backend.planner.answerGroceries(true) }.buttonStyle(.borderedProminent).foregroundStyle(.white)
                                        Button("Not yet") { presentation.backend.planner.answerGroceries(false) }.buttonStyle(.bordered)
                                    }.controlSize(.large)
                                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 20))
                            }
                            ForEach(presentation.backend.planner.today?.items.filter { item in item.pillar == .meds && !presentation.boxes.contains(.medicine) || item.pillar == .chores && !presentation.boxes.contains(.cleaning) } ?? []) { item in
                                Button { presentation.backend.planner.mark(item, item.status == .done ? .open : .done) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle").font(.title3)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title).font(.headline)
                                            if let time = item.time { Text(PlanFormat.clock(time)).font(.subheadline).foregroundStyle(.secondary) }
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 20))
                                }.buttonStyle(.plain).accessibilityValue(item.status == .done ? "Done" : "Not done")
                            }
                            actionRow(title: "Send a message", subtitle: "Choose a person and open Messages", color: EverydayStyle.lavender) { openMessages() }
                            if let social = presentation.backend.planner.today?.asksAboutSocial {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(social.contactName.map { "Did you get to meet \($0)?" } ?? "Did you get to meet?").font(.headline)
                                    HStack {
                                        Button("Yes") { presentation.backend.planner.answerSocial(planID: social.id, met: true) }
                                        Button("Another time") { presentation.backend.planner.answerSocial(planID: social.id, met: false) }
                                    }.buttonStyle(.bordered)
                                }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
                            }
                        }
                    }.padding(20)
                }.refreshable { await presentation.refresh() }
                .onChange(of: context.date) { _, _ in Task { await presentation.refresh() } }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showDayPicker { BesideDayPicker() }
            }
            .background(EverydayStyle.paper).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Beside").font(.title2.bold()) }
                ToolbarItem(placement: .topBarTrailing) { Button("Support") { showHelp = true } }
            }
            .sheet(isPresented: $editBoxes) { BesideEditBoxesView() }
            .sheet(isPresented: $showHelp) { EverydayHelpView() }
            .sheet(isPresented: $showMessages) { EverydaySocialView(initialPersonID: messagePersonID, initialTopic: messageTopic, prompt: messagePrompt) }
            .sheet(isPresented: $showCheckIn) { BesideCheckInView() }
            .sheet(isPresented: $showSafety) { BesideSafetyView() }
            .sheet(item: $selectedBox) { box in
                if let task = box.legacyTask { EverydayTaskDetailView(task: task) }
                else if box == .social { EverydaySocialView() }
                else { BesideBoxDetailsView(box: box) }
            }
        }
    }
    private func categoryBox(_ box: BesideHomeBox) -> some View {
        let done = presentation.isDone(box)
        return Button { presentation.toggle(box) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(box.title).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.8)
                    Text(box.subtitle).font(.caption).foregroundStyle(EverydayStyle.ink.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2)
            }.padding(18).frame(maxWidth: .infinity, minHeight: 88)
                .background(box.color, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(EverydayStyle.ink.opacity(done ? 0.35 : 0.08), lineWidth: done ? 2 : 1) }
                .contentShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityLabel("\(box.title), \(box.subtitle)").accessibilityValue(done ? "Done" : "Not done")
            .accessibilityHint(done ? "Double-tap to undo" : "Double-tap to mark as done")
            .accessibilityIdentifier("day-\(box.id)")
            .contextMenu { Button(box == .social ? "Choose a message" : "Details and settings") { selectedBox = box } }
    }
    private func actionRow(title: String, subtitle: String, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
    private func openMessages(personID: String? = nil, topic: SupportTopic? = nil, prompt: ReachOutPrompt? = nil) {
        messagePersonID = personID; messageTopic = topic; messagePrompt = prompt; showMessages = true
    }
    private func reachOutCard(_ prompt: ReachOutPrompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt.title).font(.headline)
            Text("You can ask someone you know.").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button("Reach out") { openMessages(personID: prompt.contact?.id, topic: prompt.topic, prompt: prompt) }
                    .buttonStyle(.borderedProminent).foregroundStyle(.white)
                Button("Not now") { presentation.backend.planner.dismissReachOutPrompt(prompt) }.buttonStyle(.bordered)
            }.controlSize(.large)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(EverydayStyle.mint, in: RoundedRectangle(cornerRadius: 20))
    }
    @ViewBuilder private func plannerCard(_ card: Card) -> some View {
        switch card {
        case .social(let suggestion):
            actionRow(title: "Time with \(suggestion.contact?.name ?? "someone")?", subtitle: suggestion.activity.capitalized, color: EverydayStyle.mint) { openMessages(personID: suggestion.contact?.id, topic: .social) }
        case .clinic(let nudge):
            VStack(alignment: .leading, spacing: 10) {
                Text(nudge.reason).font(.headline)
                if let url = URL(string: "tel:\(nudge.phone.filter { $0.isNumber || $0 == "+" })"), !nudge.phone.isEmpty { Link("Call \(nudge.clinicName)", destination: url) }
                else { Text("You can contact your care team.").font(.subheadline) }
            }.padding(18).background(EverydayStyle.peach, in: RoundedRectangle(cornerRadius: 20))
        case .safetyCheck:
            actionRow(title: "A moment to check in", subtitle: "A few questions, at your own pace") { if SafetyCopy.reviewedByClinician { presentation.backend.planner.startSafety(); showSafety = true } else { showHelp = true } }
        case .askForHelp(let suggestion), .callSignal(let suggestion):
            actionRow(title: "Reach out to \(suggestion.contact.name)", subtitle: "A little practical support, on your terms", color: EverydayStyle.mint) { openMessages(personID: suggestion.contact.id, topic: suggestion.kind == .pharmacyRun ? .pharmacy : suggestion.kind == .homeCleaning ? .cleaning : suggestion.kind == .groceryRun || suggestion.kind == .inviteToEat || suggestion.kind == .shopTogether ? .groceries : .social) }
        }
    }
}

struct EverydayTaskDetailView: View {
    let task: EverydayTaskKind
    @Environment(EverydayStore.self) private var store
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var showRoutine = false
    @State private var showSensors = false
    private var box: BesideHomeBox { task == .food ? .eat : task == .movement ? .move : .sleep }
    private var configured: Bool { task != .medication || store.state.profile.usesMedication }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    EverydayHeading(eyebrow: task.category, title: task.title)
                    Text(presentation.item(for: box).detail ?? task.detail).foregroundStyle(.secondary)
                    if task == .movement, let activity = presentation.backend.tracking.activity {
                        LabeledContent("Steps so far", value: activity.stepsSoFar.text)
                        if let evidence = activity.movementEvidence { Text(evidence).font(.footnote).foregroundStyle(.secondary) }
                    }
                    if task == .sleep, let sleep = presentation.backend.tracking.sleep {
                        LabeledContent("Recorded sleep", value: sleep.duration.text)
                        Text("The circle records last night’s rest. You can correct it yourself.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if task == .movement || task == .sleep {
                        Button(task == .movement ? "Movement settings" : "Sleep settings") { showSensors = true }
                            .font(.subheadline).frame(minHeight: 44)
                    }
                    if !configured {
                        Text("Only add a medication reminder if you have your own medication.").font(.subheadline)
                        Button("Edit your rhythm") { showRoutine = true }.buttonStyle(.borderedProminent).foregroundStyle(.white).controlSize(.large)
                    } else if presentation.isDone(box) {
                        Label("Recorded for today", systemImage: "checkmark.circle.fill").font(.headline)
                        Button("Undo today's mark") { presentation.backend.planner.mark(presentation.item(for: box), .open); dismiss() }.buttonStyle(.bordered)
                    } else {
                        Button(task == .medication ? "Taken as instructed" : task == .food ? "I've eaten" : task == .sleep ? "I've rested" : "I've moved") { presentation.backend.planner.mark(presentation.item(for: box), .done); dismiss() }.buttonStyle(.borderedProminent).foregroundStyle(.white).controlSize(.large)
                        Button("Not today") { presentation.backend.planner.mark(presentation.item(for: box), .skipped); dismiss() }.frame(minHeight: 44)
                    }
                    if task == .food { EverydayNotice(text: "Soup and bread, yoghurt and fruit, or a familiar ready meal. Choose what suits you and your dietary needs.") }
                }.padding(24)
            }.background(EverydayStyle.paper)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showSensors) {
                NavigationStack {
                    ScrollView { EverydaySensorSettings().padding(20) }.background(EverydayStyle.paper)
                        .navigationTitle("Movement & sleep").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSensors = false } } }
                }
            }
            .sheet(isPresented: $showRoutine) { NavigationStack { ScrollView { EverydayRoutineFields().padding(24) }.background(EverydayStyle.paper).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showRoutine = false } } } } }
        }
    }
}

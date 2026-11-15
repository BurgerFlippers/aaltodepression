import SwiftUI

/// The live day only. History and editable judging data live in the Demo tab.
struct EverydayTodayView: View {
    @Environment(BesidePresentation.self) private var presentation
    @State private var showHelp = false
    @State private var showMessages = false
    @State private var lastMessageRoute = 0

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    BesideSidequestView().id("daily-sidequest").padding(.horizontal, 16).padding(.vertical, 4)
                }
                .refreshable { await presentation.refresh() }
                .onChange(of: presentation.sidequestFocus) { _, _ in proxy.scrollTo("daily-sidequest", anchor: .top) }
            }
            .background(EverydayStyle.paper)
            .navigationTitle("Mind").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Support", systemImage: "person.2") { showHelp = true } } }
            .onChange(of: presentation.messageFocus, initial: true) { _, value in
                if value > lastMessageRoute { lastMessageRoute = value; showMessages = true }
            }
            .sheet(isPresented: $showHelp) { EverydayHelpView() }
            .sheet(isPresented: $showMessages) {
                EverydaySocialView(sidequest: presentation.sidequest?.selected, smallerQuest: presentation.sidequest?.useSmaller ?? false)
            }
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
                        Button("Edit your rhythm") { showRoutine = true }.buttonStyle(.borderedProminent).tint(EverydayStyle.action).foregroundStyle(.white).controlSize(.large)
                    } else if presentation.isDone(box) {
                        Label("Recorded for today", systemImage: "checkmark.circle.fill").font(.headline)
                        Button("Undo today's mark") { presentation.backend.planner.mark(presentation.item(for: box), .open); dismiss() }.buttonStyle(.bordered)
                    } else {
                        Button(task == .medication ? "Taken as instructed" : task == .food ? "I've eaten" : task == .sleep ? "I've rested" : "I've moved") { presentation.backend.planner.mark(presentation.item(for: box), .done); dismiss() }.buttonStyle(.borderedProminent).tint(EverydayStyle.action).foregroundStyle(.white).controlSize(.large)
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

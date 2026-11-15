import SwiftUI

/// Uses the person's configured Apple Shortcut; no SMS vendor or carrier credentials in Mind.
struct BesideDemoScenarioView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("mind.demo.shortcutConfigured.v1") private var shortcutReady = false
    @State private var load = 0.0
    @State private var armed = false
    @State private var request: OutgoingMessage?
    @State private var showReadings = false
    @State private var showSetup = false
    private var sender: DemoShortcutSender { presentation.demoShortcutSender }
    private var konsta: Contact? {
        presentation.liveBackend.planner.setup.contacts.first {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .split(whereSeparator: { $0.isWhitespace }).contains("konsta") && !ContactIntake.normalized($0.phone).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use simulated data", isOn: Binding(get: { presentation.simulatedData }, set: { presentation.simulatedData = $0 }))
                        .accessibilityIdentifier("demo-simulated-data")
                } header: { Text("Data") } footer: {
                    Text("Replaces Apple Health readings with 60 simulated days ending today: sleep, rhythm, places, movement, heart, mood and food logs. Health is never changed. Turn off to see your own data again.")
                }
                Section {
                    if let offer = presentation.sidequest {
                        ForEach(offer.options) { quest in
                            Label(BesideQuestStyle.brief(quest, smaller: offer.startsSmall), systemImage: BesideQuestStyle.visual(quest))
                                .font(.subheadline)
                        }
                        Text(offer.reason + (offer.startsSmall ? " Smaller versions today." : "")).font(.caption).foregroundStyle(.secondary)
                    } else { Text("No challenges for this day.").foregroundStyle(.secondary) }
                } header: { Text("Challenges now") }
                Section {
                    ForEach(ScoreKind.allCases.filter { $0 != .places || presentation.locationAvailable }) { kind in
                        DemoScoreSlider(kind: kind)
                    }
                    if !presentation.scoreOverrides.isEmpty {
                        Button("Use measured scores") { for kind in ScoreKind.allCases { presentation.setScoreOverride(kind, to: nil) } }
                    }
                } header: { Text("Scores for this day") } footer: {
                    Text("Drag a score and release. The challenges above update right away. Demo copy only.")
                }
                Section {
                    LabeledContent("Demo balance", value: presentation.healthSignal?.result.steadiness.map { "\(Int($0.rounded())) / 100" } ?? "Learning your usual")
                    Text(presentation.balanceTitle).font(.subheadline).foregroundStyle(EverydayStyle.accent)
                    Slider(value: $load, in: 0...1, step: 0.05) { Text("Demo difficulty") } onEditingChanged: { editing in
                        if !editing { apply() }
                    }.accessibilityIdentifier("demo-load-slider")
                    HStack { Text("Steady days"); Spacer(); Text("Harder days") }.font(.caption).foregroundStyle(.secondary)
                    LabeledContent("Scenario", value: load >= 0.8 ? "18 changed days" : "7 changed days")
                    Button("Apply scenario") { apply() }.accessibilityIdentifier("demo-apply-scenario")
                } header: { Text("Demo controls") } footer: { Text("Simulated readings run through the existing scoring rules. Real Health data and live records stay unchanged.") }
                Section {
                    LabeledContent("To", value: konsta?.name ?? "Add Konsta in Your people")
                    Toggle("Send a demo text automatically", isOn: $armed)
                        .disabled(konsta == nil || !shortcutReady || sender.coolingDown || request != nil)
                        .accessibilityIdentifier("demo-arm-sms")
                    Label(presentation.healthSignal?.step == .steady || presentation.demoLoad == nil ? "Waiting for a support signal" : "Support signal detected", systemImage: "waveform.path")
                        .accessibilityIdentifier("demo-signal-state")
                    Text(request == nil ? "No request started" : "Request handed to Shortcuts")
                        .accessibilityIdentifier("demo-request-state")
                    if let status = sender.statusText {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Latest shortcut result").font(.caption).foregroundStyle(.secondary)
                            Text(status).font(.subheadline)
                        }.accessibilityIdentifier("demo-sms-result")
                    }
                    if sender.coolingDown { Text("One attempt per five minutes. Reset does not remove this limit.").font(.caption).foregroundStyle(.secondary) }
                    DisclosureGroup("One-time iPhone setup", isExpanded: $showSetup) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. In Shortcuts, create a shortcut named Mind Demo SMS.")
                            Text("2. Add Apple's Send Message action. Choose Konsta and the same number saved in MindMaintainer.")
                            Text("3. Use this fixed message:")
                            Text("Mind DEMO TEST: automatic support signal reached. No action needed.").textSelection(.enabled)
                            Text("4. Turn off Show When Run / Show Compose Sheet in that action. Allow the first iOS permission yourself.")
                            Text("The shortcut must contain only that fixed test message and recipient. It receives no Health data or phone number from MindMaintainer.")
                            Button("Open Shortcuts") { if let url = URL(string: "shortcuts://") { openURL(url) } }
                            Toggle("Mind Demo SMS is configured for Konsta", isOn: $shortcutReady)
                                .accessibilityIdentifier("demo-shortcut-ready")
                        }.font(.subheadline).padding(.vertical, 10)
                    }
                } header: { Text("Message test · your iPhone") } footer: {
                    Text("Once set up, a support signal runs the shortcut without a Messages Send button. Shortcuts may open and iOS may request a first-run permission. A completed shortcut does not verify message delivery.")
                }
                Section {
                    Button("Fine-tune individual readings", systemImage: "slider.horizontal.3") { showReadings = true }
                    LabeledContent("Support stage", value: stage)
                    LabeledContent("Changed days this week", value: "\(presentation.healthSignal?.driftDaysInLastWeek ?? 0)")
                }
            }.navigationTitle("Demo").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Reset") { reset() }.accessibilityIdentifier("demo-restore") }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                .onAppear {
                    load = presentation.demoLoad ?? 0
                    // With simulated data on, keep its history; the difficulty slider is still there to apply on purpose.
                    if presentation.demoLoad == nil && !presentation.simulatedData { presentation.applyDemoLoad(0) }
                    showSetup = !shortcutReady
                }
                .onChange(of: shortcutReady) { _, ready in if !ready { armed = false } }
                .onChange(of: armed) { _, enabled in
                    presentation.setDemoRecipient(enabled ? konsta?.id : nil)
                    if enabled { sendIfNeeded() }
                }
                .sheet(isPresented: $showReadings) { BesideDemoControlsView(embeddedInDemo: true) }
        }
    }
    private var stage: String {
        switch presentation.healthSignal?.step { case .nudge: "Small step / support check"; case .reachOut: "Reach out"; default: "Steady" }
    }
    private func apply() {
        presentation.applyDemoLoad(load)
        sendIfNeeded()
    }
    private func sendIfNeeded() {
        guard armed, shortcutReady, konsta != nil, !sender.coolingDown, request == nil,
              let prepared = presentation.prepareDemoSMS(),
              let url = sender.begin(requestID: prepared.id, day: presentation.day), let run = sender.run else { return }
        request = prepared
        armed = false
        openURL(url) { opened in sender.didOpen(id: run.id, opened: opened) }
    }
    private func reset() {
        armed = false; request = nil; load = 0
        presentation.resetDemoScenario()
    }
}

/// One area score with a slider. Commits on release, so scoring runs once per change.
private struct DemoScoreSlider: View {
    let kind: ScoreKind
    @Environment(BesidePresentation.self) private var presentation
    @State private var value: Double = 50
    @State private var editing = false
    private var measured: Double? { presentation.healthSignal?.result.scores[kind] }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(kind.title)
                if presentation.scoreOverrides[kind] != nil { Text("set").font(.caption2).foregroundStyle(EverydayStyle.accent) }
                Spacer()
                Text(measured == nil && !editing ? "–" : "\(Int(value.rounded()))").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 0...100) { Text(kind.title) } onEditingChanged: { active in
                editing = active
                if !active { presentation.setScoreOverride(kind, to: value) }
            }
        }
        .onAppear { value = measured ?? 50 }
        .onChange(of: measured) { _, new in if !editing { value = new ?? 50 } }
    }
}

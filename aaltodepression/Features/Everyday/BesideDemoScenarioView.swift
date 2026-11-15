import SwiftUI

/// Advanced demo controls, opened by triple-tapping the Trends title. The message test lives in BesideSMSDemoSection.
struct BesideDemoScenarioView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var load = 0.0
    @State private var showReadings = false

    var body: some View {
        NavigationStack {
            Form {
                BesideSMSDemoSection()
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
                    Button("Health readings and fine-tuning", systemImage: "heart.text.square") { showReadings = true }
                    LabeledContent("Support stage", value: stage)
                    LabeledContent("Changed days this week", value: "\(presentation.healthSignal?.driftDaysInLastWeek ?? 0)")
                }
            }.navigationTitle("Demo").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Reset") { reset() }.accessibilityIdentifier("demo-restore") }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                .onAppear {
                    // The advanced controls take over from the simple Trends demo data while they are used.
                    presentation.setQuickScenario(nil)
                    load = presentation.demoLoad ?? 0
                    // With simulated data on, keep its history; the difficulty slider is still there to apply on purpose.
                    if presentation.demoLoad == nil && !presentation.simulatedData { presentation.applyDemoLoad(0) }
                }
                .sheet(isPresented: $showReadings) { BesideDemoControlsView(embeddedInDemo: true) }
        }
    }
    private var stage: String {
        switch presentation.healthSignal?.step { case .nudge: "Small step / support check"; case .reachOut: "Reach out"; default: "Steady" }
    }
    // The message test section sends on its own when a new load reaches the support signal.
    private func apply() { presentation.applyDemoLoad(load) }
    private func reset() {
        load = 0
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

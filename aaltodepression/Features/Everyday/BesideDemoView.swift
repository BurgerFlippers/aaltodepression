import SwiftUI

/// Dates and demo overrides are confined to this tab. Challenge activity is read from live records.
struct BesideDemoView: View {
    @Environment(BesidePresentation.self) private var presentation
    @AppStorage("beside.demo.sms.lastSent") private var lastTestSent = 0.0
    @State private var showControls = false
    @State private var showSMSTest = false
    private var recorded: SidequestDay? { presentation.liveBackend.planner.state.sidequests[presentation.day.jdn] }
    private var konsta: Contact? {
        presentation.liveBackend.planner.setup.contacts.first {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .split(whereSeparator: { $0.isWhitespace }).contains("konsta")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: Binding(get: { presentation.day.start() }, set: { presentation.selectDay(Day($0)) }),
                               in: (Day(Date()) - 120).start()...Date(), displayedComponents: .date).accessibilityIdentifier("demo-day-picker")
                    Text(presentation.selectedDayAvailability).font(.caption).foregroundStyle(.secondary)
                }
                Section("Daily balance") {
                    BesideDemoBar().listRowInsets(EdgeInsets())
                    Text(presentation.isDemoMode && presentation.hasDemoEdits ? "Demo readings edited for this session" : "Shared Health and iPhone readings")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Status", value: recorded?.selected == nil ? "Not selected" : "Selected")
                    if let recorded, let quest = recorded.selected, let version = recorded.version {
                        Label(quest.category.title, systemImage: BesideQuestStyle.kind(quest).symbol)
                        Text(version.instruction).font(.body)
                        LabeledContent("Version", value: recorded.useSmaller ? "Smaller" : "Regular")
                        if let started = recorded.startedAt { LabeledContent("Selected at", value: started.formatted(date: .omitted, time: .shortened)) }
                        LabeledContent("Completion", value: recorded.completedAt == nil ? "Assumed · not verified" : "Previously marked complete")
                        Text(presentation.sidequestEvidence(on: presentation.day)).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No challenge was selected for this day.").foregroundStyle(.secondary)
                    }
                } header: { Text("Recorded challenge") } footer: { Text("Choosing a task is enough. Health activity can provide clues, but does not prove a specific task was completed.") }
                Section("By category") {
                    ForEach([SidequestCategory.nutrition, .movement, .sleep, .social, .medicine], id: \.rawValue) { category in
                        LabeledContent(category.title, value: presentation.categoryStatus(category))
                    }
                }
                Section("Health connection") {
                    Button("Review Health access", systemImage: "heart.text.square") {
                        Task { await presentation.connectHealth() }
                    }.disabled(presentation.isRefreshing)
                    Button("Refresh readings", systemImage: "arrow.clockwise") { Task { await presentation.refresh() } }
                        .disabled(presentation.isRefreshing)
                    if presentation.isRefreshing { ProgressView("Reading Health…") }
                    if let status = presentation.healthStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                    Text("To change an earlier denial: Health → profile → Apps → Mind. Enable the data you want to share.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Daily statistics") {
                    ForEach([BesideHealthMetric.sleep, .steps, .exercise, .daylight]) { metric in
                        LabeledContent(metric.title, value: metric.text(presentation.reading(metric)))
                    }
                    ForEach(["Daily signals", "Nutrition", "Mind"], id: \.self) { group in
                        DisclosureGroup(group == "Daily signals" ? "More daily signals" : group) {
                            ForEach(BesideHealthMetric.allCases.filter { $0.group == group && ![.sleep, .steps, .exercise, .daylight].contains($0) }) { metric in
                                LabeledContent(metric.title, value: metric.text(presentation.reading(metric)))
                            }
                        }
                    }
                    Button("Edit demo readings", systemImage: "slider.horizontal.3") { showControls = true }
                }
                Section {
                    if let konsta {
                        Button("Review test message to \(konsta.name)", systemImage: "message") { showSMSTest = true }
                            .disabled(Date().timeIntervalSince1970 - lastTestSent < 300)
                        if lastTestSent > 0 { Label("Test message sent from this iPhone.", systemImage: "checkmark.circle").font(.caption) }
                    } else {
                        Text("Add Konsta in Your people to prepare a test message.").foregroundStyle(.secondary)
                    }
                } header: { Text("Phone SMS test") } footer: { Text("Uses this iPhone’s Messages app. You review and tap Send. No Health data is included.") }
            }
            .navigationTitle("Trends").navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showControls) { BesideDemoControlsView(embeddedInDemo: true) }
            .sheet(isPresented: $showSMSTest) {
                if let konsta {
                    EverydaySocialView(initialPersonID: konsta.id, testMessage: "Mind test: checking the message flow from this iPhone. No action needed.", onSent: { lastTestSent = Date().timeIntervalSince1970 })
                }
            }
        }
    }
}

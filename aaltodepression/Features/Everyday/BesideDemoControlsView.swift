import SwiftUI
import HealthKit

/// Only requests the Health types used by the active interface. No write access.
enum BesideHealthAccess {
    static func request() async throws {
        var types: Set<HKObjectType> = [HKQuantityType(.stepCount), HKQuantityType(.walkingSpeed),
            HKQuantityType(.appleExerciseTime), HKQuantityType(.timeInDaylight), HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.respiratoryRate),
            HKQuantityType(.appleSleepingWristTemperature), HKCategoryType(.sleepAnalysis),
            HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryWater), HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal), HKCategoryType(.mindfulSession)]
        if #available(iOS 18.0, *) {
            types.insert(HKObjectType.stateOfMindType())
            types.insert(HKScoredAssessmentType(.PHQ9))
            types.insert(HKScoredAssessmentType(.GAD7))
        }
        try await HKHealthStore().requestAuthorization(toShare: [], read: types)
    }
}

enum BesideHealthMetric: String, CaseIterable, Identifiable {
    case steps, sleep, bedtime, wake, exercise, daylight, heartRate, hrv, breathing, temperature, walkingSpeed
    case foodEnergy, water, protein, carbs, fat, mindful, stateOfMind, phq9, gad7
    var id: String { rawValue }
    var group: String {
        switch self {
        case .foodEnergy, .water, .protein, .carbs, .fat: "Nutrition"
        case .mindful, .stateOfMind, .phq9, .gad7: "Mind"
        default: "Daily signals"
        }
    }
    var isContextOnly: Bool { group != "Daily signals" }
    var wholeNumber: Bool { self == .steps || self == .phq9 || self == .gad7 }
    var key: String {
        switch self {
        case .steps: F.steps; case .sleep: F.sleepHours; case .bedtime: F.bedtime; case .wake: F.wake
        case .exercise: F.exerciseMin; case .daylight: F.daylightMin; case .heartRate: F.restingHR
        case .hrv: F.hrv; case .breathing: F.respRate; case .temperature: F.wristTemp; case .walkingSpeed: F.walkingSpeed
        case .foodEnergy: F.dietaryEnergy; case .water: F.dietaryWater; case .protein: F.dietaryProtein
        case .carbs: F.dietaryCarbs; case .fat: F.dietaryFat; case .mindful: F.mindfulMin
        case .stateOfMind: F.stateOfMindValence; case .phq9: F.phq9; case .gad7: F.gad7
        }
    }
    var title: String { FeatureCatalog.byKey[key]?.title ?? rawValue }
    var unit: String {
        switch self {
        case .steps: "steps"; case .sleep: "hours"; case .bedtime, .wake: "time"
        case .exercise, .daylight: "minutes"; case .heartRate: "bpm"; case .hrv: "ms"
        case .breathing: "per minute"; case .temperature: "°C"; case .walkingSpeed: "m/s"
        case .foodEnergy: "kcal"; case .water: "mL"; case .protein, .carbs, .fat: "g"
        case .mindful: "minutes"; case .stateOfMind: "valence"; case .phq9: "/ 27"; case .gad7: "/ 21"
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .steps: 0...100000; case .sleep: 0...24; case .bedtime: 0...24; case .wake: 0...24
        case .exercise, .daylight: 0...1440; case .heartRate: 20...220; case .hrv: 0...500
        case .breathing: 4...60; case .temperature: 25...45; case .walkingSpeed: 0...5
        case .foodEnergy: 0...15000; case .water: 0...15000; case .protein, .carbs, .fat: 0...2000
        case .mindful: 0...1440; case .stateOfMind: -1...1; case .phq9: 0...27; case .gad7: 0...21
        }
    }
    var initial: Double {
        switch self {
        case .steps: 5000; case .sleep: 8; case .bedtime: 5; case .wake: 7
        case .exercise: 20; case .daylight: 30; case .heartRate: 65; case .hrv: 40
        case .breathing: 15; case .temperature: 36; case .walkingSpeed: 1.2
        case .foodEnergy: 2000; case .water: 1500; case .protein: 60; case .carbs: 250; case .fat: 70
        case .mindful: 10; case .stateOfMind: 0; case .phq9, .gad7: 0
        }
    }
    func text(_ value: Double?) -> String {
        guard let value else { return "Not available" }
        if self == .bedtime || self == .wake {
            let total = Int((value + (self == .bedtime ? 18 : 0)) * 60) % 1440
            return String(format: "%02d:%02d", total / 60, total % 60)
        }
        if self == .sleep { return "\(Int(value)) h \(Int((value * 60).rounded()) % 60) min" }
        return "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }
}

struct BesideDemoControlsView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @AppStorage("beside.demobar.visible") private var showDemobar = true
    @State private var editing: BesideHealthMetric?
    @State private var confirmReset = false
    @State private var connecting = false
    @State private var automaticTopic: SupportTopic = .groceries
    @State private var automaticResult: String?
    @State private var showRequests = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: Binding(get: { presentation.day.start() }, set: { showDemobar = true; presentation.selectDay(Day($0)) }),
                               in: (Calendar.current.date(byAdding: .day, value: -120, to: Date()) ?? Date())...Date(), displayedComponents: .date)
                    if presentation.isDemoMode {
                        Label(presentation.hasDemoEdits ? "Demo copy · edited readings" : "Demo copy · real readings", systemImage: "testtube.2")
                        Button("Return to live today") { presentation.returnToLive() }
                    } else {
                        Label("Live today", systemImage: "waveform.path")
                        Button("Edit today in demo") { showDemobar = true; presentation.selectDay(Day(Date())) }
                    }
                } header: { Text("Explore a day") } footer: { Text("Selecting a date opens a separate demo copy. Reading edits and task marks stay in that copy for this session. Apple Health and your live records stay unchanged.") }
                ForEach(["Daily signals", "Nutrition", "Mind"], id: \.self) { group in
                Section {
                    ForEach(BesideHealthMetric.allCases.filter { $0.group == group }) { metric in
                        Button { editing = metric } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(metric.title).foregroundStyle(.primary)
                                    Text(presentation.isEdited(metric) ? "Demo override" : presentation.reading(metric) == nil ? "No shared reading" : "Health / iPhone").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(metric.text(presentation.reading(metric))).foregroundStyle(.secondary)
                                if presentation.isDemoMode { Image(systemName: "pencil").font(.caption) }
                            }
                        }.buttonStyle(.plain).disabled(!presentation.isDemoMode)
                    }

                } header: { Text(group) } footer: {
                    if group == "Nutrition" { Text("Only what was logged in Apple Health. Missing entries don't mean meals were skipped. These values are not scored.") }
                    if group == "Mind" { Text("Your existing Health entries and assessments, shown as context only. These do not change the bar or trigger automatic requests.") }
                }
                }
                if presentation.isDemoMode { Section { Button("Reset this day's demo readings", role: .destructive) { confirmReset = true } } }

                Section {
                    Button {
                        connecting = true
                        Task { await presentation.connectHealth(); connecting = false }
                    } label: { HStack { Text("Connect / update Apple Health"); Spacer(); if connecting { ProgressView() } } }.disabled(connecting)
                    Button("Refresh shared data") { Task { await presentation.refresh() } }.disabled(presentation.isRefreshing)
                    if let status = presentation.healthStatus { Text(status).font(.footnote).foregroundStyle(.secondary) }
                    if let date = presentation.healthReadAt { LabeledContent("Last read", value: date.formatted(date: .omitted, time: .shortened)) }
                } header: { Text("Data connection") } footer: { Text("Health shares only the types you allow. Missing readings remain unknown. Heart and sleep measurements may require a Watch or another source that writes to Health.") }
                Section {
                    LabeledContent("Signals evaluated for", value: presentation.signalDay.start().formatted(date: .abbreviated, time: .omitted))
                    if let signal = presentation.healthSignal {
                        LabeledContent("Personal baseline", value: presentation.signalHasBaseline ? "Available" : "Still learning")
                        LabeledContent("Drift days this week", value: "\(signal.driftDaysInLastWeek)")
                        ForEach(ScoreKind.allCases.filter { signal.result.scores[$0] != nil }) { kind in
                            LabeledContent(kind.title, value: "\(Int((signal.result.scores[kind] ?? 0).rounded())) / 100")
                        }
                    } else { Text("Not enough shared history yet.").foregroundStyle(.secondary) }
                    if let contact = presentation.callCue { Label("A call from \(contact) is suggested", systemImage: "phone.fill") }
                } header: { Text("What drives the bar") } footer: { Text("The backend compares sleep, rhythm, movement, daylight and body signals with your own history. Live today uses the last complete day to avoid comparing partial steps with a full day. The demo evaluates the selected day. This is a prototype change indicator, not a depression diagnosis. Contact suggestions also depend on the support agreements in the backend.") }
                Section {
                    DisclosureGroup("Automatic support demo") {
                        NavigationLink("Support choices and agreement") {
                            ScrollView { EverydaySupportSetupFields().padding(20) }.background(EverydayStyle.paper).navigationTitle("Support choices").navigationBarTitleDisplayMode(.inline)
                        }
                        Picker("Request", selection: $automaticTopic) { ForEach(SupportTopic.allCases) { Text($0.title).tag($0) } }
                        if presentation.isDemoMode {
                            Button("Simulate an automatic request") {
                                if let request = presentation.backend.planner.demonstrateAutomaticSupport(automaticTopic) { automaticResult = "Simulated request recorded for \(request.contactName). Nothing was delivered." }
                                else { automaticResult = "Check the selected support choice and recipient agreement. Existing frequency limits and cancellations still apply." }
                            }
                        } else { Button("Open today's demo copy") { showDemobar = true; presentation.selectDay(Day(Date())) } }
                        if let automaticResult { Text(automaticResult).font(.footnote).foregroundStyle(.secondary) }
                        Button("View prototype requests") { showRequests = true }
                        Text("Separate from the first, user-led reach-out suggestion. This control advances the automatic-message scene in the demo copy only.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section { Toggle("Show Demobar", isOn: $showDemobar).onChange(of: showDemobar) { _, visible in if !visible { presentation.returnToLive() } } }
            }.navigationTitle("Demo controls").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $showRequests) { BesideSupportRequestsView() }
                .sheet(item: $editing) { metric in BesideMetricEditorView(metric: metric, day: presentation.day) }
                .confirmationDialog("Restore the original readings for this day?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset demo readings", role: .destructive) { presentation.resetEdits(on: presentation.day) }
                }
        }
    }
}

private struct BesideMetricEditorView: View {
    let metric: BesideHealthMetric
    let day: Day
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var value = 0.0
    @State private var time = Date()
    private var isTime: Bool { metric == .bedtime || metric == .wake }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isTime {
                        DatePicker(metric.title, selection: $time, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden()
                    } else {
                        HStack { Text(metric.unit); TextField("Value", value: $value, format: .number).keyboardType(metric == .stateOfMind ? .numbersAndPunctuation : .decimalPad).multilineTextAlignment(.trailing) }
                        Text("Allowed range: \(metric.range.lowerBound.formatted())–\(metric.range.upperBound.formatted()) \(metric.unit)").font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text(day.start().formatted(date: .abbreviated, time: .omitted)) } footer: { Text("This value is used only in the demo copy. It is not written to Apple Health.") }
            }.navigationTitle(metric.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                            let hours = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
                            let number = isTime ? (metric == .bedtime ? (hours + 6).truncatingRemainder(dividingBy: 24) : hours) : value
                            presentation.edit(metric, value: number, on: day); dismiss()
                        }.disabled(!isTime && (!value.isFinite || !metric.range.contains(value) || metric.wholeNumber && value.rounded() != value))
                    }
                }.onAppear {
                    value = presentation.reading(metric, on: day) ?? metric.initial
                    let hour = (value + (metric == .bedtime ? 18 : 0)).truncatingRemainder(dividingBy: 24)
                    time = Calendar.current.date(bySettingHour: Int(hour), minute: Int((hour * 60).rounded()) % 60, second: 0, of: Date()) ?? Date()
                }
        }
    }
}

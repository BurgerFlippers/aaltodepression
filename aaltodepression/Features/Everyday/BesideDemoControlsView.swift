import SwiftUI
import HealthKit

/// Only requests the Health types used by the active interface. Writes only State of Mind (the check-in answer).
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
        var share: Set<HKSampleType> = []
        if #available(iOS 18.0, *) { share.insert(HKObjectType.stateOfMindType()) }
        try await HKHealthStore().requestAuthorization(toShare: share, read: types)
    }
}

enum BesideHealthMetric: String, CaseIterable, Identifiable {
    case steps, sleep, bedtime, wake, exercise, daylight, heartRate, hrv, breathing, temperature, walkingSpeed
    case activeHours, efficiency, timeAway, places
    case foodEnergy, water, protein, carbs, fat, mindful, stateOfMind, phq9, gad7
    var id: String { rawValue }
    var group: String {
        switch self {
        case .foodEnergy, .water, .protein, .carbs, .fat: "Nutrition"
        case .mindful, .stateOfMind, .phq9, .gad7: "Mind"
        case .timeAway, .places: "Places"
        default: "Daily signals"
        }
    }
    var isContextOnly: Bool { group == "Nutrition" || group == "Mind" }
    var wholeNumber: Bool { self == .steps || self == .places || self == .phq9 || self == .gad7 }
    var key: String {
        switch self {
        case .steps: F.steps; case .sleep: F.sleepHours; case .bedtime: F.bedtime; case .wake: F.wake
        case .exercise: F.exerciseMin; case .daylight: F.daylightMin; case .heartRate: F.restingHR
        case .hrv: F.hrv; case .breathing: F.respRate; case .temperature: F.wristTemp; case .walkingSpeed: F.walkingSpeed
        case .foodEnergy: F.dietaryEnergy; case .water: F.dietaryWater; case .protein: F.dietaryProtein
        case .carbs: F.dietaryCarbs; case .fat: F.dietaryFat; case .mindful: F.mindfulMin
        case .stateOfMind: F.stateOfMindValence; case .phq9: F.phq9; case .gad7: F.gad7
        case .activeHours: F.activeHours; case .efficiency: F.sleepEfficiency
        case .timeAway: F.awayHours; case .places: F.placesVisited
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
        case .activeHours, .timeAway: "hours"; case .efficiency: "share"; case .places: "places"
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .steps: 0...100000; case .sleep: 0...24; case .bedtime: 0...24; case .wake: 0...24
        case .exercise, .daylight: 0...1440; case .heartRate: 20...220; case .hrv: 0...500
        case .breathing: 4...60; case .temperature: 25...45; case .walkingSpeed: 0...5
        case .foodEnergy: 0...15000; case .water: 0...15000; case .protein, .carbs, .fat: 0...2000
        case .mindful: 0...1440; case .stateOfMind: -1...1; case .phq9: 0...27; case .gad7: 0...21
        case .activeHours, .timeAway: 0...24; case .efficiency: 0...1; case .places: 0...50
        }
    }
    var initial: Double {
        switch self {
        case .steps: 5000; case .sleep: 8; case .bedtime: 5; case .wake: 7
        case .exercise: 20; case .daylight: 30; case .heartRate: 65; case .hrv: 40
        case .breathing: 15; case .temperature: 36; case .walkingSpeed: 1.2
        case .foodEnergy: 2000; case .water: 1500; case .protein: 60; case .carbs: 250; case .fat: 70
        case .mindful: 10; case .stateOfMind: 0; case .phq9, .gad7: 0
        case .activeHours: 8; case .efficiency: 0.9; case .timeAway: 5; case .places: 3
        }
    }
    func text(_ value: Double?) -> String {
        guard let value else { return "No entry for this day" }
        if self == .bedtime || self == .wake {
            let total = Int((value + (self == .bedtime ? 18 : 0)) * 60) % 1440
            return String(format: "%02d:%02d", total / 60, total % 60)
        }
        if self == .efficiency { return "\(Int((value * 100).rounded())) %" }
        if self == .sleep || self == .timeAway { return "\(Int(value)) h \(Int((value * 60).rounded()) % 60) min" }
        return "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }
}

struct BesideDemoControlsView: View {
    var embeddedInDemo = false
    /// Reading edits are an advanced demo control; the main Trends screen opens this read-only.
    var allowsEditing = true
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var editing: BesideHealthMetric?
    @State private var connecting = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Day", value: presentation.day.start().formatted(date: .abbreviated, time: .omitted))
                    Text(presentation.selectedDayAvailability).font(.caption).foregroundStyle(.secondary)
                    if presentation.hasDemoEdits { Label("Demo values", systemImage: "testtube.2").foregroundStyle(EverydayStyle.accent) }
                }
                ForEach(["Daily signals", "Places", "Nutrition", "Mind"], id: \.self) { group in
                    Section(group) {
                        ForEach(BesideHealthMetric.allCases.filter { $0.group == group && presentation.reading($0) != nil }) { metric in row(metric) }
                        DisclosureGroup("Not recorded for this day") {
                            ForEach(BesideHealthMetric.allCases.filter { $0.group == group && presentation.reading($0) == nil }) { metric in row(metric) }
                        }
                    }
                }
                Section {
                    Button {
                        connecting = true
                        Task { await presentation.connectHealth(); connecting = false }
                    } label: { HStack { Text("Review Health access"); Spacer(); if connecting { ProgressView() } } }.disabled(connecting)
                    Button("Refresh readings") { Task { await presentation.refresh() } }.disabled(presentation.isRefreshing)
                    if let status = presentation.healthStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                    Text("To change an earlier denial: Health → profile → Apps → MindMaintainer.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Health connection") } footer: { Text("Nutrition and Mind entries are context only. Missing logs do not mean a skipped meal or low mood.") }
            }.navigationTitle("Health readings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $editing) { metric in BesideMetricEditorView(metric: metric, day: presentation.day) }
        }
    }
    private func row(_ metric: BesideHealthMetric) -> some View {
        Button { editing = metric } label: {
            HStack {
                Text(metric.title).foregroundStyle(.primary)
                Spacer()
                Text(metric.text(presentation.reading(metric))).foregroundStyle(.secondary)
                if presentation.isDemoMode && allowsEditing { Image(systemName: "pencil").font(.caption) }
            }.padding(.vertical, 4)
        }.buttonStyle(.plain).disabled(!presentation.isDemoMode || !allowsEditing)
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

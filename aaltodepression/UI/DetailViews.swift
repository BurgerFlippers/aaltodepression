import SwiftUI

/// What one score is based on: each signal today next to the person's usual.
struct ScoreDetailView: View {
    let kind: ScoreKind
    let result: DayResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(explanation).fixedSize(horizontal: false, vertical: true)
                }
                if kind == .rhythm {
                    Section("Last 7 days") {
                        row("Wake time varied by", result.wakeSD.map { Format.value($0, .hoursMinutes) })
                        row("Bedtime varied by", result.bedtimeSD.map { Format.value($0, .hoursMinutes) })
                    }
                } else if kind == .daylight {
                    Section("Today") {
                        row("Target today", Format.value(result.daylightTarget, .minutes))
                    }
                } else if let parts = result.parts[kind] {
                    Section("Today and your usual") {
                        ForEach(parts, id: \.key) { p in
                            let info = FeatureCatalog.byKey[p.key]
                            LabeledContent(info?.title ?? p.key) {
                                VStack(alignment: .trailing) {
                                    Text(info.map { Format.value(p.value, $0.format) } ?? "\(p.value)")
                                    if let u = p.usual, let info {
                                        Text("usually \(Format.value(u.median, info.format))")
                                            .font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, _ value: String?) -> some View {
        LabeledContent(title, value: value ?? "No data")
    }

    private var explanation: String {
        switch kind {
        case .sleep: "How long you slept, when you fell asleep and woke up, and time awake in the night, compared with your last four weeks."
        case .rhythm: "How regular your wake and bedtimes were this week. Within half an hour of each other is a full stripe."
        case .movement: "Steps and exercise minutes, where more than usual counts as full, plus walking speed and time spent still."
        case .daylight: "Minutes outside in daylight, measured by Apple Watch. The target is 30 minutes, lower on short winter days."
        case .places: "Time away from home and places you went, where more than usual counts as full."
        case .body: "Resting heart rate, heart rate variability, wrist temperature and breathing rate, compared with your usual."
        }
    }
}

/// Crisis help, one tap from the home screen.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("If things feel too heavy right now, call. Someone will answer.")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.clear)
                }
                Section {
                    Link(destination: URL(string: "tel:+358000000000")!) {
                        Label("Call the crisis line", systemImage: "phone.fill")
                    }
                    .frame(minHeight: 44)
                } footer: {
                    Text("Demo placeholder number, not a real line. The clinic sets the real number in the plan.")
                }
                Section {
                    Link(destination: URL(string: "tel:112")!) {
                        Label("Call 112, emergency", systemImage: "staroflife.fill")
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Get help now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

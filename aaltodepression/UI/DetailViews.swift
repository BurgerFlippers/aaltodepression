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
                if kind == .daylight {
                    Section("This day") {
                        row("Target", Format.value(result.daylightTarget, .minutes))
                        if result.daylightEstimated {
                            Text("No Apple Watch daylight for this day, so it's estimated from steps between sunrise and sunset.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } else if let parts = result.parts[kind] {
                    Section("This day and your usual") {
                        ForEach(parts, id: \.key) { p in
                            let info = Explain.info(p.key)
                            LabeledContent(info.title) {
                                VStack(alignment: .trailing) {
                                    Text(Format.value(p.value, info.format))
                                    if let u = p.usual {
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
        case .sleep: "The night before this day: how long you slept, when you fell asleep and woke up, time awake, and the last three nights together. Sleep shapes the next day more than the day shapes the next night, so a short night shows here the morning after."
        case .rhythm: "How regular your sleep timing was this week compared with your own usual regularity, where the middle of your sleep sits, and listening late at night. Rhythm changes slowly, so it often moves before the other stripes."
        case .movement: "This day's steps, exercise minutes and hours with movement, where more than usual counts as full, plus walking speed."
        case .daylight: "Minutes outside in daylight this day. The target is 30 minutes, lower on short winter days. Daylight also helps the next night's sleep come on time."
        case .places: "Time away from home and places you went this day, where more than usual counts as full."
        case .body: "Resting heart rate, heart rate variability, wrist temperature and breathing rate, mostly measured overnight, compared with your usual."
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

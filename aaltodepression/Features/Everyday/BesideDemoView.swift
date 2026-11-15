import SwiftUI

/// Balance first; readings and judging controls remain one deliberate tap away.
struct BesideDemoView: View {
    @Environment(BesidePresentation.self) private var presentation
    @State private var showDemo = false
    @State private var showReadings = false
    private var recorded: SidequestDay? { presentation.liveBackend.planner.state.sidequests[presentation.day.jdn] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DatePicker("Day", selection: Binding(get: { presentation.day.start() }, set: { presentation.selectDay(Day($0)) }),
                               in: (Day(Date()) - 120).start()...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("demo-day-picker")
                    BesideTrendBalanceView()
                    if presentation.simulatedData {
                        Label("Simulated data · Apple Health is not read", systemImage: "testtube.2")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(EverydayStyle.accent)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your signals").font(.title3.bold())
                        VStack(spacing: 0) {
                            ForEach(TrendArea.allCases) { area in
                                DisclosureGroup {
                                    ForEach(area.metrics) { metric in
                                        LabeledContent(metric.title, value: metric.text(presentation.reading(metric)))
                                            .font(.subheadline).padding(.vertical, 5)
                                    }
                                    ForEach(regularityRows(area), id: \.0) { row in
                                        LabeledContent(row.0, value: row.1).font(.subheadline).padding(.vertical, 5)
                                    }
                                    Text(area.note).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: area.symbol).font(.title3).foregroundStyle(EverydayStyle.accent).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(area.title).font(.headline).foregroundStyle(.primary)
                                            Text(summary(area)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 4)
                                        if let kind = area.score, let score = presentation.areaScore(kind) {
                                            Text("\(Int(score.rounded()))").font(.title3.monospacedDigit().bold()).foregroundStyle(.primary)
                                        }
                                    }.padding(.vertical, 10)
                                }.padding(.horizontal, 16).padding(.vertical, 4)
                                if area != TrendArea.allCases.last { Divider().padding(.leading, 58) }
                            }
                        }.background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    DisclosureGroup("Your chosen challenge") {
                        if let recorded, let quest = recorded.selected {
                            Text(BesideQuestStyle.brief(quest, smaller: recorded.useSmaller)).font(.headline).padding(.top, 10)
                            Text("Selected · no completion tap needed").font(.caption).foregroundStyle(.secondary)
                            Text(presentation.sidequestEvidence(on: presentation.day)).font(.caption).foregroundStyle(.secondary)
                        } else { Text("No challenge selected for this day.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
                    }.padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    Button { showReadings = true } label: {
                        HStack { Label("Health readings", systemImage: "heart.text.square"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                            .padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).accessibilityIdentifier("trends-health-readings")
                    Text(presentation.selectedDayAvailability).font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.background(EverydayStyle.paper).navigationTitle("Trends")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Demo", systemImage: "slider.horizontal.3") { showDemo = true }.accessibilityIdentifier("trends-demo") } }
                .sheet(isPresented: $showDemo) { BesideDemoScenarioView() }
                .sheet(isPresented: $showReadings) { BesideDemoControlsView(embeddedInDemo: true) }
        }
    }

    private func summary(_ area: TrendArea) -> String {
        if let kind = area.score, let score = presentation.areaScore(kind) {
            return score >= 70 ? "Close to your usual" : "Different from your usual"
        }
        if area == .places && !presentation.locationAvailable { return "Needs Location · not connected" }
        if let first = area.metrics.first(where: { presentation.reading($0) != nil }) {
            return area.score == nil ? first.text(presentation.reading(first)) : "Learning your usual"
        }
        return "Nothing recorded for this day"
    }

    /// Regularity rows: this week's night-to-night spread against the person's own earlier weeks.
    private func regularityRows(_ area: TrendArea) -> [(String, String)] {
        guard area == .rhythm else { return [] }
        return [("Bedtime regularity", F.bedtime), ("Wake-up regularity", F.wake)].compactMap { title, key in
            guard let week = presentation.spreadMinutes(key, endingOn: presentation.day) else { return nil }
            let usual = presentation.spreadMinutes(key, endingOn: presentation.day - 7, days: 28)
            let text = "± \(Int(week.rounded())) min" + (usual.map { " · usually ± \(Int($0.rounded()))" } ?? "")
            return (title, text)
        }
    }
}

struct BesideTrendBalanceView: View {
    @Environment(BesidePresentation.self) private var presentation
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily balance").font(.headline)
                Spacer()
                if let value = presentation.healthSignal?.result.steadiness {
                    Text("\(Int(value.rounded()))").font(.largeTitle.monospacedDigit().bold())
                    Text("/100").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(presentation.balanceTitle).font(.title3.weight(.semibold))
            GeometryReader { geometry in
                Capsule().fill(LinearGradient(colors: [.init(red: 0.77, green: 0.91, blue: 0.68), .init(red: 0.95, green: 0.83, blue: 0.36), .init(red: 0.91, green: 0.41, blue: 0.23), .init(red: 0.49, green: 0.06, blue: 0.13)], startPoint: .leading, endPoint: .trailing)).frame(height: 8).frame(height: 18)
                if let score = presentation.healthSignal?.result.steadiness {
                    Circle().fill(.white).overlay { Circle().strokeBorder(.black, lineWidth: 3) }.frame(width: 18, height: 18)
                        .offset(x: (geometry.size.width - 18) * min(1, max(0, 1 - score / 100)))
                }
            }.frame(height: 18).accessibilityHidden(true)
            HStack { Text("Your usual"); Spacer(); Text("More support") }.font(.caption).foregroundStyle(.secondary)
            if presentation.hasDemoEdits {
                Label("Demo values · Health is unchanged", systemImage: "testtube.2").font(.caption).foregroundStyle(EverydayStyle.accent)
            } else { Text("Compared with your own daily rhythm").font(.caption).foregroundStyle(.secondary) }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }
}

/// What Trends shows, ordered by how much the relapse evidence supports each signal.
/// Social contact is not passively readable on iOS, so it is not shown as a metric.
private enum TrendArea: CaseIterable, Identifiable {
    case sleep, rhythm, places, movement, daylight, body, mind, food
    var id: Self { self }
    var title: String {
        switch self {
        case .sleep: "Sleep"; case .rhythm: "Daily rhythm"; case .places: "Getting out"; case .movement: "Movement"
        case .daylight: "Daylight"; case .body: "Body"; case .mind: "How you feel"; case .food: "Food"
        }
    }
    var symbol: String {
        switch self {
        case .sleep: "moon.zzz"; case .rhythm: "clock.arrow.circlepath"; case .places: "mappin.and.ellipse"; case .movement: "figure.walk"
        case .daylight: "sun.max"; case .body: "heart"; case .mind: "face.smiling"; case .food: "fork.knife"
        }
    }
    var score: ScoreKind? {
        switch self {
        case .sleep: .sleep; case .rhythm: .rhythm; case .places: .places; case .movement: .movement
        case .daylight: .daylight; case .body: .body; case .mind, .food: nil
        }
    }
    var metrics: [BesideHealthMetric] {
        switch self {
        case .sleep: [.sleep, .bedtime, .wake, .efficiency]
        case .rhythm: [.activeHours]
        case .places: [.timeAway, .places]
        case .movement: [.steps, .exercise, .walkingSpeed]
        case .daylight: [.daylight]
        case .body: [.heartRate, .breathing, .temperature, .hrv]
        case .mind: [.stateOfMind, .mindful, .phq9, .gad7]
        case .food: [.foodEnergy, .water, .protein, .carbs, .fat]
        }
    }
    var note: String {
        switch self {
        case .sleep: "Compared with your own nights. Too little and too much both count."
        case .rhythm: "A steady daily rhythm is one of the clearest signs of how routines are going."
        case .places: "Time away from home and places visited. Collected on this iPhone from install onward."
        case .movement: "An iPhone left on the table counts fewer steps, so a single low day means little."
        case .daylight: "Time in daylight from Apple Watch, or estimated from daytime walking."
        case .body: "Resting heart rate is the most reliable here. Heart rate variability is noisy on a watch."
        case .mind: "What you log in the Health app. Not scored; it helps check the other signals."
        case .food: "Only if you log food. Not scored. A missing log does not mean a skipped meal."
        }
    }
}

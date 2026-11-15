import SwiftUI
import Charts

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
                    BesideTrendBalanceView()
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
                        }.background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
                    }
                    DisclosureGroup("Your chosen challenge") {
                        if let recorded, let quest = recorded.selected {
                            Text(BesideQuestStyle.brief(quest, smaller: recorded.useSmaller)).font(.headline).padding(.top, 10)
                            Text(recorded.completedAt == nil ? "Selected · not marked done yet" : recorded.alsoDoneIDs.map { "Marked done · plus \($0.count) more" } ?? "Marked done").font(.caption).foregroundStyle(.secondary)
                            Text(presentation.sidequestEvidence(on: presentation.day)).font(.caption).foregroundStyle(.secondary)
                        } else { Text("No challenge selected for this day.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
                    }.padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
                    Button { showReadings = true } label: {
                        HStack { Label("Health readings", systemImage: "heart.text.square"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                            .padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
                    }.buttonStyle(.plain).accessibilityIdentifier("trends-health-readings")
                    Text(presentation.selectedDayAvailability).font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.background(EverydayStyle.paper).mindHeader("Trends")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Previous day", systemImage: "chevron.left") { presentation.selectDay(presentation.day - 1) }
                            .disabled(presentation.day <= Day(Date()) - 120)
                        Text(presentation.day == Day(Date()) ? "Today" : presentation.day.start().formatted(.dateTime.day().month(.abbreviated)))
                            .font(.subheadline.weight(.semibold).monospacedDigit()).fixedSize()
                            .accessibilityIdentifier("demo-day-picker")
                        Button("Next day", systemImage: "chevron.right") { presentation.selectDay(presentation.day + 1) }
                            .disabled(presentation.day >= Day(Date()))
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("Demo", systemImage: "slider.horizontal.3") { showDemo = true }.accessibilityIdentifier("trends-demo") }
                }
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
                BalanceScale().frame(height: 18)
                if let score = presentation.healthSignal?.result.steadiness {
                    Circle().fill(.white).overlay { Circle().strokeBorder(.black, lineWidth: 3) }.frame(width: 18, height: 18)
                        .offset(x: (geometry.size.width - 18) * min(1, max(0, 1 - score / 100)))
                }
            }.frame(height: 18).accessibilityHidden(true)
            HStack { Text("Your usual"); Spacer(); Text("More support") }.font(.caption).foregroundStyle(.secondary)
            BesideBalanceTrend()
            if presentation.simulatedData {
                Label("Simulated data · Apple Health is not read", systemImage: "testtube.2").font(.caption).foregroundStyle(EverydayStyle.accent)
            } else if presentation.hasDemoEdits {
                Label("Demo values · Health is unchanged", systemImage: "testtube.2").font(.caption).foregroundStyle(EverydayStyle.accent)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
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

/// The last four weeks: one bar per day and a 7-day running average.
/// Support follows sustained change, so the trend matters more than any single day.
struct BesideBalanceTrend: View {
    @Environment(BesidePresentation.self) private var presentation
    private struct Point: Identifiable { let date: Date; let value: Double; let average: Double?; var id: Date { date } }
    private var points: [Point] {
        let end = presentation.signalDay
        let days = presentation.healthHistory.filter { $0.day <= end && $0.day > end - 28 && $0.result.steadiness != nil }
            .sorted { $0.day < $1.day }
        return days.map { day in
            let week = presentation.healthHistory.filter { $0.day <= day.day && $0.day > day.day - 7 }.compactMap(\.result.steadiness)
            return Point(date: day.day.start(), value: day.result.steadiness!, average: week.count >= 4 ? week.reduce(0, +) / Double(week.count) : nil)
        }
    }
    var body: some View {
        let points = points
        if points.count >= 7 {
            VStack(alignment: .leading, spacing: 8) {
                Divider().padding(.vertical, 4)
                HStack(alignment: .firstTextBaseline) {
                    Text("Last 4 weeks").font(.subheadline.weight(.semibold))
                    Spacer()
                    if let average = points.last?.average {
                        Text("7-day average \(Int(average.rounded()))").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Chart {
                    ForEach(points) { point in
                        BarMark(x: .value("Day", point.date, unit: .day), y: .value("Balance", point.value), width: .ratio(0.6))
                            .foregroundStyle(BalanceScale.color(for: point.value).opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    }
                    ForEach(points.filter { $0.average != nil }) { point in
                        LineMark(x: .value("Day", point.date, unit: .day), y: .value("7-day average", point.average!))
                            .foregroundStyle(.primary).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { AxisGridLine(); AxisValueLabel() } }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 120)
                if let week = presentation.healthSignal?.driftDaysInLastWeek {
                    Text(week == 0 ? "Every day this week was near your usual." : "\(week) of the last 7 days were further from your usual.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

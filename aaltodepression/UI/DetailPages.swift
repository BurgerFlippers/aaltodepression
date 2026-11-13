import SwiftUI
import Charts

/// Navigation targets from the Today summary, in the way Apple Health drills from a summary into a metric.
enum SummaryRoute: Hashable {
    case steadiness
    case score(ScoreKind)
    case allSignals
}

enum ChartRange: String, CaseIterable, Identifiable {
    case week = "W", month = "M", all = "All"
    var id: String { rawValue }
    var days: Int? { switch self { case .week: 7; case .month: 30; case .all: nil } }
}

/// Bars per day with the person's usual as a line; tap a bar to pick that day.
struct DayBarsChart: View {
    let days: [StepDay]
    let range: ChartRange
    let value: (StepDay) -> Double?
    let color: Color
    @Binding var selected: Day

    private var shown: [StepDay] { range.days.map { Array(days.suffix($0)) } ?? days }
    @State private var rawSelection: Date?

    var body: some View {
        let pts = shown
        Chart {
            ForEach(pts, id: \.day) { d in
                if let v = value(d) {
                    BarMark(x: .value("Day", d.day.start(), unit: .day), y: .value("Value", v), width: .ratio(0.7))
                        .foregroundStyle(d.day == selected ? color : color.opacity(0.45))
                        .cornerRadius(2)
                }
            }
            if let usual = pts.last?.baselineDay, value(pts.last!) == pts.last?.result.steadiness {
                RuleMark(y: .value("Usual", usual))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("usual").font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis { AxisMarks(position: .trailing, values: [0, 50, 100]) }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : (range == .month ? 7 : 14))) { _ in
                AxisValueLabel(format: range == .week ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
            }
        }
        .chartXSelection(value: $rawSelection)
        .onChange(of: rawSelection) { _, d in
            guard let d else { return }
            let day = Day(d)
            if days.contains(where: { $0.day == day }) { selected = day }
        }
        .frame(height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily values, \(pts.count) days")
    }
}

/// Steadiness: the chart over time, then what moved the selected day, the rhythm chart and State of Mind.
struct SteadinessDetailView: View {
    @Environment(AppModel.self) private var model
    @State var selected: Day
    @State private var range: ChartRange = .month

    private var day: StepDay? { model.history.last { $0.day == selected } }

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $range) { ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                summary
                DayBarsChart(days: model.history, range: range, value: { $0.result.steadiness }, color: Palette.tint, selected: $selected)
            }
            if let d = day {
                DayBreakdown(day: d, table: model.table, focus: nil,
                             onPrev: { step(-1) }, onNext: { step(1) },
                             canPrev: selected > (model.history.first?.day ?? selected),
                             canNext: selected < (model.history.last?.day ?? selected), showDayHeader: false)
                Section("Sleep and activity") {
                    Actogram(days: model.history, table: model.table, selected: selected,
                             firstNudge: model.history.first { $0.step == .nudge }?.day) { selected = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                StateOfMindCompare(days: model.history, table: model.table, selected: selected)
            }
        }
        .navigationTitle("Steadiness")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.date(selected)).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(day?.result.steadiness.map { "\(Int($0.rounded()))" } ?? "–")
                        .font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                    if let b = day?.baselineDay { Text("usual \(Int(b.rounded()))").foregroundStyle(.secondary) }
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func step(_ delta: Int) {
        let t = selected + delta
        if model.history.contains(where: { $0.day == t }) { selected = t }
    }
}

/// One score: its chart over time and the signals behind the selected day.
struct ScoreDetailView: View {
    @Environment(AppModel.self) private var model
    let kind: ScoreKind
    @State var selected: Day
    @State private var range: ChartRange = .month

    private var day: StepDay? { model.history.last { $0.day == selected } }

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $range) { ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(day?.result.scores[kind].map { "\(Int($0.rounded()))" } ?? "–")
                        .font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(Format.date(selected)).foregroundStyle(.secondary)
                }
                DayBarsChart(days: model.history, range: range, value: { $0.result.scores[kind] },
                             color: Palette.stripe(kind), selected: $selected)
            }
            if let d = day {
                DayBreakdown(day: d, table: model.table, focus: kind, onPrev: {}, onNext: {},
                             canPrev: false, canNext: false, only: kind)
            }
            Section("About \(kind.title)") {
                Text(about).fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var about: String {
        switch kind {
        case .sleep: "The night before this day: how long you slept, when you fell asleep and woke up, time awake, sleep stages, and the last three nights together. Sleep shapes the next day more than the day shapes the next night."
        case .rhythm: "How regular your sleep timing was this week compared with your own usual regularity, where the middle of your sleep sits, and late listening. Rhythm often moves before the other stripes."
        case .movement: "Steps, exercise, hours with movement and other movement signals this day, compared with your usual. More than usual counts as full."
        case .daylight: "Minutes outside in daylight. The target is 30 minutes, lower on short winter days. Daylight also helps the next night's sleep come on time."
        case .places: "Time away from home, places, and signs of contact with the world, such as calendar events and photos, compared with your usual."
        case .body: "Resting heart rate, heart rate variability, wrist temperature, breathing rate and other body signals, mostly measured overnight."
        }
    }
}

/// Every signal and where it comes from, like "Show All Health Data".
struct AllSignalsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let table = model.table
        let present = FeatureCatalog.all.filter { table.dayCount($0.key) > 0 }
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(present.count) of \(FeatureCatalog.all.count) signals have data").font(.headline)
                    Text(model.isDemo ? "Synthetic demo data for Perttu. Everything is worked out on this phone."
                                      : "Read from this iPhone and its Apple Watch. Everything is worked out on this phone.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(SignalSource.allCases, id: \.self) { source in
                let rows = FeatureCatalog.all.filter { $0.source == source }
                if !rows.isEmpty {
                    Section(source.rawValue) {
                        ForEach(rows) { SignalRow(info: $0, table: table, day: model.scoredDay) }
                    }
                }
            }
        }
        .navigationTitle("All signals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

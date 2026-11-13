import SwiftUI
import Charts

/// Day score over the last four weeks, with the person's usual as a quiet band behind it.
struct HistoryChart: View {
    let days: [StepDay]
    var selected: Day? = nil

    private struct Point: Identifiable {
        let date: Date
        let score: Double?
        let usual: Double?
        var id: Date { date }
    }

    private var points: [Point] {
        // Leave out early days scored from only one or two signals, as the step engine does.
        let fullest = days.map(\.result.coverage).max() ?? 0
        return days.suffix(28).map {
            Point(date: $0.day.start(),
                  score: $0.result.coverage >= fullest * StepEngine.minimumCoverageShare ? $0.result.dayScore : nil,
                  usual: $0.baselineDay)
        }
    }

    var body: some View {
        let pts = points
        VStack(alignment: .leading, spacing: 10) {
            Text("4 weeks to this day").font(.headline)
            Chart {
                ForEach(pts) { p in
                    if let u = p.usual {
                        AreaMark(x: .value("Day", p.date, unit: .day),
                                 yStart: .value("Usual low", max(0, u - StepEngine.driftMargin)),
                                 yEnd: .value("Usual", u))
                            .foregroundStyle(Palette.tint.opacity(0.12))
                            .interpolationMethod(.monotone)
                    }
                }
                ForEach(pts) { p in
                    if let s = p.score {
                        LineMark(x: .value("Day", p.date, unit: .day), y: .value("Day score", s))
                            .foregroundStyle(Palette.tint)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.monotone)
                    }
                }
                if let last = pts.last, let s = last.score {
                    RuleMark(x: .value("Day", last.date, unit: .day))
                        .foregroundStyle(Palette.tint.opacity(0.25))
                    PointMark(x: .value("Day", last.date, unit: .day), y: .value("Day score", s))
                        .foregroundStyle(Palette.tint)
                        .symbolSize(60)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine(); AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            } }
            .frame(height: 170)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Day score over the last 4 weeks")
            .accessibilityValue(spoken(pts))
            Text("The shaded band is your usual range.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func spoken(_ pts: [Point]) -> String {
        let scores = pts.compactMap(\.score)
        guard let last = scores.last else { return "No data yet" }
        let week = scores.suffix(7)
        let avg = week.reduce(0, +) / Double(max(week.count, 1))
        return "Today \(Int(last.rounded())). Average of the last 7 days \(Int(avg.rounded())) out of 100."
    }
}

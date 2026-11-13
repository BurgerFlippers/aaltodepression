import SwiftUI
import Charts

/// State of Mind is never scored. Shown next to Steadiness so the two can be compared:
/// does the person's own logged feeling move with what the data noticed?
struct StateOfMindCompare: View {
    let days: [StepDay]
    let table: FeatureTable
    let selected: Day

    private struct Point: Identifiable {
        let date: Date
        let steadiness: Double?
        let valence: Double?
        var id: Date { date }
    }

    private var points: [Point] {
        let end = days.firstIndex { $0.day == selected }.map { $0 + 1 } ?? days.count
        return days[..<end].suffix(60).map {
            Point(date: $0.day.start(), steadiness: $0.result.steadiness, valence: table.value(F.stateOfMindValence, $0.day))
        }
    }

    /// Pearson correlation over days that have both.
    private func correlation(_ pts: [Point]) -> (r: Double, n: Int)? {
        let pairs = pts.compactMap { p -> (Double, Double)? in
            guard let s = p.steadiness, let v = p.valence else { return nil }
            return (s, v)
        }
        guard pairs.count >= 7 else { return nil }
        let n = Double(pairs.count)
        let mx = pairs.map(\.0).reduce(0, +) / n, my = pairs.map(\.1).reduce(0, +) / n
        let cov = pairs.map { ($0.0 - mx) * ($0.1 - my) }.reduce(0, +)
        let sx = pairs.map { ($0.0 - mx) * ($0.0 - mx) }.reduce(0, +).squareRoot()
        let sy = pairs.map { ($0.1 - my) * ($0.1 - my) }.reduce(0, +).squareRoot()
        guard sx > 0, sy > 0 else { return nil }
        return (cov / (sx * sy), pairs.count)
    }

    var body: some View {
        let pts = points
        let logged = pts.filter { $0.valence != nil }.count
        Section {
            if logged == 0 {
                Text("No State of Mind entries in Apple Health yet. If you log them in the Health app, they show up here next to Steadiness. Usual never asks for them.")
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(pts) { p in
                        if let s = p.steadiness {
                            LineMark(x: .value("Day", p.date, unit: .day), y: .value("Value", s), series: .value("Series", "Steadiness"))
                                .foregroundStyle(Palette.tint)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                                .interpolationMethod(.monotone)
                        }
                    }
                    ForEach(pts) { p in
                        if let v = p.valence {
                            PointMark(x: .value("Day", p.date, unit: .day), y: .value("Value", (v + 1) * 50))
                                .foregroundStyle(Palette.stripe(.rhythm))
                                .symbol(.diamond)
                                .symbolSize(28)
                        }
                    }
                    RuleMark(x: .value("Day", selected.start(), unit: .day))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { v in
                        AxisGridLine()
                        AxisValueLabel { Text(v.as(Int.self).map(String.init) ?? "") }
                    }
                    AxisMarks(position: .trailing, values: [0, 50, 100]) { v in
                        AxisValueLabel {
                            switch v.as(Int.self) {
                            case 0?: Text("Unpleasant")
                            case 100?: Text("Pleasant")
                            default: Text("Neutral")
                            }
                        }
                    }
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 14)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Steadiness and State of Mind over \(pts.count) days")
                .accessibilityValue(summary(pts))

                HStack(spacing: 16) {
                    legend(Palette.tint, "Steadiness", line: true)
                    legend(Palette.stripe(.rhythm), "State of Mind, logged", line: false)
                }
                .font(.caption).foregroundStyle(.secondary)

                Text(summary(pts)).fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Steadiness and State of Mind")
        } footer: {
            Text("State of Mind comes from the Health app and is not part of Steadiness. This only shows whether the two move together for you.")
        }
    }

    private func legend(_ c: Color, _ t: String, line: Bool) -> some View {
        HStack(spacing: 5) {
            if line { RoundedRectangle(cornerRadius: 1).fill(c).frame(width: 14, height: 2.5) }
            else { Image(systemName: "diamond.fill").font(.system(size: 8)).foregroundStyle(c) }
            Text(t)
        }
    }

    private func summary(_ pts: [Point]) -> String {
        guard let c = correlation(pts) else {
            return "Not enough days with both yet. It needs at least 7."
        }
        let r = c.r
        let words = r >= 0.5 ? "moved closely together" : r >= 0.3 ? "moved somewhat together" : r > -0.3 ? "didn't move together much" : "moved in opposite directions"
        return "Over \(c.n) days with both, they \(words) (r = \(r.formatted(.number.precision(.fractionLength(2)))))."
    }
}

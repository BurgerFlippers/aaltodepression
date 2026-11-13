import Foundation

enum Format {
    static func value(_ x: Double, _ f: ValueFormat) -> String {
        switch f {
        case .integer(let unit): return join(x.formatted(.number.precision(.fractionLength(0))), unit)
        case .decimal(let d, let unit): return join(x.formatted(.number.precision(.fractionLength(d))), unit)
        case .clockAfter18: return clock((x + 18).truncatingRemainder(dividingBy: 24))
        case .clockAfterMidnight: return clock(x)
        case .hoursMinutes:
            let m = Int((x * 60).rounded())
            return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
        case .minutes: return "\(Int(x.rounded())) min"
        case .percent(let d): return x.formatted(.number.precision(.fractionLength(d))) + " %"
        case .fractionPercent(let d): return (x * 100).formatted(.number.precision(.fractionLength(d))) + " %"
        case .text: return ""
        }
    }

    static func clock(_ hours: Double) -> String {
        var m = Int((hours * 60).rounded()) % (24 * 60)
        if m < 0 { m += 24 * 60 }
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private static func join(_ n: String, _ unit: String) -> String { unit.isEmpty ? n : "\(n) \(unit)" }

    static func date(_ day: Day) -> String {
        day.start().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

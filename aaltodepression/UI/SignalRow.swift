import SwiftUI

struct SignalRow: View {
    let info: SignalInfo
    let table: FeatureTable
    let day: Day

    var body: some View {
        let count = table.dayCount(info.key)
        let last = table.lastDay(info.key, onOrBefore: day)
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                Text(detail(count)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(lastValue(last))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ count: Int) -> String {
        var parts = [info.device.rawValue]
        parts.append(count > 0 ? "\(count) \(count == 1 ? "day" : "days")" : (info.note ?? "No data yet"))
        if count > 0, let note = info.note { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private func lastValue(_ last: Day?) -> String {
        guard let last else { return "–" }
        if case .text = info.format { return table.text(info.key, last).map(shortZone) ?? "–" }
        guard let v = table.value(info.key, last) else { return "–" }
        return Format.value(v, info.format)
    }

    private func shortZone(_ id: String) -> String { id.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? id }
}

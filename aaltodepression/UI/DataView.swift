import SwiftUI

/// Every signal Usual reads: source, last value, and how many days of history exist.
struct DataView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let table = model.table
        let present = FeatureCatalog.all.filter { table.dayCount($0.key) > 0 }
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(present.count) of \(FeatureCatalog.all.count) signals have data")
                            .font(.title3.weight(.semibold))
                        Text(summary(table)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                ForEach(SignalSource.allCases, id: \.self) { source in
                    let rows = FeatureCatalog.all.filter { $0.source == source }
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows) { info in SignalRow(info: info, table: table, day: model.scoredDay) }
                        } header: {
                            Text(source.rawValue)
                        } footer: {
                            if let note = footnote(source) { Text(note) }
                        }
                    }
                }
            }
            .navigationTitle("Data")
            .refreshable { if !model.isDemo { await model.readEverything() } }
        }
    }

    private func summary(_ t: FeatureTable) -> String {
        guard let first = t.firstDay, let last = t.lastDay else { return "Nothing read yet." }
        let days = last - first + 1
        let where_ = model.isDemo ? "Synthetic demo data for Perttu." : "Read from this iPhone and its Apple Watch."
        return "\(days) days of history. \(where_) Everything is worked out on this phone."
    }

    private func footnote(_ s: SignalSource) -> String? {
        switch s {
        case .health: "Apple Health doesn't say whether access was turned off or there's simply no data, so missing values count as unknown, never as zero."
        case .motion: "iPhone keeps only the last 7 days of motion."
        case .location: "Only daily numbers are kept. Locations never leave this phone."
        case .screenTime: "Apple lets apps draw this inside a Screen Time report but not read the number."
        case .sensorKit: "Planned for the research version with Aalto University. Needs a research permission from Apple."
        default: nil
        }
    }
}

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

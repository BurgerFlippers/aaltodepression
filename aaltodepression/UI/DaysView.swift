import SwiftUI

/// Days: pick a day on the rhythm chart, then see what moved its Steadiness.
struct DaysView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var days: [StepDay] { model.history }
    private var selected: StepDay? {
        let d = model.daysDay ?? model.scoredDay
        return days.last { $0.day == d } ?? days.last
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Actogram(days: days, table: model.table, selected: selected?.day,
                             firstNudge: days.first { $0.step == .nudge }?.day) { day in
                        model.daysDay = day
                        model.daysFocus = nil
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                if let s = selected {
                    DayBreakdown(day: s, table: model.table, focus: model.daysFocus,
                                 onPrev: { step(-1) }, onNext: { step(1) },
                                 canPrev: s.day > (days.first?.day ?? s.day), canNext: s.day < (days.last?.day ?? s.day))
                    SourcesSection(table: model.table, day: s.day, isDemo: model.isDemo)
                }
            }
            .contentMargins(.bottom, 80, for: .scrollContent)
            .navigationTitle("Days")
            .refreshable { if !model.isDemo { await model.readEverything() } }
        }
    }

    private func step(_ delta: Int) {
        guard let s = selected else { return }
        let target = s.day + delta
        guard days.contains(where: { $0.day == target }) else { return }
        model.daysFocus = nil
        withAnimation(reduceMotion ? nil : .snappy) { model.daysDay = target }
    }
}

// MARK: - The rhythm chart (actogram)

/// One row per day, newest at the bottom, 18:00 to 18:00 so the night sits in the middle.
struct Actogram: View {
    let days: [StepDay]
    let table: FeatureTable
    let selected: Day?
    let firstNudge: Day?
    var onSelect: (Day) -> Void

    static let rowHeight: CGFloat = 6
    static let gap: CGFloat = 1
    static let margin: CGFloat = 46
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            axis
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Self.gap) {
                        ForEach(days, id: \.day) { d in
                            ActogramRow(day: d, table: table, selected: d.day == selected,
                                        marker: marker(d))
                                .id(d.day)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(d.day) }
                                .accessibilityElement()
                                .accessibilityLabel(spoken(d))
                                .accessibilityAddTraits(d.day == selected ? [.isButton, .isSelected] : .isButton)
                                .accessibilityAction { onSelect(d.day) }
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 4).onChanged { v in
                        let i = Int(v.location.y / (Self.rowHeight + Self.gap))
                        if days.indices.contains(i) { onSelect(days[i].day) }
                    })
                }
                .frame(height: 200)
                .onAppear { if let s = selected { proxy.scrollTo(s, anchor: .center) } }
                .onChange(of: selected) { _, s in
                    guard let s else { return }
                    if reduceMotion { proxy.scrollTo(s, anchor: .center) } else { withAnimation { proxy.scrollTo(s, anchor: .center) } }
                }
            }
            legend
        }
    }

    private func marker(_ d: StepDay) -> String? {
        let prev = days.first { $0.day == d.day - 1 }
        if d.day == firstNudge { return "Usual noticed" }
        if d.result.likelyIll && prev?.result.likelyIll != true { return "cold" }
        if d.result.travelling && prev?.result.travelling != true { return "trip" }
        return nil
    }

    private var axis: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.margin)
            ForEach(["18", "00", "06", "12", "18"].indices, id: \.self) { i in
                Text(["18", "00", "06", "12", "18"][i])
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : (i == 4 ? .trailing : .center))
            }
        }
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            key(Palette.stripe(.sleep), "Asleep")
            key(Palette.stripe(.sleep).opacity(0.35), "Awake at night")
            key(Palette.stripe(.movement), "Steps")
            key(Palette.daylight, "Daylight")
        }
        .font(.caption2).foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private func key(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { RoundedRectangle(cornerRadius: 1).fill(c).frame(width: 10, height: 6); Text(t) }
    }

    private func spoken(_ d: StepDay) -> String {
        var parts = [Format.date(d.day)]
        if let b = table.value(F.bedtime, d.day), let w = table.value(F.wake, d.day) {
            parts.append("Asleep \(Format.value(b, .clockAfter18)) to \(Format.value(w, .clockAfterMidnight))")
        }
        if let s = table.value(F.steps, d.day) { parts.append(Format.value(s, .integer("steps"))) }
        if let s = d.result.steadiness { parts.append("Steadiness \(Int(s.rounded()))") }
        if let m = marker(d) { parts.append(m) }
        return parts.joined(separator: ". ")
    }
}

struct ActogramRow: View {
    let day: StepDay
    let table: FeatureTable
    let selected: Bool
    let marker: String?

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if let marker {
                    Text(marker)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.tint)
                        .fixedSize()
                        .offset(y: -1)
                }
            }
            .frame(width: Actogram.margin, height: Actogram.rowHeight, alignment: .leading)
            Canvas { ctx, size in
                let w = size.width, h = size.height
                func x(_ hoursAfter18: Double) -> CGFloat { CGFloat(hoursAfter18 / 24) * w }
                let sleepColor = Palette.stripe(.sleep)
                // Background band so empty rows still read as days.
                ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(.secondary.opacity(0.06)))
                // Steps per hour as ticks. This row covers 18:00 the day before to 18:00 this day.
                for hour in 0..<24 {
                    let isPrevEvening = hour >= 18
                    let d = isPrevEvening ? day.day - 1 : day.day
                    guard let s = table.value(F.stepsHour(hour), d), s >= 250 else { continue }
                    let pos = Double(isPrevEvening ? hour - 18 : hour + 6)
                    let tickH = min(h, CGFloat(s / 1500) * h + 1.5)
                    ctx.fill(Path(CGRect(x: x(pos) + 1, y: h - tickH, width: max(1.5, w / 24 - 2), height: tickH)),
                             with: .color(Palette.stripe(.movement).opacity(0.75)))
                }
                // Sleep bar, with time awake as a lighter middle segment.
                if let b = table.value(F.bedtime, day.day), let wk = table.value(F.wake, day.day) {
                    let start = x(b), end = x(wk + 6)
                    if end > start {
                        ctx.fill(Path(roundedRect: CGRect(x: start, y: 0, width: end - start, height: h), cornerRadius: 1),
                                 with: .color(sleepColor))
                        if let awake = table.value(F.awakeMin, day.day), awake > 0 {
                            let aw = min(end - start, x(awake / 60))
                            ctx.fill(Path(CGRect(x: (start + end - aw) / 2, y: 0, width: aw, height: h)),
                                     with: .color(sleepColor.opacity(0.35)))
                        }
                    }
                }
                // Daylight as a thin underline around solar noon.
                if let dl = table.value(F.daylightMin, day.day) ?? table.value(F.daylightWalkMin, day.day), dl > 0 {
                    let noon = (table.value(F.sunrise, day.day).flatMap { r in table.value(F.sunset, day.day).map { (r + $0) / 2 } } ?? 12.2) + 6
                    let half = x(dl / 60) / 2
                    ctx.fill(Path(CGRect(x: x(noon) - half, y: h - 1.5, width: half * 2, height: 1.5)), with: .color(Palette.daylight))
                }
            }
            .frame(height: Actogram.rowHeight)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Color.primary, lineWidth: 1).padding(-1.5)
                }
            }
        }
    }
}

// MARK: - The selected day

struct DayBreakdown: View {
    let day: StepDay
    let table: FeatureTable
    let focus: ScoreKind?
    var onPrev: () -> Void
    var onNext: () -> Void
    var canPrev: Bool
    var canNext: Bool
    @State private var expanded: Set<ScoreKind> = []
    @State private var showUnscored = false

    private static let oneSided: Set<String> = [F.steps, F.exerciseMin, F.activeHours, F.awayHours, F.placesVisited, Scorer.sleep3Key]

    var body: some View {
        let r = day.result
        let kinds = Effects.sortedKinds(r)
        Section {
            ForEach(kinds) { kind in
                DisclosureGroup(isExpanded: Binding(get: { expanded.contains(kind) },
                                                    set: { if $0 { expanded.insert(kind) } else { expanded.remove(kind) } })) {
                    ForEach(rows(kind), id: \.key) { p in partRow(p, all: rows(kind)) }
                } label: {
                    scoreLabel(kind)
                }
            }
        } header: {
            header
        }
        .onAppear { resetExpanded(kinds) }
        .onChange(of: day.day) { resetExpanded(Effects.sortedKinds(day.result)) }
        .onChange(of: focus) { resetExpanded(Effects.sortedKinds(day.result)) }

        if r.likelyIll || r.travelling {
            Section("Context this day") {
                if r.likelyIll { Text(illReason).fixedSize(horizontal: false, vertical: true) }
                if r.travelling { Text(travelReason).fixedSize(horizontal: false, vertical: true) }
                Text("Not counted as a drift day.").foregroundStyle(.secondary)
            }
        }

        Section {
            DisclosureGroup(isExpanded: $showUnscored) {
                ForEach(unscored, id: \.key) { info in
                    LabeledContent(info.title) {
                        VStack(alignment: .trailing) {
                            Text(value(info))
                            if let u = Baseline.usual(info.key, in: table, for: day.day) {
                                Text("usual \(Format.value(u.median, info.format))").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unscored.count) more signals")
                    Text("Read and kept on this phone, not part of Steadiness").font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Recorded, not scored")
        }
    }

    private func resetExpanded(_ kinds: [ScoreKind]) {
        if let f = focus { expanded = [f] } else if let first = kinds.first { expanded = [first] } else { expanded = [] }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onPrev) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .disabled(!canPrev).accessibilityLabel("Previous day")
                Text(Format.date(day.day)).font(.headline).foregroundStyle(.primary).textCase(nil)
                    .frame(maxWidth: .infinity)
                Button(action: onNext) { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(!canNext).accessibilityLabel("Next day")
            }
            .buttonStyle(.borderless)
            HStack(alignment: .firstTextBaseline) {
                Text("Steadiness \(day.result.steadiness.map { "\(Int($0.rounded()))" } ?? "–")")
                    .font(.title2.weight(.semibold)).foregroundStyle(.primary)
                if let b = day.baselineDay {
                    Text("usual \(Int(b.rounded()))").foregroundStyle(.secondary)
                }
            }
            .textCase(nil)
            .accessibilityElement(children: .combine)
        }
        .padding(.bottom, 4)
    }

    private func rows(_ kind: ScoreKind) -> [ScorePart] {
        let r = day.result
        if kind == .daylight, let s = r.scores[.daylight] {
            let minutes = s / 100 * r.daylightTarget
            return [ScorePart(key: r.daylightEstimated ? F.daylightWalkMin : F.daylightMin,
                              value: table.value(F.daylightMin, day.day) ?? table.value(F.daylightWalkMin, day.day) ?? minutes,
                              usual: Usual(median: r.daylightTarget, mad: 0), points: s)]
        }
        let ps = r.parts[kind] ?? []
        return ps.sorted { Effects.onScore($0, in: ps) < Effects.onScore($1, in: ps) }
    }

    private func scoreLabel(_ kind: ScoreKind) -> some View {
        let r = day.result
        let effect = Effects.onSteadiness(kind, r) ?? 0
        return HStack {
            Circle().fill(Palette.stripe(kind)).frame(width: 10, height: 10)
            Text("\(kind.title) \(r.scores[kind].map { "\(Int($0.rounded()))" } ?? "–")").font(.body.weight(.semibold))
            Spacer()
            Text(effectText(effect, aboveUsual: false))
                .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func partRow(_ p: ScorePart, all: [ScorePart]) -> some View {
        let info = Explain.info(p.key)
        let isDaylight = p.key == F.daylightMin || p.key == F.daylightWalkMin
        let effect = isDaylight ? p.points - 100 : Effects.onScore(p, in: all)
        let above = (Self.oneSided.contains(p.key) || isDaylight) && (p.usual.map { p.value > $0.median } ?? false)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                if let u = p.usual {
                    Text("\(isDaylight ? "target" : "usual") \(Format.value(u.median, info.format))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.value(p.value, info.format)).monospacedDigit()
                Text(effectText(effect, aboveUsual: above)).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func effectText(_ effect: Double, aboveUsual: Bool) -> String {
        if aboveUsual { return "↑ above usual" }
        if effect <= -3 { return "↓ pulls down \(Int(abs(effect).rounded()))" }
        return "· at usual"
    }

    private var illReason: String {
        var parts: [String] = []
        if let hr = table.value(F.restingHR, day.day), let u = Baseline.usual(F.restingHR, in: table, for: day.day) {
            parts.append("Resting heart rate \(Int(hr.rounded())), usual \(Int(u.median.rounded())).")
        }
        if let t = table.value(F.wristTemp, day.day), let u = Baseline.usual(F.wristTemp, in: table, for: day.day) {
            parts.append(String(format: "Wrist temperature %+.1f °C.", t - u.median))
        }
        return "Looks like a cold. " + parts.joined(separator: " ")
    }

    private var travelReason: String {
        var parts = ["Travelling."]
        if let tz = table.text(F.timeZone, day.day) { parts.append("Slept in time zone \(tz.split(separator: "/").last.map(String.init) ?? tz).") }
        if let km = table.value(F.maxKmFromHome, day.day), km > 100 { parts.append("\(Int(km.rounded())) km from home.") }
        return parts.joined(separator: " ")
    }

    private var unscored: [SignalInfo] {
        let scored = Set(day.result.parts.values.flatMap { $0.map(\.key) } + [F.daylightMin, F.daylightWalkMin])
        return FeatureCatalog.all.filter { !scored.contains($0.key) && (table.value($0.key, day.day) != nil || table.text($0.key, day.day) != nil) }
    }

    private func value(_ info: SignalInfo) -> String {
        if case .text = info.format { return table.text(info.key, day.day) ?? "–" }
        return table.value(info.key, day.day).map { Format.value($0, info.format) } ?? "–"
    }
}

// MARK: - Sources

struct SourcesSection: View {
    let table: FeatureTable
    let day: Day
    let isDemo: Bool
    @State private var open = false

    var body: some View {
        let present = FeatureCatalog.all.filter { table.dayCount($0.key) > 0 }
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(present.count) of \(FeatureCatalog.all.count) signals have data").font(.headline)
                Text(summary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Every signal and its source", isExpanded: $open) {
                ForEach(SignalSource.allCases, id: \.self) { source in
                    let rows = FeatureCatalog.all.filter { $0.source == source }
                    if !rows.isEmpty {
                        Text(source.rawValue).font(.subheadline.weight(.semibold)).padding(.top, 6)
                        ForEach(rows) { SignalRow(info: $0, table: table, day: day) }
                    }
                }
            }
        } header: {
            Text("Sources")
        } footer: {
            Text("Apple Health doesn't say whether access was turned off or there's simply no data, so missing values count as unknown, never as zero. Locations never leave this phone.")
        }
    }

    private var summary: String {
        guard let first = table.firstDay, let last = table.lastDay else { return "Nothing read yet." }
        let src = isDemo ? "Synthetic demo data for Perttu." : "Read from this iPhone and its Apple Watch."
        return "\(last - first + 1) days of history. \(src) Everything is worked out on this phone."
    }
}

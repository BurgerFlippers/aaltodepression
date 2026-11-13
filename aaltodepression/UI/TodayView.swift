import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var detail: ScoreKind?
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if let c = model.current {
                        StripesView(result: c.result, locationEnabled: model.locationEnabled) { detail = $0 }
                        StateSection(day: c)
                        HistoryChart(days: model.history)
                    } else {
                        ContentUnavailableView("No days to show yet", systemImage: "sun.horizon",
                                               description: Text("Usual needs a week of Health data before it can compare a day with your usual."))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle(model.isDemo ? "Today" : "Yesterday")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHelp = true } label: { HStack(spacing: 6) { Image(systemName: "phone.fill"); Text("Help") } }
                        .accessibilityHint("Shows numbers you can call right away")
                }
            }
            .sheet(item: $detail) { kind in
                if let c = model.current { ScoreDetailView(kind: kind, result: c.result) }
            }
            .sheet(isPresented: $showHelp) { HelpView() }
            .refreshable { if !model.isDemo { await model.readEverything() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Format.date(model.scoredDay))
                .font(.title3.weight(.semibold))
            if model.isDemo {
                Text("Demo with Perttu, day \(model.demoDay)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The stripes

struct StripesView: View {
    let result: DayResult
    let locationEnabled: Bool
    var onSelect: (ScoreKind) -> Void

    var kinds: [ScoreKind] { ScoreKind.allCases.filter { $0 != .places || locationEnabled } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 8) {
                ForEach(kinds) { kind in
                    Button { onSelect(kind) } label: {
                        StripeRow(kind: kind, score: result.scores[kind])
                    }
                    .buttonStyle(StripeButtonStyle())
                }
            }
            Text("A full stripe means your usual or better.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct StripeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct StripeRow: View {
    let kind: ScoreKind
    let score: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 46
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 92
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 38

    var body: some View {
        let color = Palette.stripe(kind)
        let fraction = (score ?? 0) / 100
        HStack(spacing: 12) {
            Text(kind.title)
                .font(.body.weight(.medium))
                .frame(width: labelWidth, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(color.opacity(score == nil ? 0.1 : 0.28))
                    Rectangle().fill(color).frame(width: geo.size.width * fraction)
                }
                .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: fraction)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(score.map { "\(Int($0.rounded()))" } ?? "–")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(score == nil ? .secondary : .primary)
                .frame(width: valueWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue(spokenValue)
        .accessibilityHint("Shows what this is based on")
        .accessibilityAddTraits(.isButton)
    }

    private var spokenValue: String {
        guard let s = score else { return "No data for this day" }
        let n = Int(s.rounded())
        return n >= 95 ? "\(n) of 100, your usual" : "\(n) of 100, below your usual"
    }
}

// MARK: - What the day calls for

struct StateSection: View {
    @Environment(AppModel.self) private var model
    let day: StepDay

    var body: some View {
        switch day.step {
        case .reachOut: ReachOutView()
        case .nudge: if let s = model.suggestion { NudgeView(suggestion: s) }
        case .steady: CalmLine(text: calmText)
        }
    }

    private var calmText: String {
        let r = day.result
        if r.likelyIll {
            return "Your heart rate and wrist temperature are up, like during a cold. Days like this are left out of the comparison."
        }
        if r.travelling {
            return "You're away from home. Days on the road look different, so they are left out of the comparison."
        }
        if let s = r.dayScore, let b = day.baselineDay, s < b - 10 {
            return "A quieter day than usual. Nothing to do about it."
        }
        return "Close to your usual. Nothing to do today."
    }
}

struct CalmLine: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct NudgeView: View {
    @Environment(AppModel.self) private var model
    let suggestion: SuggestedAction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One small thing for today")
                .font(.headline)
            Text(suggestion.action.title)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let why = reason {
                Text(why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let seen = seenLine {
                Label(seen, systemImage: "applewatch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("From your plan with \(model.plan.nurseName).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var info: SignalInfo? { suggestion.action.seenBy.flatMap { FeatureCatalog.byKey[$0] } }

    private var reason: String? {
        guard let info, let x = suggestion.todayValue, let u = suggestion.usual, x < u.median else { return nil }
        return "\(info.title): \(Format.value(x, info.format)) today. Usually about \(Format.value(u.median, info.format))."
    }

    private var seenLine: String? {
        guard let info else { return nil }
        if let x = suggestion.todayValue, let u = suggestion.usual, x >= u.median {
            return "Seen today: \(Format.value(x, info.format))"
        }
        return info.device == .watch ? "Your Watch will notice it." : "Your iPhone will notice it."
    }
}

struct ReachOutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.messageCancelled
                     ? "Your message to \(model.plan.friendName) won't go out."
                     : "\(model.plan.friendName) gets your message tomorrow at 12:00.")
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.plan.friendMessage)
                    .font(.body)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(model.messageCancelled ? 0.5 : 1)
                    .accessibilityLabel("Message: \(model.plan.friendMessage)")
                Text("You wrote this with \(model.plan.nurseName). It goes out on its own unless you cancel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(model.messageCancelled ? "Send it after all" : "Cancel message") {
                    model.messageCancelled.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            Divider()
            Label {
                Text("\(model.plan.nurseName) will call you this week. You don't need to prepare anything.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "phone.arrow.down.left")
            }
            .font(.body)
        }
        .padding(18)
        .background(Palette.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

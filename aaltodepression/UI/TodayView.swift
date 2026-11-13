import SwiftUI

/// Today: what to do first, then how the day sits against the usual.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showHelp = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if let c = model.current {
                        if ActionCard.needsCard(c, model) {
                            ActionCard(day: c)
                        } else {
                            StatusLine(day: c)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            if let s = c.result.steadiness {
                                if model.showsSteadiness {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("\(Int(s.rounded()))")
                                                .font(.system(size: 76, weight: .semibold, design: .rounded))
                                                .monospacedDigit()
                                                .contentTransition(.numericText())
                                            Text("Steadiness").font(.title3).foregroundStyle(.secondary)
                                        }
                                        Text(SteadinessBand(s).words).font(.title2.weight(.semibold))
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits(.isHeader)
                                } else {
                                    Text(SteadinessBand(s).words)
                                        .font(.title2.weight(.semibold))
                                        .accessibilityAddTraits(.isHeader)
                                }
                            }
                            StripesView(result: c.result, locationEnabled: model.locationEnabled) { kind in
                                model.openDays(c.day, focus: kind)
                            }
                            Button {
                                model.openDays(c.day)
                            } label: {
                                Label("Why these numbers", systemImage: "chevron.right")
                                    .labelStyle(TrailingIconLabelStyle())
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                        }
                    } else {
                        ContentUnavailableView("No days to show yet", systemImage: "sun.horizon",
                                               description: Text("Usual needs a week of Health data before it can compare a day with your usual."))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .contentMargins(.bottom, 96, for: .scrollContent)   // clears the floating tab bar
            .navigationTitle(model.isDemo ? "Today" : "Yesterday")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHelp = true } label: { HStack(spacing: 6) { Image(systemName: "phone.fill"); Text("Help") } }
                        .accessibilityHint("Shows numbers you can call right away")
                }
            }
            .sheet(isPresented: $showHelp) { HelpView() }
            .sheet(isPresented: $model.showSettings) { SettingsView() }
            .refreshable { if !model.isDemo { await model.readEverything() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Format.date(model.scoredDay)).font(.title3.weight(.semibold))
            if model.isDemo {
                Text("Demo with Perttu, day \(model.demoDay)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon.imageScale(.small) }
    }
}

// MARK: - What to do today

/// One quiet line when there's nothing to do: steady, done, or a day that isn't counted.
struct StatusLine: View {
    @Environment(AppModel.self) private var model
    let day: StepDay

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(Palette.tint)
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var done: (CarePlan.Action, Double)? {
        guard day.step == .nudge, let s = model.suggestion, let v = model.doneToday(s.action) else { return nil }
        return (s.action, v)
    }

    private var icon: String {
        if done != nil { return "checkmark.circle.fill" }
        if day.result.likelyIll { return "thermometer.medium" }
        if day.result.travelling { return "airplane" }
        return "checkmark.circle"
    }

    private var text: String {
        if let (a, v) = done { return "Done today: \(NudgeContent.noticedText(a, v)). Nothing else needed." }
        if day.result.likelyIll { return "Looks like a cold. Usual is not counting today against you." }
        if day.result.travelling { return "You're travelling. Usual is not counting today against you." }
        return "Nothing needed today. Your days look like your usual."
    }
}

struct ActionCard: View {
    @Environment(AppModel.self) private var model
    let day: StepDay

    /// A card only when there is something to do: an action not yet done, or the step-2 message.
    @MainActor static func needsCard(_ day: StepDay, _ model: AppModel) -> Bool {
        switch day.step {
        case .reachOut: return true
        case .nudge:
            guard let s = model.suggestion else { return false }
            return model.doneToday(s.action) == nil
        case .steady: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var content: some View {
        switch day.step {
        case .reachOut: ReachOutContent()
        case .nudge:
            if let s = model.suggestion { NudgeContent(suggestion: s) } else { steady }
        case .steady: steady
        }
    }

    @ViewBuilder private var steady: some View {
        let r = day.result
        if r.likelyIll {
            Text("Nothing needed today.").font(.title3.weight(.semibold))
            Text("Looks like a cold. Usual is not counting today against you.").foregroundStyle(.secondary)
        } else if r.travelling {
            Text("Nothing needed today.").font(.title3.weight(.semibold))
            Text("You're travelling. Usual is not counting today against you.").foregroundStyle(.secondary)
        } else {
            Text("Nothing needed today.").font(.title3.weight(.semibold))
            Text("Your days look like your usual.").foregroundStyle(.secondary)
        }
    }
}

struct NudgeContent: View {
    @Environment(AppModel.self) private var model
    let suggestion: SuggestedAction

    var body: some View {
        let a = suggestion.action
        if let done = model.doneToday(a) {
            Label {
                Text("Done. Noticed \(noticed(done)).").font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.tint)
            }
            Text("From your plan with \(model.plan.nurseName). Nothing else needed today.")
                .foregroundStyle(.secondary)
        } else {
            Text("One small thing for today").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(a.title)?").font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(historyLine).foregroundStyle(.secondary)
            if let source { Label(source, systemImage: "applewatch").font(.subheadline).foregroundStyle(.secondary) }
        }
    }

    private var historyLine: String {
        guard let r = model.records[suggestion.action.key], r.tried > 0 else { return "Not tried yet. It's in your plan with \(model.plan.nurseName)." }
        return "Helped \(r.helped) of \(r.tried) \(r.tried == 1 ? "time" : "times") before."
    }

    private var source: String? {
        guard let key = suggestion.action.seenBy, let info = FeatureCatalog.byKey[key] else { return nil }
        return info.device == .watch ? "Your watch will notice it" : "Your iPhone will notice it"
    }

    private func noticed(_ v: Double) -> String { Self.noticedText(suggestion.action, v) }

    static func noticedText(_ a: CarePlan.Action, _ v: Double) -> String {
        switch a.seenBy {
        case F.mindfulMin?: "\(Int(v.rounded())) min of breathing"
        case F.daylightMin?: "\(Int(v.rounded())) min of daylight"
        case F.steps?: "\(Format.value(v, .integer("steps")))"
        default: "it"
        }
    }
}

struct ReachOutContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let plan = model.plan
        Text("Let's bring people in.").font(.title2.weight(.semibold))
        Text(model.messageCancelled ? "Not sending to \(plan.friendName) this time." : "Your message to \(plan.friendName) goes out tomorrow at 12:00.")
            .fixedSize(horizontal: false, vertical: true)
        QuoteBlock(text: plan.friendMessage).opacity(model.messageCancelled ? 0.5 : 1)
        if model.messageCancelled {
            Button("Send it after all") { model.messageCancelled = false }
                .buttonStyle(.bordered).controlSize(.large)
        } else {
            HStack(spacing: 10) {
                Button("Send now") { model.showCompose = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Not this time") { model.messageCancelled = true }
                    .buttonStyle(.bordered).controlSize(.large)
            }
        }
        Divider().padding(.vertical, 2)
        Label("\(plan.nurseName) will call you this week.", systemImage: "phone.arrow.down.left")
    }
}

struct QuoteBlock: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 1).fill(Palette.tint.opacity(0.5)).frame(width: 2)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message: \(text)")
    }
}

// MARK: - The stripes

struct StripesView: View {
    let result: DayResult
    let locationEnabled: Bool
    var onSelect: (ScoreKind) -> Void

    var kinds: [ScoreKind] { ScoreKind.allCases.filter { $0 != .places || locationEnabled } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(kinds) { kind in
                Button { onSelect(kind) } label: { StripeRow(kind: kind, score: result.scores[kind]) }
                    .buttonStyle(StripeButtonStyle())
            }
            Text("A full stripe means your usual or better.").font(.footnote).foregroundStyle(.secondary)
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
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 92
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 38

    var body: some View {
        let color = Palette.stripe(kind)
        let fraction = (score ?? 0) / 100
        HStack(spacing: 12) {
            Text(kind.title).font(.body.weight(.medium)).frame(width: labelWidth, alignment: .leading)
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
                .font(.body.weight(.semibold)).monospacedDigit()
                .foregroundStyle(score == nil ? .secondary : .primary)
                .frame(width: valueWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue(score.map { s in "\(Int(s.rounded())) of 100, " + (s >= 95 ? "at your usual" : "below your usual") } ?? "No data for this day")
        .accessibilityHint("Shows this score in Days")
        .accessibilityAddTraits(.isButton)
    }
}

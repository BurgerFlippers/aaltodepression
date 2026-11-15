import SwiftUI

/// A judging overlay. The live Health history and edited demo copy are explicitly distinguished.
struct BesideDemoBar: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var details = false
    private var dayLabel: String {
        if let contact = presentation.callCue { return "A call from \(contact) is suggested" }
        switch presentation.healthSignal?.step {
        case .reachOut: return "A support check is suggested"
        case .nudge: return "A small step could help today"
        default: return presentation.signalHasBaseline ? "Daily signals compared with your usual" : "Current plan · learning your usual"
        }
    }
    var body: some View {
        VStack(spacing: 7) {
            Button { details = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(presentation.isDemoMode ? "DEMOBAR · DEMO COPY" : "DEMOBAR · LIVE DATA").font(.caption2.bold()).tracking(0.6)
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                    }
                    Text(dayLabel).font(.caption).fixedSize(horizontal: false, vertical: true)
                    GeometryReader { geometry in
                        BalanceScale().frame(height: 18)
                        if let position = presentation.indicatorPosition {
                            Circle().fill(.white)
                                .overlay { Circle().strokeBorder(Color.black, style: StrokeStyle(lineWidth: 3, dash: presentation.signalHasBaseline ? [] : [3, 2])) }
                                .frame(width: 18, height: 18)
                                .offset(x: (geometry.size.width - 18) * position)
                        }
                    }.frame(height: 18).accessibilityHidden(true)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: presentation.indicatorPosition)
                    HStack {
                        Text(presentation.routineFeedback.categoryCount == 0 ? "Your usual" : "\(presentation.routineFeedback.categoryCount) routine \(presentation.routineFeedback.categoryCount == 1 ? "category" : "categories") logged")
                        Spacer()
                        Text("More support")
                    }.font(.caption2).foregroundStyle(.secondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint("Opens editable readings for this day")

        }.foregroundStyle(EverydayStyle.ink).padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity).background(EverydayStyle.paper)
            .overlay(alignment: .bottom) { Divider() }
            .sheet(isPresented: $details) { BesideDemoControlsView(embeddedInDemo: true) }
    }
}

/// Compact day selector. Currently unused; Trends has its own toolbar day buttons.
struct BesideDayPicker: View {
    @Environment(BesidePresentation.self) private var presentation
    var body: some View {
            HStack(spacing: 5) {
                Button { presentation.selectDay(presentation.day - 1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 44) }
                    .disabled(presentation.day <= Day(Date()) - 120).accessibilityLabel("Previous day")
                ForEach(Day.range(max(presentation.day - 4, Day(Date()) - 120), presentation.day + 1), id: \.jdn) { day in
                    Button { presentation.selectDay(day) } label: {
                        Text(day.start().formatted(.dateTime.day().month(.abbreviated))).font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(day == presentation.day ? EverydayStyle.mint : .clear, in: Capsule())
                    }.buttonStyle(.plain).accessibilityAddTraits(day == presentation.day ? .isSelected : [])
                }
                Button { presentation.selectDay(presentation.day + 1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 44) }
                    .disabled(presentation.day >= Day(Date())).accessibilityLabel("Next day")
            }
        .buttonStyle(.borderless)
        .foregroundStyle(EverydayStyle.ink)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(EverydayStyle.paper)
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct BesideWinsView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedback = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(EverydayStyle.mint).frame(width: 52, height: 52)
                Image(systemName: "heart.fill").font(.title2).foregroundStyle(EverydayStyle.ink)
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : presentation.winCount)
            }.scaleEffect(presentation.winCount > 0 ? 1 : 0.8)
            VStack(alignment: .leading, spacing: 6) {
                Text("Small steps count.").font(.headline)
                HStack(spacing: 5) {
                    ForEach(0..<min(presentation.winCount, 8), id: \.self) { index in
                        Capsule().fill(EverydayStyle.color(EverydayTaskKind.allCases[index % 4]))
                            .frame(width: 22, height: 8).transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                }.accessibilityLabel("\(presentation.winCount) things done today")
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: presentation.winCount)
            .sensoryFeedback(.success, trigger: feedback)
            .onChange(of: presentation.winCount) { old, new in if new > old { feedback.toggle() } }
    }
}

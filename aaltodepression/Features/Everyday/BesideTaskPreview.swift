import SwiftUI

/// "Show more tasks (demo)": hand-set scores for all six categories preview which tasks the demo rule offers.
/// Lives only on the Today tab, is never stored and does not touch the live day, Trends or the widget.
struct BesideTaskPreview: View {
    @Binding var scores: [ScoreKind: Double]
    let day: Day
    let close: () -> Void

    private var offer: SidequestPreview { SidequestDemoRules.preview(day: day, scores: scores) }
    /// All six score categories, so each can drive the demo tasks.
    private var kinds: [ScoreKind] { ScoreKind.allCases }

    static func title(_ kind: ScoreKind) -> String { kind == .places ? "Getting out" : kind.title }

    var body: some View {
        let offer = offer
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    panel(offer)
                    Spacer(minLength: 0)
                    VStack(spacing: 8) {
                        ForEach(offer.options) { quest in card(quest, kind: offer.kinds[quest.id], smaller: offer.easy) }
                    }
                    Button("Hide demo", action: close)
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 36)
                        .accessibilityIdentifier("task-preview-hide")
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    private func panel(_ offer: SidequestPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scores for this demo").font(.subheadline.weight(.semibold))
            ForEach(kinds) { kind in
                HStack(spacing: 10) {
                    Text(Self.title(kind)).font(.footnote).frame(width: 82, alignment: .leading)
                    Slider(value: binding(kind), in: 0...100) { Text(Self.title(kind)) }
                    Text("\(Int((scores[kind] ?? 0).rounded()))").font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                }
            }
            Divider().padding(.vertical, 2)
            LabeledContent("Task focus", value: focus(offer))
                .font(.footnote)
            LabeledContent("Task difficulty", value: offer.easy ? "Easy" : "Normal")
                .font(.footnote)
            Text("The lowest scores choose the tasks. Below 50 they get easier. Demo only: your day is unchanged.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("task-preview-panel")
    }

    private func card(_ quest: Sidequest, kind: ScoreKind?, smaller: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: BesideQuestStyle.visual(quest))
                .font(.title3).symbolRenderingMode(.hierarchical).foregroundStyle(EverydayStyle.accent)
                .frame(width: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.map(Self.title) ?? quest.category.title).font(.caption).foregroundStyle(.secondary)
                Text(BesideQuestStyle.brief(quest, smaller: smaller)).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(BesideQuestStyle.cardColor(0), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func focus(_ offer: SidequestPreview) -> String {
        offer.focus.map { "\(Self.title($0)) \(Int((offer.focusScores[$0] ?? 0).rounded()))" }.joined(separator: " · ")
    }

    private func binding(_ kind: ScoreKind) -> Binding<Double> {
        Binding(get: { scores[kind] ?? 0 }, set: { scores[kind] = $0 })
    }
}

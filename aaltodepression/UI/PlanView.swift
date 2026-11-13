import SwiftUI

/// The plan as one if-then ladder that explains the whole service.
struct PlanView: View {
    @Environment(AppModel.self) private var model

    private var activeRung: Int {
        switch model.current?.step {
        case .nudge?: 2
        case .reachOut?: 3
        default: 1
        }
    }

    var body: some View {
        let plan = model.plan
        let records = model.planRecords
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Rung(number: 1, active: activeRung == 1, last: false,
                         title: "When my days look like my usual") {
                        Text("Nothing needed.").foregroundStyle(.secondary)
                    }
                    Rung(number: 2, active: activeRung == 2, last: false,
                         title: "When my rhythm starts to drift") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I do one of these:").foregroundStyle(.secondary)
                            ForEach(plan.actions) { a in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.title).font(.body.weight(.medium))
                                    Text(history(a, records[a.key])).font(.footnote).foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    Rung(number: 3, active: activeRung == 3, last: false,
                         title: "If it doesn't settle in about 10 days") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(plan.friendName) gets my message").font(.body.weight(.medium))
                            QuoteBlock(text: plan.friendMessage)
                            Text("\(plan.nurseName) calls me").font(.body.weight(.medium))
                        }
                    }
                    Rung(number: 4, active: false, last: true, title: "If that's not enough") {
                        Text("\(plan.nurseName) can offer a booster TMS session.").foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("My early signs").font(.headline)
                        ForEach(plan.earlySigns, id: \.self) { sign in
                            Label(sign, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                        }
                        Text("\(plan.nurseName) wrote this with you on \(startText). It runs \(plan.months) months.")
                            .padding(.top, 8)
                        Text("To change it, talk to \(plan.nurseName).").foregroundStyle(.secondary)
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 20)
            }
            .contentMargins(.bottom, 96, for: .scrollContent)
            .navigationTitle("Plan")
        }
    }

    private func history(_ a: CarePlan.Action, _ r: ActionRecord?) -> String {
        guard a.seenBy != nil else { return "You tell Usual" }
        var line: String
        if let r, r.tried > 0 { line = "Helped \(r.helped) of \(r.tried) \(r.tried == 1 ? "time" : "times")" } else { line = "Not tried yet" }
        if model.current?.step == .nudge, model.suggestion?.action.key == a.key, model.doneToday(a) != nil { line += " · done today" }
        return line
    }

    private var startText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: model.plan.startDate) else { return model.plan.startDate }
        return d.formatted(.dateTime.day().month(.wide))
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon.font(.system(size: 6)).foregroundStyle(.secondary)
            configuration.title
        }
    }
}

/// One rung: a node on a vertical line, the condition, and what happens.
struct Rung<Content: View>: View {
    let number: Int
    let active: Bool
    let last: Bool
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().strokeBorder(Palette.tint, lineWidth: 2).frame(width: 22, height: 22)
                    if active { Circle().fill(Palette.tint).frame(width: 12, height: 12) }
                }
                .padding(.top, 2)
                if !last { Rectangle().fill(Palette.tint.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity) }
            }
            .frame(width: 22)
            VStack(alignment: .leading, spacing: 8) {
                if active {
                    Label("You are here", systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Palette.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(Palette.tint)
                }
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(.bottom, last ? 0 : 26)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rung \(number) of 4. \(title).\(active ? " You are here." : "")")
    }
}

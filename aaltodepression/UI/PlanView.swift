import SwiftUI

/// The nurse's plan, read-only.
struct PlanView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.plan
        NavigationStack {
            List {
                Section {
                    Text("\(plan.nurseName) wrote this plan with you. It runs \(plan.months) months from \(startText).")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section("Early signs you named") {
                    ForEach(plan.earlySigns, id: \.self) { Text($0) }
                }
                Section {
                    ForEach(plan.actions) { a in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(a.title)
                            if let key = a.seenBy, let info = FeatureCatalog.byKey[key] {
                                Label("Noticed in \(info.title.lowercased())", systemImage: "checkmark.circle")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Small things that help")
                } footer: {
                    Text("When your days drift from your usual, Usual suggests one of these.")
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.friendName).font(.headline)
                        Text(plan.friendMessage).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your message to a friend")
                } footer: {
                    Text("If a longer drift continues, this goes to \(plan.friendName), and \(plan.nurseName) calls you. You can cancel the message before it goes out.")
                }
            }
            .navigationTitle("Plan")
        }
    }

    private var startText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: model.plan.startDate) else { return model.plan.startDate }
        return d.formatted(.dateTime.day().month(.wide).year())
    }
}

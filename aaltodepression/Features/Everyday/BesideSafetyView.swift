import SwiftUI

struct BesideSafetyView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var support = false
    var body: some View {
        NavigationStack {
            Form {
                if SafetyCopy.reviewedByClinician, let step = presentation.backend.planner.safety?.step {
                    switch step {
                    case .bridge:
                        Section {
                            Text(SafetyCopy.bridgeTitle).font(.title3.bold())
                            Text(SafetyCopy.bridgeBody)
                            Text(SafetyCopy.dataNote).font(.footnote).foregroundStyle(.secondary)
                            Button("Continue") { presentation.backend.planner.safetyContinue() }
                        }
                    case .ask(let question):
                        Section(SafetyCopy.timeframe) {
                            Text(SafetyCopy.text(question))
                            Button("Yes") { presentation.backend.planner.safetyAnswer(true) }
                            Button("No") { presentation.backend.planner.safetyAnswer(false) }
                        }
                    case .done(let outcome):
                        Section {
                            Text(SafetyCopy.title(outcome)).font(.title3.bold())
                            Button("Support options") { support = true }
                        }
                    }
                } else {
                    Section { Button("Talk to someone") { support = true } }
                }
            }.navigationTitle("A moment for you").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { presentation.backend.planner.finishSafety(); dismiss() } } }
                .sheet(isPresented: $support) { EverydayHelpView() }
        }
    }
}

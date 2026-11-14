import SwiftUI

struct BesideSupportSuggestionView: View {
    let suggestion: ContactSuggestion
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var recorded = false
    var body: some View {
        NavigationStack {
            Form {
                Section("A practical hand") {
                    LabeledContent("To", value: suggestion.contact.name)
                    Text(suggestion.reason)
                }
                Section("Message preview") { Text(suggestion.message) }
                Section {
                    if recorded { Label("Request recorded · not delivered", systemImage: "checkmark.circle") }
                    else {
                        Button("Try request in prototype") {
                            recorded = presentation.backend.planner.send(suggestion) != nil
                        }
                    }
                } footer: { Text("The current backend records support requests locally. It does not deliver messages to your contacts.") }
            }.navigationTitle("Support suggestion").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct BesideSupportRequestsView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(presentation.backend.planner.outbox) { message in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(message.contactName).font(.headline); Spacer(); Text(label(message.status)).font(.caption).foregroundStyle(.secondary) }
                            Text(message.text).font(.subheadline)
                            if let reply = message.simulatedReply { Text("Demo reply: \(reply)").font(.subheadline).foregroundStyle(.secondary) }
                            if message.status == .pending {
                                HStack {
                                    Button("Try confirmation") { presentation.backend.planner.confirm(messageID: message.id) }
                                    Button("Cancel request", role: .destructive) { presentation.backend.planner.cancel(messageID: message.id) }
                                }.buttonStyle(.bordered)
                            }
                        }.padding(.vertical, 8)
                    }
                } footer: { Text("Prototype records only. No automatic messages have been delivered.") }
            }.navigationTitle("Support requests").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func label(_ status: MessageStatus) -> String {
        switch status { case .pending: "Waiting"; case .sent: "Recorded"; case .replied: "Demo reply"; case .cancelled: "Cancelled" }
    }
}

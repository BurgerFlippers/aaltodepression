import SwiftUI
import MessageUI

struct EverydaySocialView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var personID = ""
    @State private var activity = "go for a walk"
    @State private var date = Date()
    @State private var draft = ""
    @State private var generated = ""
    @State private var compose = false
    @State private var unavailable = false
    @State private var showPeople = false
    @State private var sent = false
    @State private var failed = false
    @State private var reviewEditedDraft = false
    @State private var demoPreview = false
    private var contacts: [Contact] { presentation.backend.planner.setup.contacts }
    private var selected: Contact? { contacts.first { $0.id == personID } }

    var body: some View {
        NavigationStack {
            Form {
                if contacts.isEmpty {
                    Section {
                        Text("Choose someone you'd like to hear from.")
                        Button("Add someone") { showPeople = true }
                    }
                } else {
                    Section("Who would you like to see?") {
                        Picker("To", selection: $personID) {
                            Text("Choose a person").tag("")
                            ForEach(contacts) { contact in Text(contact.name).tag(contact.id) }
                        }
                    }
                    Section("Start with a message") {
                        Picker("Something to do", selection: $activity) {
                            Text("Walk").tag("go for a walk")
                            Text("Coffee").tag("have a coffee")
                            Text("A meal").tag("eat together")
                        }.pickerStyle(.segmented)
                        DatePicker("When", selection: $date, in: presentation.day.start()..., displayedComponents: .date)
                    }
                    Section {
                        TextEditor(text: $draft).frame(minHeight: 150).accessibilityLabel("Your message")
                        Button("Use the suggested words again") { fillDraft(force: true) }.font(.subheadline)
                    } header: { Text("Make it yours") } footer: {
                        Text("Edit any words you like. Nothing is sent until you send it in Messages.")
                    }
                    if sent { Section { Label("Message sent", systemImage: "checkmark.circle.fill") } }
                }
            }
            .navigationTitle("Send a message").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if !contacts.isEmpty {
                    Button(presentation.backend.isDemo ? "Preview demo message" : "Open in Messages") {
                        if presentation.backend.isDemo { demoPreview = true }
                        else if MessageCompose.canSend { compose = true } else { unavailable = true }
                    }.buttonStyle(EverydayPrimaryButton()).padding(20).background(EverydayStyle.paper)
                        .disabled(selected == nil || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                date = presentation.day.start()
                personID = contacts.first(where: { $0.relation == .friend })?.id ?? contacts.first?.id ?? ""
                fillDraft(force: true)
            }
            .onChange(of: personID) { _, _ in updateSuggestion(); sent = false }
            .onChange(of: activity) { _, _ in updateSuggestion(); sent = false }
            .onChange(of: date) { _, _ in updateSuggestion(); sent = false }
            .sheet(isPresented: $showPeople, onDismiss: { presentation.syncSetup(); personID = contacts.last?.id ?? ""; fillDraft(force: true) }) {
                NavigationStack { EverydayNetworkView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPeople = false } } } }
            }
            .sheet(isPresented: $compose) {
                MessageCompose(recipient: selected?.phone ?? "", body: draft, onResult: { result in
                    if result == .sent {
                        sent = true
                        presentation.backend.planner.mark(presentation.item(for: .connect), .done)
                        let plannedDay = Day(date)
                        let suggestion = SocialSuggestion(id: UUID().uuidString, contact: selected, activity: activity, message: draft, suggestedDay: plannedDay, reason: "Planned by you")
                        presentation.backend.planner.acceptSocial(suggestion)
                        if plannedDay == presentation.day {
                            if let item = presentation.backend.planner.today?.items.first(where: { $0.pillar == .social && $0.id.contains(suggestion.id) }) {
                                // Reaching out counts for Connect; the future meet-up itself is still open.
                                presentation.backend.planner.mark(item, .open)
                            }
                        }
                    } else if result == .failed { failed = true }
                }, onFinish: { compose = false })
            }
            .confirmationDialog("Keep your edited message?", isPresented: $reviewEditedDraft, titleVisibility: .visible) {
                Button("Keep my words", role: .cancel) {}
                Button("Use the updated suggestion") { fillDraft(force: true) }
            } message: { Text("The person, activity or day changed. You can keep your text or start with the new suggestion.") }
            .alert("Demo preview only", isPresented: $demoPreview) { Button("OK", role: .cancel) {} } message: { Text("No message has been sent. Switch to Live data to message your own contacts.") }
            .alert("Messages isn't available", isPresented: $unavailable) { Button("OK", role: .cancel) {} } message: { Text("No message has been sent. You can copy your text and use another messaging app.") }
            .alert("The message wasn't sent", isPresented: $failed) { Button("OK", role: .cancel) {} } message: { Text("Your draft is still here. You can try again.") }
        }
    }
    private func updateSuggestion() {
        if !draft.isEmpty && draft != generated { reviewEditedDraft = true }
        else { fillDraft(force: true) }
    }
    private func fillDraft(force: Bool) {
        guard force || draft.isEmpty || draft == generated else { return }
        let text = MessageTemplates.social(activity: activity, contact: selected, day: Day(date), today: presentation.day)
        generated = text
        draft = text
    }
}

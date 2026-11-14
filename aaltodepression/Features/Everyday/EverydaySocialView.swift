import SwiftUI
import MessageUI

/// Contact first. Writing assistance is optional and never required to open Messages.
struct EverydaySocialView: View {
    var initialPersonID: String? = nil
    var initialTopic: SupportTopic? = nil
    var prompt: ReachOutPrompt? = nil
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var personID = ""
    @State private var topic: SupportTopic?
    @State private var writingHelp = false
    @State private var draft = ""
    @State private var compose = false
    @State private var unavailable = false
    @State private var failed = false
    @State private var showPeople = false
    @State private var replaceDraft = false
    @State private var generated = ""
    @State private var copied = false
    private var contacts: [Contact] { presentation.backend.planner.setup.contacts }
    private var selected: Contact? { contacts.first { $0.id == personID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("A message can be enough.").font(.title2.bold())
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Who would you like to contact?").font(.headline)
                        if contacts.isEmpty {
                            Button("Add someone") { showPeople = true }.buttonStyle(.bordered)
                        } else {
                            Picker("To", selection: $personID) {
                                Text("Choose a person").tag("")
                                ForEach(contacts) { Text($0.name).tag($0.id) }
                            }.pickerStyle(.menu)
                            Button("Open Messages") { openMessages() }
                                .buttonStyle(EverydayPrimaryButton()).disabled(selected == nil)
                            Text("Messages opens for this person. You take it from there.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(EverydayStyle.mint, in: RoundedRectangle(cornerRadius: 20))
                    if let prompt { Text(prompt.explanation).font(.footnote).foregroundStyle(.secondary) }
                    DisclosureGroup("Help me find the words", isExpanded: $writingHelp) {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("What would you like to say?", selection: $topic) {
                                Text("Just say hello").tag(Optional<SupportTopic>.none)
                                ForEach(SupportTopic.allCases) { Text($0.title).tag(Optional($0)) }
                            }.pickerStyle(.menu)
                            TextEditor(text: $draft).font(.body).frame(minHeight: 130).padding(10).scrollContentBackground(.hidden)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Your message")
                            HStack {
                                Button("Try suggested words") { if draft.isEmpty || draft == generated { useSuggestion() } else { replaceDraft = true } }
                                Spacer()
                                Button(copied ? "Copied" : "Copy text") { UIPasteboard.general.string = draft; copied = true }
                            }.font(.subheadline)
                            Button("Review draft in Messages") {
                                if MessageCompose.canSend { compose = true } else { unavailable = true }
                            }.buttonStyle(EverydayPrimaryButton()).disabled(selected == nil || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Text("You can change every word. Nothing is sent until you send it in Messages.").font(.footnote).foregroundStyle(.secondary)
                        }.padding(.top, 16)
                    }.font(.headline).padding(18).background(EverydayStyle.peach, in: RoundedRectangle(cornerRadius: 20))
                }.padding(20)
            }.background(EverydayStyle.paper)
                .navigationTitle("Reach out").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear {
                    if personID.isEmpty {
                        personID = initialPersonID ?? contacts.first(where: { $0.relation == .friend })?.id ?? contacts.first?.id ?? ""
                        topic = initialTopic
                        useSuggestion()
                    }
                }
                .onChange(of: personID) { _, _ in refreshSuggestionIfUnedited() }
                .onChange(of: topic) { _, _ in refreshSuggestionIfUnedited() }
                .onChange(of: draft) { _, _ in copied = false }
                .sheet(isPresented: $showPeople, onDismiss: { presentation.syncSetup(); personID = contacts.last?.id ?? "" }) {
                    NavigationStack { EverydayNetworkView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPeople = false } } } }
                }
                .sheet(isPresented: $compose) {
                    MessageCompose(recipient: selected?.phone ?? "", body: draft, onResult: { result in
                        if result == .failed { failed = true }
                        if result == .sent { if let prompt { presentation.backend.planner.dismissReachOutPrompt(prompt) }; dismiss() }
                    }, onFinish: { compose = false })
                }
                .confirmationDialog("Replace your draft with suggested words?", isPresented: $replaceDraft, titleVisibility: .visible) {
                    Button("Use suggestion") { useSuggestion() }
                    Button("Keep my words", role: .cancel) {}
                }
                .alert("Messages couldn't be opened", isPresented: $unavailable) { Button("OK", role: .cancel) {} } message: { Text("No message has been sent. You can copy the text and use another messaging app.") }
                .alert("The message wasn't sent", isPresented: $failed) { Button("OK", role: .cancel) {} } message: { Text("Your draft is still here.") }
        }
    }
    private func openMessages() {
        guard let selected else { return }
        let number = selected.phone.filter { $0.isNumber || $0 == "+" }
        guard !number.isEmpty, let url = URL(string: "sms:\(number)") else { unavailable = true; return }
        openURL(url) { opened in
            if opened {
                if let prompt { presentation.backend.planner.dismissReachOutPrompt(prompt) }
                // Opening another app is not evidence that a message was sent or a task completed.
                dismiss()
            } else { unavailable = true }
        }
    }
    private func refreshSuggestionIfUnedited() {
        if draft.isEmpty || draft == generated { useSuggestion() }
    }
    private func useSuggestion() {
        generated = MessageTemplates.reachOut(topic, contact: selected)
        draft = generated
    }
}

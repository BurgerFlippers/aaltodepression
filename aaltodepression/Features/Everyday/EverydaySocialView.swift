import SwiftUI
import MessageUI

/// One recipient and one clear next action. Writing help stays optional.
struct EverydaySocialView: View {
    var initialPersonID: String? = nil
    var initialTopic: SupportTopic? = nil
    var prompt: ReachOutPrompt? = nil
    var sidequest: Sidequest? = nil
    var smallerQuest = false
    var testMessage: String? = nil
    var onSent: (() -> Void)? = nil
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var personID = ""
    @State private var topic: SupportTopic?
    @State private var writingHelp = false
    @State private var draft = ""
    @State private var generated = ""
    @State private var compose = false
    @State private var composeBody = ""
    @State private var unavailable = false
    @State private var failed = false
    @State private var showPeople = false
    @State private var replaceDraft = false
    @State private var copied = false
    private var contacts: [Contact] {
        presentation.backend.planner.setup.contacts.filter {
            !ContactIntake.normalized($0.phone).isEmpty && (testMessage == nil || $0.id == initialPersonID)
        }
    }
    private var selected: Contact? { contacts.first { $0.id == personID } }
    private var inviting: Bool { sidequest?.canInvite == true && prompt == nil && initialTopic == nil }
    private var people: [Contact] {
        let ordered = contacts.sorted { a, b in
            let aPreferred = inviting ? a.relation == .friend : a.id == initialPersonID
            let bPreferred = inviting ? b.relation == .friend : b.id == initialPersonID
            if aPreferred != bPreferred { return aPreferred }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        var visible = Array(ordered.prefix(3))
        if let selected, !visible.contains(where: { $0.id == selected.id }) {
            if visible.count == 3 { visible.removeLast() }
            visible.append(selected)
        }
        return visible
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if testMessage != nil {
                        Text("Test the SMS flow").font(.title2.bold())
                        Text("One test message from this iPhone. Nothing is sent until you tap Send in Messages.").font(.subheadline).foregroundStyle(.secondary)
                    } else if inviting, let sidequest {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("A little company for this?").font(.title2.bold())
                            Text((smallerQuest ? sidequest.smaller : sidequest.regular).title).font(.body)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(BesideQuestStyle.color(sidequest.category), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        Text(prompt?.title ?? "Who would you like to hear from?").font(.title2.bold())
                        if let prompt { Text(prompt.explanation).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your people").font(.headline)
                        if contacts.isEmpty {
                            Text("Choose someone you know. You can message them in your usual way.").font(.subheadline).foregroundStyle(.secondary)
                            Button("Add someone", systemImage: "person.badge.plus") { showPeople = true }
                                .buttonStyle(EverydayPrimaryButton())
                        } else {
                            ForEach(people) { person in
                                Button { personID = person.id } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(person.name).font(.headline)
                                            Text(person.relation == .friend ? "Friend" : "Close person").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: person.id == personID ? "checkmark.circle.fill" : "circle").font(.title2)
                                    }.padding(18).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                                        .background(person.id == personID ? EverydayStyle.mint : EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }.buttonStyle(.plain).accessibilityValue(person.id == personID ? "Selected" : "")
                            }
                            if contacts.count > 3 {
                                Picker("More people", selection: $personID) {
                                    Text("Choose a person").tag("")
                                    ForEach(contacts) { Text($0.name).tag($0.id) }
                                }.pickerStyle(.menu).frame(minHeight: 44)
                            }
                        }
                    }
                    if selected != nil {
                        if inviting || testMessage != nil {
                            Text(draft).font(.body).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            Button(testMessage == nil ? "Review invite to \(selected?.name ?? "friend")" : "Review test to \(selected?.name ?? "Konsta")") { review(draft) }
                                .buttonStyle(EverydayPrimaryButton())
                            Text("You review and send it in Messages.").font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Button("Message \(selected?.name ?? "someone")") { openMessages() }
                                .buttonStyle(EverydayPrimaryButton())
                        }
                        DisclosureGroup(inviting ? "Change the words" : "Help me write it", isExpanded: $writingHelp) {
                            VStack(alignment: .leading, spacing: 14) {
                                if !inviting {
                                    Picker("What would help?", selection: $topic) {
                                        Text("Just say hello").tag(Optional<SupportTopic>.none)
                                        ForEach(SupportTopic.allCases) { Text($0.title).tag(Optional($0)) }
                                    }.pickerStyle(.menu)
                                }
                                TextEditor(text: $draft).frame(minHeight: 110).padding(10).scrollContentBackground(.hidden)
                                    .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).accessibilityLabel("Your message")
                                HStack {
                                    Button("Use suggested words") {
                                        if draft.isEmpty || draft == generated { useSuggestion() } else { replaceDraft = true }
                                    }
                                    Spacer()
                                    Button(copied ? "Copied" : "Copy") { UIPasteboard.general.string = draft; copied = true }
                                }.font(.subheadline)
                                Button("Review message") { review(draft) }.buttonStyle(.borderedProminent).tint(EverydayStyle.action).foregroundStyle(.white)
                                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }.padding(.top, 14)
                        }.font(.headline).padding(18).background(EverydayStyle.peach, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }.padding(20)
            }.background(EverydayStyle.paper)
                .navigationTitle(inviting ? "Invite someone" : "Reach out").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear {
                    if personID.isEmpty {
                        personID = initialPersonID.flatMap { id in contacts.first { $0.id == id }?.id } ?? people.first?.id ?? ""
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
                    MessageCompose(recipient: selected?.phone ?? "", body: composeBody, onResult: { result in
                        if result == .failed { failed = true }
                        if result == .sent { onSent?(); if let prompt { presentation.backend.planner.dismissReachOutPrompt(prompt) }; dismiss() }
                    }, onFinish: { compose = false })
                }
                .confirmationDialog("Replace your draft?", isPresented: $replaceDraft, titleVisibility: .visible) {
                    Button("Use suggested words") { useSuggestion() }
                    Button("Keep my words", role: .cancel) {}
                }
                .alert("Messages isn't available", isPresented: $unavailable) {
                    Button("Copy message") { UIPasteboard.general.string = draft; copied = true }
                    Button("OK", role: .cancel) {}
                } message: { Text("Nothing was sent. You can copy the message and use your usual messaging app.") }
                .alert("The message wasn't sent", isPresented: $failed) { Button("OK", role: .cancel) {} } message: { Text("Your draft is still here.") }
        }
    }

    private func review(_ text: String) {
        guard selected != nil else { return }
        composeBody = text
        if MessageCompose.canSend { compose = true } else { unavailable = true }
    }

    private func openMessages() {
        guard let selected else { return }
        let number = selected.phone.filter { $0.isNumber || $0 == "+" }
        guard !number.isEmpty, let url = URL(string: "sms:\(number)") else { unavailable = true; return }
        openURL(url) { opened in
            if opened { dismiss() } else { unavailable = true }
        }
    }

    private func refreshSuggestionIfUnedited() {
        if draft.isEmpty || draft == generated { useSuggestion() }
    }

    private func useSuggestion() {
        generated = testMessage ?? (inviting ? sidequest!.invitation : MessageTemplates.reachOut(topic, contact: selected))
        draft = generated
    }
}

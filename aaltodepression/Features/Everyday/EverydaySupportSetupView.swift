import SwiftUI

struct EverydaySupportSetupFields: View {
    @Environment(BesidePresentation.self) private var presentation
    @State private var preferences = SupportPreferences()
    @State private var agreement = false
    @State private var automaticDetails = false
    @State private var saved = false
    private var contacts: [Contact] { presentation.backend.planner.setup.contacts }
    private var selected: Contact? { contacts.first { $0.id == preferences.personID } }
    private var canSave: Bool { selected != nil && !preferences.topics.isEmpty && (!preferences.automaticDemo || agreement) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose practical support you would welcome. Mind first helps you reach out yourself.").foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(SupportTopic.allCases) { topic in
                    Toggle(topic.title, isOn: Binding(get: { preferences.topics.contains(topic) }, set: { enabled in
                        if enabled { preferences.topics.insert(topic) } else { preferences.topics.remove(topic) }
                        saved = false; agreement = false
                    })).padding(16)
                    if topic != SupportTopic.allCases.last { Divider().padding(.horizontal, 16) }
                }
            }.tint(EverydayStyle.ink).background(EverydayStyle.mint, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 12) {
                Text("Who could help?").font(.headline)
                if contacts.isEmpty { Text("Add someone in Your people first.").foregroundStyle(.secondary) }
                else {
                    Picker("Your person", selection: $preferences.personID) {
                        Text("Choose someone").tag("")
                        ForEach(contacts) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.menu)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            DisclosureGroup("Automatic support (optional demo)", isExpanded: $automaticDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A separate demo shows an agreed practical request being recorded for your person. It never delivers a real message.").font(.subheadline).foregroundStyle(.secondary)
                    Toggle("Allow the automatic-message demo", isOn: $preferences.automaticDemo)
                    if preferences.automaticDemo {
                        Toggle("I've agreed these kinds of support requests with this person.", isOn: $agreement)
                        Text("Only the practical request is included. Your Health readings and check-in answers are not shared.").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(.top, 14)
            }.padding(18).background(EverydayStyle.lavender, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            Button("Save choices") {
                presentation.saveSupportPreferences(preferences, contactAgreed: agreement)
                saved = true
            }.buttonStyle(EverydayPrimaryButton()).disabled(!canSave).accessibilityIdentifier("support-save-preferences")
            if saved { Label("Choices saved", systemImage: "checkmark.circle").font(.subheadline) }
        }
        .onAppear {
            preferences = presentation.backend.planner.setup.supportPreferences ?? SupportPreferences()
            if preferences.personID.isEmpty { preferences.personID = contacts.first(where: { $0.relation != .friend })?.id ?? contacts.first?.id ?? "" }
            agreement = selected?.agreed == true
        }
        .onChange(of: preferences.personID) { _, _ in agreement = false; saved = false }
        .onChange(of: preferences.automaticDemo) { _, _ in saved = false }
    }
}

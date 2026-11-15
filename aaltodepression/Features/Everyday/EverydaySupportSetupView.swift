import SwiftUI

/// Practical support, one helper per topic. Every change is saved straight away.
struct EverydaySupportSetupFields: View {
    @Environment(BesidePresentation.self) private var presentation
    @State private var preferences = SupportPreferences()
    @State private var loaded = false
    private var contacts: [Contact] { presentation.liveBackend.planner.setup.contacts }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose practical support you would welcome. MindMaintainer first helps you reach out yourself. With Automatic support on, it can also ask your chosen person for you when your days look harder.")
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(SupportTopic.allCases) { topic in
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(topic.title, isOn: Binding(get: { preferences.topics.contains(topic) }, set: { enabled in
                            if enabled { preferences.topics.insert(topic) } else { preferences.topics.remove(topic) }
                        }))
                        if preferences.topics.contains(topic), !contacts.isEmpty {
                            HStack {
                                Text("Who could help").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Picker("Who could help with \(topic.title.lowercased())", selection: person(for: topic)) {
                                    ForEach(contacts) { Text($0.name).tag($0.id) }
                                }.pickerStyle(.menu)
                            }
                        }
                    }.padding(16)
                    if topic != SupportTopic.allCases.last { Divider().padding(.horizontal, 16) }
                }
                if contacts.isEmpty {
                    Divider().padding(.horizontal, 16)
                    Text("Add someone in Your people first to choose who could help.").font(.subheadline).foregroundStyle(.secondary)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.tint(EverydayStyle.accent).background(EverydayStyle.mint, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 12) {
                Text("Automatic support").font(.headline)
                Toggle("Automatic support", isOn: $preferences.automaticDemo).tint(EverydayStyle.accent)
                Text("Only the practical request is included. Your Health readings and check-in answers are not shared.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(EverydayStyle.lavender, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
        }
        .onAppear {
            // People added in the previous onboarding step live in the profile store until synced.
            presentation.syncSetup()
            let saved = presentation.liveBackend.planner.setup.supportPreferences
            preferences = saved ?? SupportPreferences(automaticDemo: true)
            fillDefaultPeople()
            loaded = true
            save()
        }
        .onChange(of: preferences) { _, _ in if loaded { save() } }
        // On the You page people can change while this section is open.
        .onChange(of: contacts.map(\.id)) { _, _ in if loaded { fillDefaultPeople() } }
    }

    private func person(for topic: SupportTopic) -> Binding<String> {
        Binding(get: { preferences.person(for: topic) }, set: {
            preferences.topicPeople[topic.rawValue] = $0
            preferences.pickedTopics.insert(topic.rawValue)
        })
    }

    /// Practical topics default to a random loved one, Social contact to the first friend; otherwise anyone available.
    /// Re-run on every visit, so defaults follow people added or changed since. Picked topics stay as chosen.
    private func fillDefaultPeople() {
        guard !contacts.isEmpty else { return }
        let lovedOnes = contacts.filter { $0.relation != .friend }
        let friends = contacts.filter { $0.relation == .friend }
        // One random loved one for all practical topics, unless one is already helping with them.
        let practical = SupportTopic.allCases.filter { $0 != .social }
        let lovedOne = practical.lazy.compactMap { topic in lovedOnes.first { $0.id == preferences.topicPeople[topic.rawValue] } }.first
            ?? lovedOnes.randomElement()
        for topic in SupportTopic.allCases {
            let current = contacts.first { $0.id == preferences.topicPeople[topic.rawValue] }
            if preferences.pickedTopics.contains(topic.rawValue), current != nil { continue }
            let chosen: Contact?
            if topic == .social { chosen = friends.first ?? current ?? contacts.first }
            else if let current, current.relation != .friend { chosen = current }   // keep an earlier random loved one
            else { chosen = lovedOne ?? current ?? contacts.first }
            preferences.topicPeople[topic.rawValue] = chosen?.id
            preferences.pickedTopics.remove(topic.rawValue)
        }
        preferences.personID = preferences.person(for: .groceries)
    }

    private func save() {
        presentation.saveSupportPreferences(preferences, contactAgreed: preferences.automaticDemo)
    }
}

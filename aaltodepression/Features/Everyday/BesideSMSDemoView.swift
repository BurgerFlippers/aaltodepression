import SwiftUI
import Contacts

/// The SMS demo. Set up once in the triple-tap demo menu (a contact and the person's own "Mind Demo SMS"
/// Apple Shortcut); then "Send SMS demo" on Trends runs the shortcut straight away. The shortcut gets the
/// number and a generic message as text, never Health data. iOS may show Shortcuts briefly while it runs.
@MainActor enum BesideSMSDemo {
    static let nameKey = "mind.demo.sms.contactName"
    static let phoneKey = "mind.demo.sms.contactPhone"
    static let readyKey = "mind.demo.shortcutConfigured.v1"

    static func message(contactName: String, userName: String) -> String {
        let contact = contactName.split(separator: " ").first.map(String.init) ?? contactName
        let user = userName.split(separator: " ").first.map(String.init) ?? ""
        let who = user.isEmpty ? "your friend" : user
        return "Hi \(contact), it would be good to give \(who) a call today. (MindMaintainer demo)"
    }

    /// The latest shortcut result, only for a run in the last ten minutes.
    static func recentStatus(_ presentation: BesidePresentation) -> String? {
        let sender = presentation.demoShortcutSender
        guard let run = sender.run, Date().timeIntervalSince(run.startedAt) < 600 else { return nil }
        return sender.statusText
    }

    /// Why sending is not possible yet, or nil when it is.
    static func blocker(_ presentation: BesidePresentation) -> String? {
        let defaults = UserDefaults.standard
        if (defaults.string(forKey: phoneKey) ?? "").isEmpty { return "Choose a contact in the demo menu (triple-tap Trends)." }
        if !defaults.bool(forKey: readyKey) { return "Set up the Mind Demo SMS shortcut in the demo menu (triple-tap Trends)." }
        if presentation.demoShortcutSender.coolingDown { return "Just sent. Try again in a few seconds." }
        return nil
    }

    /// Runs the shortcut with the saved contact. Returns false when it could not start.
    @discardableResult static func send(_ presentation: BesidePresentation, openURL: OpenURLAction) -> Bool {
        let defaults = UserDefaults.standard
        guard blocker(presentation) == nil,
              let name = defaults.string(forKey: nameKey), let phone = defaults.string(forKey: phoneKey) else { return false }
        let sender = presentation.demoShortcutSender
        let text = phone + "\n" + message(contactName: name, userName: presentation.profileStore.state.profile.name)
        guard let url = sender.begin(requestID: "sms-demo", day: presentation.day, text: text), let run = sender.run else { return false }
        openURL(url) { opened in sender.didOpen(id: run.id, opened: opened) }
        return true
    }
}

/// Setup in the triple-tap demo menu: the contact, the message preview, shortcut steps and a test send.
struct BesideSMSDemoSection: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.openURL) private var openURL
    @AppStorage(BesideSMSDemo.nameKey) private var contactName = ""
    @AppStorage(BesideSMSDemo.phoneKey) private var contactPhone = ""
    @AppStorage(BesideSMSDemo.readyKey) private var shortcutReady = false
    @State private var picking = false
    @State private var showSetup = false

    var body: some View {
        Section {
            Button { picking = true } label: {
                LabeledContent("Send to", value: contactName.isEmpty ? "Choose a contact" : "\(contactName) · \(contactPhone)")
            }.accessibilityIdentifier("sms-demo-contact")
            // The same Apple contact picker as onboarding. Attached to this row: a sheet on a Form Section
            // is applied to every row and does not present.
            .sheet(isPresented: $picking) {
                EverydayContactPicker { contact in
                    let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    if let phone = contact.phoneNumbers.first?.value.stringValue {
                        contactPhone = phone
                        contactName = name.isEmpty ? phone : name
                    }
                    picking = false
                } onCancel: { picking = false }
            }
            if !contactName.isEmpty {
                Text(BesideSMSDemo.message(contactName: contactName, userName: presentation.profileStore.state.profile.name))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            DisclosureGroup("Shortcut setup (once)", isExpanded: $showSetup) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. In Shortcuts, tap + and name the shortcut Mind Demo SMS.")
                    Text("2. Add Split Text. Tap its text and choose Shortcut Input. Split by New Lines.")
                    Text("3. Add Get Item from List: First Item. Add it again: Last Item.")
                    Text("4. Add Send Message. Message: the Last Item. Recipient: the First Item.")
                    Text("5. In Send Message, turn off Show When Run.")
                    Text("6. Come back, turn on the switch below and tap Send a test. Allow the permission once.")
                    Button("Open Shortcuts") { if let url = URL(string: "shortcuts://") { openURL(url) } }
                }.font(.subheadline).padding(.vertical, 8)
            }
            .onAppear { showSetup = !shortcutReady }
            Toggle("Mind Demo SMS shortcut is set up", isOn: $shortcutReady)
                .accessibilityIdentifier("demo-shortcut-ready")
            Button("Send a test") { BesideSMSDemo.send(presentation, openURL: openURL) }
                .disabled(BesideSMSDemo.blocker(presentation) != nil)
                .accessibilityIdentifier("sms-demo-test")
            if let status = presentation.demoShortcutSender.statusText {
                Text(status).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("demo-sms-result")
            }
        } header: { Text("SMS demo") } footer: {
            Text("On Trends, choose A harder stretch and tap Send SMS demo. The message goes through your shortcut; Shortcuts may show for a moment. A finished shortcut does not confirm delivery.")
        }
    }
}

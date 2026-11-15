import SwiftUI

/// The message test: a support signal runs the person's own "Mind Demo SMS" Apple Shortcut.
/// Used by the Trends "SMS demo" button and by the advanced demo controls.
struct BesideSMSDemoSection: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.openURL) private var openURL
    @AppStorage("mind.demo.shortcutConfigured.v1") private var shortcutReady = false
    @State private var armed = false
    @State private var request: OutgoingMessage?
    @State private var showSetup = false
    private var sender: DemoShortcutSender { presentation.demoShortcutSender }
    private var konsta: Contact? {
        presentation.liveBackend.planner.setup.contacts.first {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .split(whereSeparator: { $0.isWhitespace }).contains("konsta") && !ContactIntake.normalized($0.phone).isEmpty
        }
    }
    private var signalReached: Bool {
        guard presentation.quickScenario != nil || presentation.demoLoad != nil,
              let step = presentation.healthSignal?.step else { return false }
        return step != .steady
    }

    var body: some View {
        Section {
            LabeledContent("To", value: konsta?.name ?? "Add Konsta in Your people")
            Toggle("Send a demo text automatically", isOn: $armed)
                .disabled(konsta == nil || !shortcutReady || sender.coolingDown || request != nil)
                .accessibilityIdentifier("demo-arm-sms")
            Label(signalReached ? "Support signal detected" : "Waiting for a support signal", systemImage: "waveform.path")
                .accessibilityIdentifier("demo-signal-state")
            Text(request == nil ? "No request started" : "Request handed to Shortcuts")
                .accessibilityIdentifier("demo-request-state")
            if let status = sender.statusText {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Latest shortcut result").font(.caption).foregroundStyle(.secondary)
                    Text(status).font(.subheadline)
                }.accessibilityIdentifier("demo-sms-result")
            }
            if sender.coolingDown { Text("One attempt per five minutes. Reset does not remove this limit.").font(.caption).foregroundStyle(.secondary) }
            DisclosureGroup("One-time iPhone setup", isExpanded: $showSetup) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. In Shortcuts, create a shortcut named Mind Demo SMS.")
                    Text("2. Add Apple's Send Message action. Choose Konsta and the same number saved in MindMaintainer.")
                    Text("3. Use this fixed message:")
                    Text("Mind DEMO TEST: automatic support signal reached. No action needed.").textSelection(.enabled)
                    Text("4. Turn off Show When Run / Show Compose Sheet in that action. Allow the first iOS permission yourself.")
                    Text("The shortcut must contain only that fixed test message and recipient. It receives no Health data or phone number from MindMaintainer.")
                    Button("Open Shortcuts") { if let url = URL(string: "shortcuts://") { openURL(url) } }
                    Toggle("Mind Demo SMS is configured for Konsta", isOn: $shortcutReady)
                        .accessibilityIdentifier("demo-shortcut-ready")
                }.font(.subheadline).padding(.vertical, 10)
            }
        } header: { Text("Message test · your iPhone") } footer: {
            Text("Once set up, a support signal runs the shortcut without a Messages Send button. Shortcuts may open and iOS may request a first-run permission. A completed shortcut does not verify message delivery.")
        }
        .onAppear { showSetup = !shortcutReady }
        .onChange(of: shortcutReady) { _, ready in if !ready { armed = false } }
        .onChange(of: armed) { _, enabled in
            presentation.setDemoRecipient(enabled ? konsta?.id : nil)
            if enabled { sendIfNeeded() }
        }
        // A new scenario may reach the signal; a reset clears the request.
        .onChange(of: presentation.demoLoad) { _, load in
            if load == nil && presentation.quickScenario == nil { armed = false; request = nil } else { sendIfNeeded() }
        }
        .onChange(of: presentation.quickScenario) { _, scenario in
            if scenario == nil && presentation.demoLoad == nil { armed = false; request = nil } else { sendIfNeeded() }
        }
    }

    private func sendIfNeeded() {
        guard armed, shortcutReady, konsta != nil, !sender.coolingDown, request == nil,
              let prepared = presentation.prepareDemoSMS(),
              let url = sender.begin(requestID: prepared.id, day: presentation.day), let run = sender.run else { return }
        request = prepared
        armed = false
        openURL(url) { opened in sender.didOpen(id: run.id, opened: opened) }
    }
}

/// Trends "Send SMS demo" button, shown with the A harder stretch demo data (a support signal is reached).
struct BesideSMSDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form { BesideSMSDemoSection() }
                .navigationTitle("Send SMS demo").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

import SwiftUI
import MessageUI

/// A deliberately armed, foreground test. MessageUI still owns the real Send action.
struct BesideDemoScenarioView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @AppStorage("beside.demo.sms.lastSent") private var lastSent = 0.0
    @State private var load = 0.0
    @State private var recipientID = ""
    @State private var armed = false
    @State private var request: OutgoingMessage?
    @State private var compose = false
    @State private var result: String?
    @State private var showReadings = false
    private var contacts: [Contact] { presentation.liveBackend.planner.setup.contacts.filter { !ContactIntake.normalized($0.phone).isEmpty } }
    private var recipient: Contact? { contacts.first { $0.id == recipientID } }
    private var coolingDown: Bool { Date().timeIntervalSince1970 - lastSent < 300 }
    private var bodyText: String { "Mind DEMO TEST — no action needed. " + (request?.text ?? "") }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Demo balance", value: presentation.healthSignal?.result.steadiness.map { "\(Int($0.rounded())) / 100" } ?? "Learning your usual")
                    Text(presentation.balanceTitle).font(.subheadline).foregroundStyle(EverydayStyle.accent)
                    Slider(value: $load, in: 0...1, step: 0.05) { Text("Demo difficulty") } onEditingChanged: { editing in
                        if !editing { apply() }
                    }.accessibilityIdentifier("demo-load-slider")
                    HStack { Text("Steady days"); Spacer(); Text("Harder days") }.font(.caption).foregroundStyle(.secondary)
                    LabeledContent("Scenario", value: load >= 0.8 ? "18 changed days" : "7 changed days")
                    Button("Apply scenario") { apply() }.accessibilityIdentifier("demo-apply-scenario")
                } header: { Text("Demo controls") } footer: { Text("Simulated sleep, movement and daylight run through the existing scoring rules. Apple Health and live records stay unchanged.") }
                Section {
                    if contacts.isEmpty { Text("Add a test contact in You → Your people first.") }
                    else {
                        Picker("Test recipient", selection: $recipientID) {
                            ForEach(contacts) { Text($0.name).tag($0.id) }
                        }.disabled(request != nil)
                        Toggle("Prepare a test request automatically", isOn: $armed).disabled(recipient == nil || coolingDown)
                            .accessibilityIdentifier("demo-arm-sms")
                    }
                    Label(presentation.healthSignal?.step == .steady || presentation.demoLoad == nil ? "Waiting for a support signal" : "Support signal detected", systemImage: "waveform.path")
                        .accessibilityIdentifier("demo-signal-state")
                    Label(request == nil ? "No request prepared" : "Request prepared for \(request!.contactName)", systemImage: request == nil ? "circle" : "checkmark.circle")
                        .accessibilityIdentifier("demo-request-state")
                    if let request {
                        Text(request.status == .pending ? "Prepared · not sent" : "Submitted to Messages")
                            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("demo-transport-state")
                        Text(bodyText).font(.subheadline).textSelection(.enabled)
                        if request.status == .pending {
                            Button("Review test message", systemImage: "message") { openMessages() }
                                .disabled(coolingDown || !MessageCompose.canSend)
                        }
                        Text("Request ID: \(request.id)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let result { Text(result).font(.subheadline).foregroundStyle(EverydayStyle.accent).accessibilityIdentifier("demo-sms-result") }
                    if coolingDown { Text("A test was recently submitted. Wait five minutes before another send.").font(.caption).foregroundStyle(.secondary) }
                    if !MessageCompose.canSend { Text("SMS review is available on an iPhone with Messages enabled.").font(.caption).foregroundStyle(.secondary) }
                } header: { Text("Message test") } footer: {
                    Text("Arming agrees to this foreground demo test only. Crossing the support threshold prepares one request and opens Messages. Tap Send there. Background SMS delivery is not connected; delivery is not verified by this app.")
                }
                Section {
                    Button("Fine-tune individual readings", systemImage: "slider.horizontal.3") { showReadings = true }
                    LabeledContent("Support stage", value: stage)
                    LabeledContent("Changed days this week", value: "\(presentation.healthSignal?.driftDaysInLastWeek ?? 0)")
                }
            }.navigationTitle("Demo").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Reset") { reset() }.accessibilityIdentifier("demo-restore") }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                .onAppear {
                    load = presentation.demoLoad ?? 0
                    if presentation.demoLoad == nil { presentation.applyDemoLoad(0) }
                    recipientID = presentation.demoRecipientID ?? contacts.first(where: { $0.name.localizedCaseInsensitiveContains("konsta") })?.id ?? contacts.first?.id ?? ""
                    request = presentation.backend.planner.outbox.first { $0.day == presentation.day && $0.contactID == recipientID && $0.status != .cancelled }
                    if request?.status == .sent { result = "Submitted to Messages. Recipient delivery is not verified." }
                }
                .onChange(of: recipientID) { old, _ in
                    guard !old.isEmpty else { return }
                    armed = false; request = nil; result = nil; presentation.setDemoRecipient(nil)
                }
                .onChange(of: armed) { _, enabled in
                    presentation.setDemoRecipient(enabled ? recipientID : nil)
                    if enabled { prepareIfNeeded() }
                }
                .sheet(isPresented: $showReadings) { BesideDemoControlsView(embeddedInDemo: true) }
                .sheet(isPresented: $compose) {
                    if let recipient, let request {
                        MessageCompose(recipient: recipient.phone, body: bodyText, onResult: { outcome in
                            switch outcome {
                            case .sent:
                                lastSent = Date().timeIntervalSince1970
                                presentation.backend.planner.recordDemoSMSSubmitted(messageID: request.id)
                                var submitted = request
                                submitted.status = .sent
                                self.request = submitted
                                result = "Submitted to Messages. Recipient delivery is not verified."
                                armed = false
                            case .cancelled: result = "Cancelled. Nothing was sent."
                            case .failed: result = "Messages could not send the test. Nothing is marked as sent."
                            @unknown default: result = "Send status unknown. Nothing is marked as sent."
                            }
                        }, onFinish: { compose = false })
                    }
                }
        }
    }
    private var stage: String {
        switch presentation.healthSignal?.step { case .nudge: "Small step / support check"; case .reachOut: "Reach out"; default: "Steady" }
    }
    private func apply() {
        presentation.applyDemoLoad(load)
        prepareIfNeeded()
    }
    private func prepareIfNeeded() {
        guard armed, recipient != nil, !coolingDown, request == nil else { return }
        guard let prepared = presentation.prepareDemoSMS() else { return }
        request = prepared
        result = nil
        openMessages()
    }
    private func openMessages() {
        guard !coolingDown, MessageCompose.canSend, recipient != nil, request != nil else { return }
        compose = true
    }
    private func reset() {
        armed = false; request = nil; result = nil; load = 0
        presentation.resetDemoScenario()
    }
}

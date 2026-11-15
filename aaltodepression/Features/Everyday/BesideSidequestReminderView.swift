import SwiftUI

struct BesideSidequestReminderView: View {
    let day: Day
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var time = Date().addingTimeInterval(30 * 60)
    @State private var saving = false
    @State private var error: String?
    private var earliest: Date { Date().addingTimeInterval(60) }
    private var latest: Date { max(earliest, (day + 1).start().addingTimeInterval(-1)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A gentle reminder, once today.").font(.title2.bold())
                    DatePicker("Remind me", selection: $time, in: earliest...latest, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                    Text("The notification keeps your task and Health details private. Tap it to return to your task.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(saving ? "Saving…" : "Set reminder") { Task { await save() } }
                        .buttonStyle(EverydayPrimaryButton()).disabled(saving)
                    if presentation.sidequest?.reminderAt != nil {
                        Button("Remove reminder", role: .destructive) {
                            Task {
                                saving = true
                                await SidequestReminders.cancel(on: day)
                                _ = presentation.liveBackend.planner.setSidequestReminder(nil, on: day)
                                dismiss()
                            }
                        }.disabled(saving).frame(minHeight: 44)
                    }
                    if let error {
                        Text(error).font(.subheadline)
                        Button("Open notification settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.frame(minHeight: 44)
                    }
                }.padding(24)
            }.background(EverydayStyle.paper)
                .navigationTitle("Remind me").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) } }
                .interactiveDismissDisabled(saving)
                .onAppear {
                    let existing = presentation.sidequest?.reminderAt ?? time
                    time = min(latest, max(earliest, existing))
                }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await SidequestReminders.schedule(on: day, at: time)
            guard presentation.liveBackend.planner.setSidequestReminder(time, on: day) else {
                await SidequestReminders.cancel(on: day)
                error = "This task has changed. Open your current task and try again."
                return
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

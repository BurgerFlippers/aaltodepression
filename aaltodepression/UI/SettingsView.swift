import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle("Demo mode", isOn: Binding(get: { model.isDemo }, set: { model.mode = $0 ? .demo : .real }))
                    if model.isDemo {
                        Stepper(value: $model.demoDay, in: AppModel.demoDays) {
                            LabeledContent("Demo day", value: "\(model.demoDay)")
                        }
                        LabeledContent("Date", value: Format.date(model.scoredDay))
                    }
                } footer: {
                    Text(model.isDemo
                         ? "Shows Perttu, a made-up person: steady until day 44, a cold on days 30–32, a trip on days 38–40, then a slow drift."
                         : "Shows your own data from Apple Health and this phone.")
                }
                if !model.isDemo {
                    Section {
                        Button {
                            Task { await model.readEverything() }
                        } label: {
                            HStack {
                                Text("Read Health data again")
                                Spacer()
                                if model.isReading { ProgressView() }
                            }
                        }
                        .disabled(model.isReading)
                        if let d = model.lastRead {
                            LabeledContent("Last read", value: d.formatted(date: .omitted, time: .shortened))
                        }
                        Button("Allow Health, Motion and Location") { Task { await model.requestPermissions(); await model.readEverything() } }
                    }
                }
                Section {
                    LabeledContent("Nurse", value: model.plan.nurseName)
                    LabeledContent("Friend", value: model.plan.friendName)
                } header: {
                    Text("Your plan")
                } footer: {
                    Text("Usual is a hackathon prototype for Junction 2026. It doesn't diagnose anything, and nothing leaves this phone.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

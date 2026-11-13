import SwiftUI

/// Settings and demo controls, behind the gear on Today.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

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
                         ? "Perttu is made up: steady until day 44, a cold on days 30–32, a trip on days 38–40, then a slow drift. Breathing minutes for today come from your real Apple Watch."
                         : "Shows your own data from Apple Health and this phone.")
                }
                if !model.isDemo {
                    Section {
                        Toggle("Show Steadiness on Today", isOn: $model.showSteadinessSetting)
                    } footer: {
                        Text("The number is always in Days. In the demo it also shows on Today.")
                    }
                }
                Section {
                    Button("Simulate a breathing session") { Task { await model.simulateBreathing() } }
                    Button("Skip to tomorrow") { model.skipToTomorrow() }
                    if let m = model.liveMindfulToday {
                        LabeledContent("Breathing today", value: "\(Int(m)) min")
                    }
                } header: {
                    Text("Stage demo")
                } footer: {
                    Text("Simulate writes a 1-minute mindful session to Apple Health. Skip to tomorrow sends the 12:00 reminder to message \(model.plan.friendName) now.")
                }
                Section {
                    TextField("Phone number", text: $model.friendPhone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                } header: {
                    Text("\(model.plan.friendName)'s number for the demo")
                }
                if !model.isDemo {
                    Section {
                        Button {
                            Task { await model.readEverything() }
                        } label: {
                            HStack { Text("Read Health data again"); Spacer(); if model.isReading { ProgressView() } }
                        }
                        .disabled(model.isReading)
                        if let d = model.lastRead {
                            LabeledContent("Last read", value: d.formatted(date: .omitted, time: .shortened))
                        }
                        Button("Allow Health, Motion, Location, Calendar and Photos") { Task { await model.requestPermissions(); await model.readEverything() } }
                        Button("Share medications from Health") { Task { await model.requestMedicationAccess() } }
                    }
                }
                Section {
                    TextField("https://", text: $model.clinicEndpoint)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    Text("Clinic endpoint (optional)")
                } footer: {
                    Text("When set, Usual sends only the step, Steadiness, its usual, a one-line reason and the actions tried. No raw data, location or message text.")
                }
                Section {
                    LabeledContent("Nurse", value: model.plan.nurseName)
                    LabeledContent("Friend", value: model.plan.friendName)
                } footer: {
                    Text("Usual is a hackathon prototype for Junction 2026. It doesn't diagnose anything.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

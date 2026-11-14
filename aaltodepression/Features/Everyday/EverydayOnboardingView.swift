import SwiftUI

struct EverydayOnboardingView: View {
    @Environment(EverydayStore.self) private var store
    @State private var page = 0
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if page > 0 { ProgressView(value: Double(page), total: 5).tint(EverydayStyle.orange).padding(.horizontal, 24).padding(.top, 12) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch page {
                        case 0:
                            BesideLogoView().frame(width: 116, height: 116).padding(.top, 18)
                            EverydayHeading(eyebrow: "A little support, every day", title: "Your day.\nA little lighter.")
                            Text("Beside prepares the small things, so you can start with just one.").font(.title3).foregroundStyle(EverydayStyle.muted)
                            Text("Set up your support on a good day, so you have someone beside you when things feel harder.").foregroundStyle(EverydayStyle.muted)
                            Label("A couple of minutes to get started", systemImage: "clock").font(.subheadline)
                        case 1:
                            EverydayHeading(eyebrow: "1 of 5 · About you", title: "Let's start with you.")
                            Text("A few basics. You can change these later.").foregroundStyle(EverydayStyle.muted)
                            EverydayProfileFields()
                        case 2:
                            EverydayHeading(eyebrow: "2 of 5 · Your people", title: "Choose your people on a good day.")
                            Text("When you're feeling well, choose the people you can turn to on harder days. Having them ready means you don't have to figure out who to ask when you feel alone.").foregroundStyle(EverydayStyle.muted)
                            Text("A loved one can help with practical things. A friend is there for everyday company.").font(.subheadline).foregroundStyle(EverydayStyle.muted)
                            EverydayContactsEditor()
                        case 3:
                            EverydayHeading(eyebrow: "3 of 5 · Support in advance", title: "Agree on help while things feel easier.")
                            EverydaySupportSetupFields()
                        case 4:
                            EverydayHeading(eyebrow: "4 of 5 · Your rhythm", title: "A day that fits you.")
                            EverydayRoutineFields()
                        default:
                            BesideLogoView().frame(width: 88, height: 88)
                            EverydayHeading(eyebrow: "5 of 5 · Ready", title: "You don't have to do it all.")
                            Text("Mark meals with one tap. Let your iPhone notice movement, and connect sleep if you want to.").foregroundStyle(EverydayStyle.muted)
                            EverydaySensorSettings()
                            EverydayNotice(text: "Only occasional questions about groceries and laundry. Background support is a local demo for now; nothing is sent to your people automatically.")
                        }
                    }.padding(24)
                }.scrollDismissesKeyboard(.interactively)
                VStack(spacing: 8) {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if page < 5 { page += 1 } else { store.state.completedSetup = true; store.refreshDay() }
                    } label: { Text(page == 0 ? "Get started" : page == 5 ? "See my day" : "Continue") }
                        .buttonStyle(EverydayPrimaryButton()).accessibilityIdentifier("setup-next")
                    if page == 1 || page == 2 || page == 3 { Button("I'll do this later") { page += 1 }.font(.subheadline.weight(.semibold)).frame(minHeight: 40) }
                }.padding(.horizontal, 24).padding(.vertical, 12)
            }.background(EverydayStyle.paper)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Beside").font(.title2.bold()) }
                if page > 0 { ToolbarItem(placement: .topBarLeading) { Button { page -= 1 } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous step") } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }.navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EverydayProfileFields: View {
    @Environment(EverydayStore.self) private var store
    @State private var selectedField: ProfileWheelField?
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack {
                Text("First name")
                TextField("Optional", text: $store.state.profile.name).multilineTextAlignment(.trailing).textContentType(.givenName)
            }.padding(16)
            Divider().padding(.leading, 16)
            ForEach(ProfileWheelField.allCases) { field in
                Button { selectedField = field } label: {
                    HStack {
                        Text(field.title)
                        Spacer()
                        Text(value(field)).foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.tertiary)
                    }.padding(16).contentShape(Rectangle())
                }.buttonStyle(.plain)
                if field != .height { Divider().padding(.leading, 16) }
            }
        }.background(.white, in: RoundedRectangle(cornerRadius: 18))
        .sheet(item: $selectedField) { field in
            NavigationStack {
                Picker(field.title, selection: binding(field)) {
                    if field == .gender {
                        ForEach(["Prefer not to say", "Female", "Male", "Other"], id: \.self) { Text($0).tag($0) }
                    } else {
                        Text("Not set").tag("")
                        let current = binding(field).wrappedValue
                        if !current.isEmpty && Int(current) == nil { Text("\(current) \(field.unit)").tag(current) }
                        ForEach(field.range, id: \.self) { value in Text("\(value) \(field.unit)").tag(String(value)) }
                    }
                }.pickerStyle(.wheel).labelsHidden().padding(.horizontal)
                    .navigationTitle(field.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedField = nil } } }
            }.presentationDetents([.medium])
        }
    }
    private func binding(_ field: ProfileWheelField) -> Binding<String> {
        switch field {
        case .gender: Binding(get: { store.state.profile.gender }, set: { store.state.profile.gender = $0 })
        case .age: Binding(get: { store.state.profile.age }, set: { store.state.profile.age = $0 })
        case .weight: Binding(get: { store.state.profile.weight }, set: { store.state.profile.weight = $0 })
        case .height: Binding(get: { store.state.profile.height }, set: { store.state.profile.height = $0 })
        }
    }
    private func value(_ field: ProfileWheelField) -> String {
        let current = binding(field).wrappedValue
        return current.isEmpty ? "Not set" : current + (field.unit.isEmpty ? "" : " \(field.unit)")
    }
}

enum ProfileWheelField: String, CaseIterable, Identifiable {
    case gender, age, weight, height
    var id: String { rawValue }
    var title: String { switch self { case .gender: "Gender"; case .age: "Age"; case .weight: "Weight"; case .height: "Height" } }
    var unit: String { switch self { case .gender: ""; case .age: "years"; case .weight: "kg"; case .height: "cm" } }
    var range: ClosedRange<Int> { switch self { case .gender: 0...0; case .age: 1...120; case .weight: 1...400; case .height: 30...250 } }
}

struct EverydayRoutineFields: View {
    @Environment(EverydayStore.self) private var store
    @State private var timeField: RhythmTimeField?
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            timeRow(.wake)
            Divider().padding(.leading, 16)
            timeRow(.bed)
            Divider().padding(.leading, 16)
            Toggle("Medication reminder", isOn: $store.state.profile.usesMedication).tint(EverydayStyle.orange).padding(16)
            if store.state.profile.usesMedication {
                Divider().padding(.leading, 16)
                timeRow(.medication)
                Text("Follow your own medication instructions. This sets the time shown in your day.").font(.footnote).foregroundStyle(.secondary).padding(16)
            }
        }.background(.white, in: RoundedRectangle(cornerRadius: 18))
        .sheet(item: $timeField) { field in
            NavigationStack {
                DatePicker(field.title, selection: timeBinding(field), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().padding()
                    .navigationTitle(field.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { timeField = nil } } }
            }.presentationDetents([.medium])
        }
    }
    private func timeRow(_ field: RhythmTimeField) -> some View {
        Button { timeField = field } label: {
            HStack { Text(field.title); Spacer(); Text(timeBinding(field).wrappedValue.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_GB")))).foregroundStyle(.secondary); Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.tertiary) }.padding(16).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func timeBinding(_ field: RhythmTimeField) -> Binding<Date> {
        Binding(get: {
            let p = store.state.profile
            let hour = field == .wake ? p.wakeHour : field == .bed ? p.bedtimeHour : p.medicationHour
            let minute = field == .wake ? p.wakeMinute : field == .bed ? p.bedtimeMinute : p.medicationMinute
            return Calendar.current.date(bySettingHour: hour, minute: minute ?? 0, second: 0, of: Date()) ?? Date()
        }, set: { value in
            let c = Calendar.current.dateComponents([.hour, .minute], from: value)
            switch field {
            case .wake: store.state.profile.wakeHour = c.hour ?? 8; store.state.profile.wakeMinute = c.minute
            case .bed: store.state.profile.bedtimeHour = c.hour ?? 22; store.state.profile.bedtimeMinute = c.minute
            case .medication: store.state.profile.medicationHour = c.hour ?? 8; store.state.profile.medicationMinute = c.minute
            }
        })
    }
}

enum RhythmTimeField: String, Identifiable {
    case wake, bed, medication
    var id: String { rawValue }
    var title: String { switch self { case .wake: "Usual wake-up time"; case .bed: "Usual bedtime"; case .medication: "Medication time" } }
}

struct EverydaySensorSettings: View {
    @Environment(EverydayStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("iPhone movement", isOn: Binding(get: { store.state.motionEnabled == true }, set: { enabled in
                if enabled { Task { await store.connectMotion() } } else { store.disconnectMotion() }
            })).tint(EverydayStyle.orange)
            Text("Uses your iPhone steps. You can also mark movement yourself.").font(.footnote).foregroundStyle(.secondary)
            Divider()
            Toggle("Apple Health sleep", isOn: Binding(get: { store.state.healthSleepEnabled == true }, set: { enabled in
                if enabled { Task { await store.connectSleep() } } else { store.disconnectSleep() }
            })).tint(EverydayStyle.orange)
            Text("Uses recorded sleep. Phone inactivity is not treated as sleep.").font(.footnote).foregroundStyle(.secondary)
            if let status = store.sensorStatus { Text(status).font(.footnote).foregroundStyle(EverydayStyle.muted) }
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

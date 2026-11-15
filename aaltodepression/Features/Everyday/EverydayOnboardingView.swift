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
                            Text("Mind prepares the small things, so you can start with just one.").font(.title3).foregroundStyle(EverydayStyle.muted)
                            Text("Set up your support on a good day, so you have someone beside you when things feel harder.").foregroundStyle(EverydayStyle.muted)
                            Label("A couple of minutes to get started", systemImage: "clock").font(.subheadline)
                        case 1:
                            EverydayHeading(eyebrow: "1 of 5 · Your name", title: "What should we call you?")
                            Text("Just your first name. You can change it later.").foregroundStyle(EverydayStyle.muted)
                            EverydayProfileFields()
                        case 2:
                            EverydayHeading(eyebrow: "2 of 5 · Your people", title: "Choose your people on a good day.")
                            Text("When you're feeling well, choose the people you can turn to on harder days. Having them ready means you don't have to figure out who to ask when you feel alone.").foregroundStyle(EverydayStyle.muted)
                            Text("A loved one can help with practical things. A friend is there for everyday company.").font(.subheadline).foregroundStyle(EverydayStyle.muted)
                            EverydayContactsEditor()
                        case 3:
                            EverydayHeading(eyebrow: "3 of 5 · Support in advance", title: "A hand with everyday things.")
                            EverydaySupportSetupFields()
                        case 4:
                            EverydayHeading(eyebrow: "4 of 5 · Your rhythm", title: "A day that fits you.")
                            EverydayRoutineFields()
                        default:
                            BesideLogoView().frame(width: 88, height: 88)
                            EverydayHeading(eyebrow: "5 of 5 · Ready", title: "You don't have to do it all.")
                            Text("Share Apple Health data to guide three daily choices. Tap the challenge that feels right today.").foregroundStyle(EverydayStyle.muted)
                            EverydaySensorSettings()
                            EverydayNotice(text: "Reach out when you need a hand. Automatic support is shown separately in the demo; nothing is delivered automatically.")
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
                ToolbarItem(placement: .principal) { Text("Mind").font(.title2.bold()) }
                if page > 0 { ToolbarItem(placement: .topBarLeading) { Button { page -= 1 } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous step") } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }.navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EverydayProfileFields: View {
    @Environment(EverydayStore.self) private var store
    var body: some View {
        @Bindable var store = store
        HStack {
            Text("First name")
            TextField("Your name", text: $store.state.profile.name)
                .multilineTextAlignment(.trailing).textContentType(.givenName)
        }.padding(16).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
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
        }.background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            let hour = field == .wake ? p.wakeHour : p.bedtimeHour
            let minute = field == .wake ? p.wakeMinute : p.bedtimeMinute
            return Calendar.current.date(bySettingHour: hour, minute: minute ?? 0, second: 0, of: Date()) ?? Date()
        }, set: { value in
            let c = Calendar.current.dateComponents([.hour, .minute], from: value)
            switch field {
            case .wake: store.state.profile.wakeHour = c.hour ?? 8; store.state.profile.wakeMinute = c.minute
            case .bed: store.state.profile.bedtimeHour = c.hour ?? 22; store.state.profile.bedtimeMinute = c.minute
            }
        })
    }
}

enum RhythmTimeField: String, Identifiable {
    case wake, bed
    var id: String { rawValue }
    var title: String { switch self { case .wake: "Usual wake-up time"; case .bed: "Usual bedtime" } }
}

struct EverydaySensorSettings: View {
    @Environment(EverydayStore.self) private var store
    @Environment(BesidePresentation.self) private var presentation
    @State private var connecting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("iPhone movement", isOn: Binding(get: { store.state.motionEnabled == true }, set: { enabled in
                if enabled { Task { await store.connectMotion() } } else { store.disconnectMotion() }
            })).tint(EverydayStyle.orange)
            Text("Optional iPhone steps help guide your daily task choices.").font(.footnote).foregroundStyle(.secondary)
            Divider()
            Button {
                connecting = true
                Task { await presentation.connectHealth(); connecting = false }
            } label: {
                HStack { Text("Connect Apple Health"); Spacer(); if connecting { ProgressView() } else { Image(systemName: "heart.fill") } }
            }.disabled(connecting).frame(minHeight: 44)
            Text("Share sleep, movement, daylight and heart measurements to compare daily changes with your own history. You choose what to share in Apple's permission sheet.").font(.footnote).foregroundStyle(.secondary)
            if let status = presentation.healthStatus { Text(status).font(.footnote).foregroundStyle(.secondary) }
            if let status = store.sensorStatus { Text(status).font(.footnote).foregroundStyle(EverydayStyle.muted) }
        }.padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

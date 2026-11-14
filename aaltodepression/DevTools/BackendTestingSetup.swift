import SwiftUI
import ContactsUI

// TEMPORARY backend testing area (see BackendTestingView.swift).

struct SetupPage: View {
    let lab: BackendLab
    @State private var draft = PlannerSetup(personName: "")
    @State private var loaded = false
    @State private var showPicker = false
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.personName)
            } header: {
                Text("Person")
            } footer: {
                Text("Used in messages to contact people, e.g. \"Could you pick up a few groceries for \(draft.personName.isEmpty ? "…" : draft.personName)?\"")
            }

            Section {
                ForEach($draft.contacts) { $c in
                    NavigationLink { LabContactEditor(contact: $c) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name.isEmpty ? "New contact" : c.name)
                            Text("\(c.relation.title) · \(c.canHelpWith.count) kinds of help · \(ContactIntake.problem(c) ?? "ready")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { draft.contacts.remove(atOffsets: $0) }
                Button("Pick from Contacts") { showPicker = true }
                Button("Add by hand") {
                    draft.contacts.append(Contact(id: UUID().uuidString, name: "", phone: "", relation: .friend,
                                                  canHelpWith: [.call, .inviteToEat], agreed: true))
                }
                Picker("Suggestions to contacts", selection: $draft.helpConsent) {
                    Text("Send right away").tag(HelpConsent.sendRightAway)
                    Text("Ask me each time").tag(HelpConsent.askEachTime)
                }
            } header: {
                Text("Contact people")
            } footer: {
                Text("planner.addContacts / ContactIntake. The picker needs no Contacts permission: the app sees only the people picked. New people wait until they agree.")
            }

            Section("Times") {
                LabClock("Wake-up", minutes: $draft.wakeTime)
                LabClock("Check-in", minutes: $draft.checkInTime)
                LabClock("Bedtime", minutes: $draft.bedtime)
                LabeledContent("Wind-down starts", value: PlanFormat.clock(draft.windDownTime))
            }

            Section {
                HStack {
                    ForEach(1...7, id: \.self) { w in
                        let on = draft.shoppingWeekdays.contains(w)
                        Button(["M", "T", "W", "T", "F", "S", "S"][w - 1]) {
                            if on { draft.shoppingWeekdays.remove(w) } else { draft.shoppingWeekdays.insert(w) }
                        }
                        .buttonStyle(.bordered)
                        .tint(on ? .accentColor : .secondary)
                    }
                }
            } header: {
                Text("Shopping days")
            } footer: {
                Text("On these days the list has a grocery run and the app asks at 17:00 whether the shop happened.")
            }

            Section("Medication") {
                ForEach($draft.medications) { $m in
                    VStack(alignment: .leading) {
                        TextField("Name", text: $m.name)
                        ForEach(m.times.indices, id: \.self) { i in
                            LabClock("Dose \(i + 1)", minutes: Binding(get: { m.times[i] }, set: { m.times[i] = $0 }))
                        }
                        HStack {
                            Button("Add a dose time") { m.times.append(20 * 60) }.font(.caption)
                            if m.times.count > 1 { Button("Remove last") { m.times.removeLast() }.font(.caption) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { draft.medications.remove(atOffsets: $0) }
                Button("Add medication") { draft.medications.append(Medication(id: UUID().uuidString, name: "", times: [8 * 60])) }
            }

            Section("Must-dos") {
                ForEach($draft.chores) { $c in
                    VStack(alignment: .leading) {
                        TextField("Title", text: $c.title)
                        Stepper("Every \(c.everyDays) days", value: $c.everyDays, in: 1...30)
                    }
                }
                .onDelete { draft.chores.remove(atOffsets: $0) }
                Button("Add a must-do") { draft.chores.append(Chore(id: UUID().uuidString, title: "", everyDays: 7)) }
            }

            Section {
                Toggle("Ask about yesterday's phone time", isOn: $draft.asksScreenTime)
            } header: {
                Text("Screen time (bonus)")
            } footer: {
                Text("An optional morning question. Apple doesn't let apps read Screen Time directly.")
            }

            Section("Clinic") {
                TextField("Clinic name", text: $draft.clinicName)
                TextField("Clinic phone", text: $draft.clinicPhone).keyboardType(.phonePad)
            }

            Section("Small things that feel good") {
                ForEach(draft.goodThings.indices, id: \.self) { i in
                    TextField("Something small", text: Binding(get: { draft.goodThings[i] }, set: { draft.goodThings[i] = $0 }))
                }
                .onDelete { draft.goodThings.remove(atOffsets: $0) }
                Button("Add") { draft.goodThings.append("") }
            }

            Section {
                Button(saved ? "Saved" : "Save setup") {
                    draft.contacts.removeAll { $0.name.isEmpty }
                    draft.medications.removeAll { $0.name.isEmpty }
                    draft.chores.removeAll { $0.title.isEmpty }
                    lab.save(draft)
                    saved = true
                }
                .buttonStyle(.borderedProminent)
            } footer: {
                Text(lab.useMyData ? "Saved on this phone and used by My data." : "Kept for the demo until you leave Backend testing.")
            }
        }
        .navigationTitle("Setup")
        .onAppear {
            guard !loaded else { return }
            draft = lab.planner.setup
            if draft.personName.isEmpty { draft.personName = "Me" }
            loaded = true
        }
        .onChange(of: draft) { saved = false }
        .background(LabContactPicker(isPresented: $showPicker) { picked in
            // Same call the frontend uses: ContactIntake skips duplicates and starts people as not agreed.
            ContactIntake.add(picked.map { (name: $0.name, phone: $0.phone) }, to: &draft)
        })
    }
}

struct LabContactEditor: View {
    @Binding var contact: Contact

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $contact.name)
                TextField("Phone", text: $contact.phone).keyboardType(.phonePad)
                Picker("Relation", selection: $contact.relation) {
                    ForEach(Relation.allCases) { Text($0.title).tag($0) }
                }
            }
            Section {
                ForEach(HelpKind.allCases) { k in
                    Toggle(k.title, isOn: Binding(get: { contact.canHelpWith.contains(k) },
                                                  set: { if $0 { contact.canHelpWith.insert(k) } else { contact.canHelpWith.remove(k) } }))
                }
            } header: {
                Text("What they can be asked")
            }
            Section {
                Toggle("Has agreed to get suggestions", isOn: $contact.agreed)
            } footer: {
                Text("A new contact starts as not agreed. In the real app the first message is an invitation.")
            }
        }
        .navigationTitle(contact.name.isEmpty ? "Contact" : contact.name)
    }
}

/// A clock picker bound to minutes after midnight.
struct LabClock: View {
    let title: String
    @Binding var minutes: Int

    init(_ title: String, minutes: Binding<Int>) {
        self.title = title
        self._minutes = minutes
    }

    var body: some View {
        DatePicker(title, selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date() },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0) }),
                   displayedComponents: .hourAndMinute)
    }
}

// MARK: - Contact picker

/// Presents the system contact picker. No Contacts permission: the app gets only the people picked.
struct LabContactPicker: UIViewControllerRepresentable {
    struct Picked: Sendable { let name: String; let phone: String }

    @Binding var isPresented: Bool
    var onPick: ([Picked]) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        DispatchQueue.main.async { host.present(picker, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: LabContactPicker
        init(parent: LabContactPicker) { self.parent = parent }

        nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let picked = contacts.map { c in
                Picked(name: CNContactFormatter.string(from: c, style: .fullName) ?? c.givenName,
                       phone: c.phoneNumbers.first?.value.stringValue ?? "")
            }
            MainActor.assumeIsolated {
                parent.onPick(picked)
                parent.isPresented = false
            }
        }

        nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            MainActor.assumeIsolated { parent.isPresented = false }
        }
    }
}

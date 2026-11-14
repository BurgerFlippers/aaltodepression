import SwiftUI
import Contacts
import ContactsUI

struct EverydayContactsEditor: View {
    @Environment(EverydayStore.self) private var store
    @State private var suggestions: [EverydayPerson] = []
    @State private var loading = false
    @State private var didLoad = false
    @State private var query = ""
    @State private var notice: String?
    @State private var showPicker = false
    @State private var showManual = false
    private var visibleSuggestions: [EverydayPerson] {
        Array(suggestions.filter { person in
            !store.state.people.contains(where: { $0.id == person.id || $0.phone == person.phone })
            && (query.isEmpty || person.name.localizedCaseInsensitiveContains(query))
        }.prefix(query.isEmpty ? 3 : 20))
    }
    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 18) {
            ForEach($store.state.people) { $person in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(.headline)
                        Text(person.phone).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Menu {
                        Picker("Role", selection: $person.role) {
                            ForEach(NetworkRole.allCases) { role in Text(role.title).tag(role) }
                        }
                        Button("Remove person", role: .destructive) { store.state.people.removeAll { $0.id == person.id } }
                    } label: {
                        HStack(spacing: 4) { Text(person.role.title); Image(systemName: "chevron.up.chevron.down").font(.caption2) }
                            .font(.subheadline).frame(minHeight: 44)
                    }.accessibilityLabel("Role for \(person.name): \(person.role.title)")
                }.padding(.vertical, 4)
            }
            HStack {
                Menu {
                    Button("Choose from Contacts") { showPicker = true }
                    Button("Suggest people from Contacts") { Task { await loadSuggestions() } }
                    Button("Enter a number") { showManual = true }
                } label: {
                    Label("Add someone", systemImage: "plus").frame(minHeight: 44)
                }.disabled(loading)
                if loading { ProgressView() }
            }
            if didLoad && !suggestions.isEmpty {
                TextField("Search by name", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Search contacts")
                Text("Suggestions").font(.subheadline.weight(.semibold))
                ForEach(visibleSuggestions) { person in
                    Button { store.addPerson(person) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name).font(.headline)
                                Text(person.role == .close ? "Suggested loved one" : "Choose a role after adding").font(.caption).foregroundStyle(EverydayStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(EverydayStyle.orange)
                        }.padding(.vertical, 7).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            if let notice { Text(notice).font(.footnote).foregroundStyle(EverydayStyle.muted) }
            Text("Only the people you choose are saved.").font(.footnote).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showPicker) {
            EverydayContactPicker { contact in
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                if let phone = contact.phoneNumbers.first?.value.stringValue {
                    store.addPerson(EverydayPerson(id: contact.identifier, name: name.isEmpty ? phone : name, phone: phone,
                                                  role: SupportContactsSource.isFamilyName(name) ? .close : .friend))
                }
                showPicker = false
            } onCancel: { showPicker = false }
        }
        .sheet(isPresented: $showManual) { EverydayManualContactView() }
    }
    private func loadSuggestions() async {
        loading = true
        defer { loading = false }
        do {
            suggestions = try await SupportContactsSource.suggestions()
            didLoad = true
            notice = suggestions.isEmpty ? "No shared contacts found. You can choose a contact or enter a number instead." : nil
        } catch { notice = "Contacts couldn't be loaded. You can still add someone manually." }
    }
}

struct EverydayContactPicker: UIViewControllerRepresentable {
    var onSelect: (CNContact) -> Void
    var onCancel: () -> Void
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: EverydayContactPicker
        init(parent: EverydayContactPicker) { self.parent = parent }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) { parent.onSelect(contact) }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { parent.onCancel() }
    }
}

struct EverydayManualContactView: View {
    @Environment(EverydayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var role: NetworkRole = .close
    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && phone.filter(\.isNumber).count >= 5 }
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact details") {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Phone number", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                }
                Section {
                    Picker("Role", selection: $role) { ForEach(NetworkRole.allCases) { Text($0.title).tag($0) } }
                    Text(role.explanation).font(.footnote)
                }
            }
            .navigationTitle("Add someone").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.addPerson(EverydayPerson(name: name.trimmingCharacters(in: .whitespaces), phone: phone, role: role)); dismiss() }.disabled(!valid)
                }
            }
        }
    }
}

struct EverydayNetworkView: View {
    var body: some View {
        Form {
            Section("Your people") { EverydayContactsEditor() }
        }.navigationTitle("Your people").navigationBarTitleDisplayMode(.inline)
    }
}

struct EverydayBackgroundSupportView: View {
    @Environment(EverydayStore.self) private var store
    var body: some View {
        Form {
            Section { EverydaySupportSetupFields().padding(.vertical, 8) }
            if !store.state.supportDrafts.isEmpty {
                Section {
                    NavigationLink("Earlier demo requests") { EverydaySupportDemoHistoryView() }
                }
            }
        }.navigationTitle("Background support").navigationBarTitleDisplayMode(.inline)
    }
}

struct EverydaySupportDemoHistoryView: View {
    @Environment(EverydayStore.self) private var store
    var body: some View {
        List {
            Section {
                ForEach(store.state.supportDrafts) { draft in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.state.people.first(where: { $0.id == draft.personID })?.name ?? "Removed contact").font(.headline)
                        Text(draft.text).font(.subheadline)
                        Text("Not sent").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            } footer: { Text("These are local prototype drafts. They were not delivered.") }
        }.navigationTitle("Demo history").navigationBarTitleDisplayMode(.inline)
    }
}

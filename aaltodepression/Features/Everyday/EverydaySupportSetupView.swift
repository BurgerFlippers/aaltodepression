import SwiftUI

/// UI-only preference draft. Backend activation and delivery are deliberately not inferred from this form.
struct EverydaySupportSetupFields: View {
    @Environment(EverydayStore.self) private var store
    @AppStorage("beside.support.uiDraft.personID") private var savedPersonID = ""
    @AppStorage("beside.support.uiDraft.groceries") private var savedGroceries = true
    @AppStorage("beside.support.uiDraft.laundry") private var savedLaundry = true
    @State private var personID = ""
    @State private var groceries = true
    @State private var laundry = true
    @State private var agreementChecked = false
    @State private var saved = false

    private var lovedOnes: [EverydayPerson] { store.state.people.filter { $0.role == .close } }
    private var chosenPerson: EverydayPerson? { lovedOnes.first { $0.id == personID } }
    private var canSave: Bool { chosenPerson != nil && (groceries || laundry) && agreementChecked }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Not connected yet", systemImage: "link")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text("Choose how you'd like support to work. These preferences stay on this phone until the support service is connected.")
                .font(.subheadline).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Who can help?").font(.headline)
                if lovedOnes.isEmpty {
                    Text("Add a loved one in Your people first. Friends are kept for everyday company.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Picker("Loved one", selection: $personID) {
                        Text("Choose someone").tag("")
                        ForEach(lovedOnes) { person in Text(person.name).tag(person.id) }
                    }.pickerStyle(.menu)
                    if let person = chosenPerson {
                        Text(person.phone).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Contact method", value: "Text message").font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("When to ask for help").font(.headline)
                Toggle("I need help with groceries", isOn: $groceries)
                Toggle("I need help with laundry", isOn: $laundry)
                Text("A request follows your answer that you need a hand. Skipping a question or leaving the app closed doesn't trigger a request.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.tint(EverydayStyle.orange)

            VStack(alignment: .leading, spacing: 10) {
                Text("What they would receive").font(.headline)
                Text(exampleMessage).font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(EverydayStyle.paper, in: RoundedRectangle(cornerRadius: 14))
                Text("Example only. Your name and the practical help needed are included. Health data and your other answers are not shared.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Toggle(isOn: $agreementChecked) {
                Text("I agree that Beside may automatically ask this loved one for help in the situations I choose.")
                    .font(.subheadline)
            }.tint(EverydayStyle.orange)
            Text("You can change or pause this agreement later. Saving here does not activate message delivery yet.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Save preferences") {
                savedPersonID = personID
                savedGroceries = groceries
                savedLaundry = laundry
                saved = true
            }.buttonStyle(.borderedProminent).foregroundStyle(.white).controlSize(.large)
                .disabled(!canSave).accessibilityIdentifier("support-save-preferences")
            if saved {
                Label("Preferences saved on this phone. No messages are being sent.", systemImage: "checkmark.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            personID = lovedOnes.contains(where: { $0.id == savedPersonID }) ? savedPersonID : ""
            groceries = savedGroceries
            laundry = savedLaundry
        }
        .onChange(of: personID) { _, _ in invalidateReview() }
        .onChange(of: groceries) { _, _ in invalidateReview() }
        .onChange(of: laundry) { _, _ in invalidateReview() }
        .onChange(of: store.state.people) { _, _ in
            if chosenPerson == nil { personID = "" }
            invalidateReview()
        }
    }

    private var exampleMessage: String {
        let name = store.state.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let person = name.isEmpty ? "Your person" : name
        if groceries { return "Beside: \(person) could use a hand with groceries. Could you check in or suggest a shopping trip together?" }
        return "Beside: \(person) could use a hand with laundry. Could you offer some practical help this week?"
    }

    private func invalidateReview() { agreementChecked = false; saved = false }
}

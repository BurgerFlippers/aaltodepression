import SwiftUI

/// Crisis help, one tap from the home screen.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("If things feel too heavy right now, call. Someone will answer.")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.clear)
                }
                Section {
                    Link(destination: URL(string: "tel:+358000000000")!) {
                        Label("Call the crisis line", systemImage: "phone.fill")
                    }
                    .frame(minHeight: 44)
                } footer: {
                    Text("Demo placeholder number, not a real line. The clinic sets the real number in the plan.")
                }
                Section {
                    Link(destination: URL(string: "tel:112")!) {
                        Label("Call 112, emergency", systemImage: "staroflife.fill")
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Get help now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

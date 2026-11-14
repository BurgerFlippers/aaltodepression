import SwiftUI

struct EverydayProfileView: View {
    @State private var showSupport = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your setup") {
                    NavigationLink {
                        ScrollView { EverydayProfileFields().padding(20) }.background(EverydayStyle.paper).navigationTitle("About you")
                            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
                    } label: { Text("About you") }
                    NavigationLink {
                        ScrollView { EverydayRoutineFields().padding(20) }.background(EverydayStyle.paper).navigationTitle("Daily rhythm")
                    } label: { Text("Daily rhythm") }
                    NavigationLink("Your people") { EverydayNetworkView() }
                }
                Section("Automatic updates") {
                    NavigationLink("Movement & sleep") {
                        ScrollView { EverydaySensorSettings().padding(20) }.background(EverydayStyle.paper).navigationTitle("Movement & sleep")
                    }
                }
                Section {
                    Button("Talk to someone") { showSupport = true }
                    NavigationLink("About Beside") { EverydayAboutView() }
                }
            }.navigationTitle("You")
                .sheet(isPresented: $showSupport) { EverydayHelpView() }
        }
    }
}

struct EverydayAboutView: View {
    #if DEBUG
    @AppStorage("beside.demobar.visible") private var showDemobar = true
    #else
    @AppStorage("beside.demobar.visible") private var showDemobar = false
    #endif
    var body: some View {
        Form {
            Section {
                BesideLogoView().frame(width: 64, height: 64).frame(maxWidth: .infinity).padding(.vertical, 12)
                Text("Beside · Junction 2026").font(.headline)
                Text("Your profile and the people you choose stay on this phone.")
            }
            Section {
                Toggle("Show Demobar", isOn: $showDemobar)
            } header: { Text("Judging view") } footer: { Text("Visualise the actual data and backend support suggestions. Hiding the bar does not stop the backend.") }
            Section("This prototype") {
                Text("You can mark everyday things yourself. Optional iPhone movement and Apple Health sleep data can fill in some things for you.")
                Text("Background support requests are local demo drafts for now. They are not sent to anyone automatically.")
            }
        }.navigationTitle("About Beside").navigationBarTitleDisplayMode(.inline)
    }
}

struct EverydayHelpView: View {
    @Environment(EverydayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        if let url = URL(string: "tel:+358925250111") { openURL(url) }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Call MIELI Crisis Helpline").font(.headline)
                            Text("09 2525 0111").font(.body.monospacedDigit())
                        }.padding(.vertical, 8)
                    }.accessibilityIdentifier("mieli-call")
                    Link("About the helpline", destination: URL(string: "https://mieli.fi/tukea-ja-apua/kriisipuhelin?oai_link_source=model_response_hotline")!)
                } footer: { Text("Confidential phone support, 24/7.") }
                if store.state.people.contains(where: { $0.role == .close }) {
                    Section("Your loved ones") {
                        ForEach(store.state.people.filter { $0.role == .close }) { person in
                            Button {
                                let number = person.phone.filter { $0.isNumber || $0 == "+" }
                                if let url = URL(string: "tel:\(number)") { openURL(url) }
                            } label: { Label("Call \(person.name)", systemImage: "phone") }
                        }
                    }
                }
            }.navigationTitle("Get support").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

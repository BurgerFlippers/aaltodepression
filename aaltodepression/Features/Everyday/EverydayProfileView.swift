import SwiftUI

struct EverydayProfileView: View {
    @Environment(EverydayStore.self) private var store
    @State private var showDemo = false
    private var name: String { store.state.profile.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Your name") { EverydayProfileFields() }
                    section("Daily rhythm") { EverydayRoutineFields() }
                    section("Your people") {
                        EverydayContactsEditor().padding(18)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).background(EverydayStyle.paper)
                .navigationTitle(name.isEmpty ? "Your profile" : name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showDemo = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Demo controls")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    }
                }
                .sheet(isPresented: $showDemo) { BesideDemoControlsView() }
        }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
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
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your people").font(.largeTitle.bold())
                        Text("You can call someone you know. You don't need to find the right words first.").foregroundStyle(.secondary)
                    }
                    if store.state.people.isEmpty {
                        NavigationLink { EverydayNetworkView() } label: {
                            Label("Add someone you trust", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 64).background(EverydayStyle.mint, in: RoundedRectangle(cornerRadius: 20))
                        }
                    } else {
                        ForEach(store.state.people.sorted { $0.role == .close && $1.role != .close }) { person in
                            Button {
                                let number = person.phone.filter { $0.isNumber || $0 == "+" }
                                if let url = URL(string: "tel:\(number)") { openURL(url) }
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "person.crop.circle.fill").font(.system(size: 42))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(person.name).font(.title2.bold())
                                        Text(person.role.title).font(.subheadline)
                                    }
                                    Spacer()
                                    Image(systemName: "phone.fill").font(.title2).padding(12).background(.white.opacity(0.7), in: Circle())
                                }.padding(20).frame(maxWidth: .infinity, minHeight: 104)
                                    .background(person.role == .close ? EverydayStyle.mint : EverydayStyle.lavender, in: RoundedRectangle(cornerRadius: 24))
                            }.buttonStyle(.plain).accessibilityLabel("Call \(person.name), \(person.role.title)")
                        }
                    }
                    Divider().padding(.top, 8)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Emergency").font(.title2.bold())
                        Button {
                            if let url = URL(string: "tel:+358925250111?oai_link_source=model_response_hotline") { openURL(url) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "phone.circle.fill").font(.title)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("MIELI Crisis Helpline").font(.headline)
                                    Text("09 2525 0111").monospacedDigit()
                                    Text("Confidential phone support, 24/7").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityIdentifier("mieli-call")
                        Link("About the helpline", destination: URL(string: "https://mieli.fi/tukea-ja-apua/kriisipuhelin?oai_link_source=model_response_hotline")!).font(.footnote)
                    }
                }.padding(20)
            }.background(EverydayStyle.paper).navigationTitle("Get support").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

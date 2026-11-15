import SwiftUI

struct EverydayProfileView: View {
    @Environment(EverydayStore.self) private var store
    private var name: String { store.state.profile.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Your name") { EverydayProfileFields() }
                    section("Daily rhythm") { EverydayRoutineFields() }
                    section("Your people") {
                        EverydayContactsEditor().padding(18)
                            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
                    }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).background(EverydayStyle.paper)
                .mindHeader("You")
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    }
                }
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
    var body: some View {
        Form {
            Section {
                BesideLogoView().frame(width: 64, height: 64).frame(maxWidth: .infinity).padding(.vertical, 12)
                Text("MindMaintainer · Junction 2026").font(.headline)
                Text("Your profile and the people you choose stay on this phone.")
            }
            Section("This prototype") {
                Text("Shared Health readings guide three daily task choices. Tap one small step or invite someone along.")
                Text("Background support requests are local demo drafts for now. They are not sent to anyone automatically.")
            }
        }.navigationTitle("About MindMaintainer").navigationBarTitleDisplayMode(.inline)
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
                                .frame(maxWidth: .infinity, minHeight: 64).background(EverydayStyle.mint, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
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
                                    Image(systemName: "phone.fill").font(.title2).padding(12).background(EverydayStyle.surface.opacity(0.7), in: Circle())
                                }.padding(20).frame(maxWidth: .infinity, minHeight: 104)
                                    .background(person.role == .close ? EverydayStyle.mint : EverydayStyle.lavender, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
                            }.buttonStyle(.plain).accessibilityLabel("Call \(person.name), \(person.role.title)")
                        }
                    }
                    Divider().padding(.top, 8)
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emergency").font(.title2.bold())
                            Text("Demo · these numbers can't be called from here.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        // Demo: shown for information only, deliberately not tappable.
                        emergencyRow(title: "MIELI Crisis Helpline", number: "09 2525 0111", detail: "Confidential phone support, 24/7")
                        emergencyRow(title: "Emergency number", number: "112", detail: "Immediate danger to life or health")
                    }
                }.padding(20)
            }.background(EverydayStyle.paper).navigationTitle("Get support").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func emergencyRow(title: String, number: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "phone.circle.fill").font(.title).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(number).monospacedDigit()
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import UserNotifications

struct EverydayRootView: View {
    @State private var store: EverydayStore
    @State private var presentation: BesidePresentation
    #if DEBUG
    @AppStorage("beside.demobar.visible") private var showDemobar = true
    #else
    @AppStorage("beside.demobar.visible") private var showDemobar = false
    #endif

    init() {
        let profile = EverydayStore()
        _store = State(initialValue: profile)
        _presentation = State(initialValue: BesidePresentation(profileStore: profile))
    }
    @Environment(\.scenePhase) private var phase
    var body: some View {
        VStack(spacing: 0) {
            if showDemobar && store.state.completedSetup { BesideDemoBar() }
            Group {
            if store.state.completedSetup {
                TabView {
                    EverydayTodayView().tabItem { Label("Today", systemImage: "sun.max") }
                    EverydayProfileView().tabItem { Label("You", systemImage: "person.crop.circle") }
                }
            } else { EverydayOnboardingView() }
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(EverydayStyle.ink)
        .environment(\.locale, Locale(identifier: "en_GB"))
        .tint(EverydayStyle.ink)
        .preferredColorScheme(.light)
        .task {
            BesideNotificationInbox.shared.drain(into: presentation)
            // Retire notifications from the previous prototype when upgrading.
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nudge", "message"])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["nudge", "message"])
        }
        .task(id: phase) {
            guard phase == .active else { return }
            BesideNotificationInbox.shared.drain(into: presentation)
            store.refreshDay()
            await presentation.refresh()
        }
        .task(id: presentation.setupSignature) {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard store.state.completedSetup else { return }
            await presentation.refresh(readSensors: false)
        }
        .onChange(of: store.state.completedSetup) { _, complete in
            if complete { Task { await presentation.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .besidePlannerAction)) { _ in
            BesideNotificationInbox.shared.drain(into: presentation)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = store.persistenceError {
                VStack { Text(error).font(.footnote); Button("Try saving again") { store.retrySaving() } }
                    .padding().background(EverydayStyle.yellow)
            }
        }
        .environment(store)
        .environment(presentation)
        .environment(presentation.backend)
    }
}

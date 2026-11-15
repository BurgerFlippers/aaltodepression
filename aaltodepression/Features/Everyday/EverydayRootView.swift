import SwiftUI
import UserNotifications

struct EverydayRootView: View {
    @State private var presentation: BesidePresentation?
    var body: some View {
        Group {
            if let presentation { EverydaySessionView(store: presentation.profileStore, presentation: presentation) }
            else { ProgressView("Opening Mind…") }
        }.task {
            if presentation == nil { presentation = BesidePresentation(profileStore: EverydayStore()) }
        }
    }
}

private struct EverydaySessionView: View {
    @Bindable var store: EverydayStore
    @Bindable var presentation: BesidePresentation
    @State private var selectedTab = 0
    @State private var demoDay: Day?
    @Environment(\.scenePhase) private var phase
    var body: some View {
        VStack(spacing: 0) {
            Group {
                if store.state.completedSetup {
                    TabView(selection: $selectedTab) {
                        EverydayTodayView().tabItem { Label("One thing", systemImage: "sun.max") }.tag(0)
                        BesideDemoView().tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }.tag(2)
                        BesideForYouView().tabItem { Label("For you", systemImage: "heart") }.tag(3)
                        EverydayProfileView().tabItem { Label("You", systemImage: "person.crop.circle") }.tag(1)
                    }
                } else { EverydayOnboardingView() }
            }
        }
        .onChange(of: selectedTab) { old, new in
            if old == 2 { demoDay = presentation.day; presentation.returnToLive() }
            if new == 2 { presentation.selectDay(demoDay ?? presentation.preferredTrendDay, refreshSnapshot: true) }
        }
        .onChange(of: presentation.liveBackend.planner.state.sidequests) { _, _ in presentation.syncSidequestWidget() }
        .onChange(of: presentation.sidequestFocus) { _, _ in selectedTab = 0 }
        .onOpenURL { url in
            guard url.scheme == "beside" else { return }
            if url.host?.hasPrefix("demo-sms-") == true {
                _ = presentation.demoShortcutSender.handle(url)
                return
            }
            if url.host == "sidequest" { presentation.openSidequest(); selectedTab = 0 }
            if url.host == "reach-out" { presentation.openMessagesFromLink(); selectedTab = 0 }
        }
        .foregroundStyle(EverydayStyle.ink)
        .environment(\.locale, Locale(identifier: "en_GB"))
        .tint(EverydayStyle.accent)
        .preferredColorScheme(.dark)
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
            await presentation.repairHealthAccessIfNeeded()
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

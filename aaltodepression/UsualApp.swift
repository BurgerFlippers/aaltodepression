import SwiftUI
import SwiftData
import UserNotifications

@main
struct BesideApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            EverydayRootView()
        }
    }
}

/// Shows the step-1 notification as a banner even while the app is open (the demo needs it on stage).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PlannerNotifications.registerCategories()
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// The 12:00 reminder opens the message to the friend.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let action = await PlannerNotifications.action(for: response) {
            let date = response.notification.date
            await MainActor.run { BesideNotificationInbox.shared.receive(action, at: date) }
        }
        if response.notification.request.content.userInfo["compose"] as? Bool == true {
            await MainActor.run { NotificationCenter.default.post(name: .openCompose, object: nil) }
        }
    }
}

extension Notification.Name {
    static let openCompose = Notification.Name("openCompose")
    static let besidePlannerAction = Notification.Name("besidePlannerAction")
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @State private var noMessages = false

    var body: some View {
        @Bindable var model = model
        Group {
            if model.onboarded {
                TabView(selection: $model.tab) {
                    TodayView().tabItem { Label("Today", systemImage: "sun.horizon") }.tag(AppModel.Tab.today)
                    PlanView().tabItem { Label("Plan", systemImage: "list.bullet.indent") }.tag(AppModel.Tab.plan)
                }
            } else {
                OnboardingView()
            }
        }
        .tint(Palette.tint)
        .task { model.attach(context) }
        .onChange(of: phase, initial: true) { _, p in
            if p == .active { model.startLiveObserver() } else { model.stopLiveObserver() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCompose)) { _ in
            model.tab = .today
            model.showCompose = true
        }
        .sheet(isPresented: Binding(get: { model.showCompose && MessageCompose.canSend },
                                    set: { model.showCompose = $0 })) {
            MessageCompose(recipient: model.friendPhone, body: model.plan.friendMessage) { model.showCompose = false }
                .ignoresSafeArea()
        }
        .onChange(of: model.showCompose) { _, show in
            if show && !MessageCompose.canSend { model.showCompose = false; noMessages = true }
        }
        .alert("Messages isn't available on this device", isPresented: $noMessages) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("On an iPhone with Messages, this opens your message to \(model.plan.friendName) ready to send.")
        }
    }
}

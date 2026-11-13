import SwiftUI
import SwiftData
import UserNotifications

@main
struct UsualApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(for: DailyFeature.self)
    }
}

/// Shows the step-1 notification as a banner even while the app is open (the demo needs it on stage).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if model.onboarded {
                TabView {
                    TodayView().tabItem { Label("Today", systemImage: "sun.horizon") }
                    PlanView().tabItem { Label("Plan", systemImage: "list.bullet.rectangle") }
                    DataView().tabItem { Label("Data", systemImage: "waveform.path.ecg") }
                    SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
            }
        }
        .tint(Palette.tint)
        .task { model.attach(context) }
    }
}

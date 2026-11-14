import Foundation

/// Keeps notification actions until the SwiftUI scene is ready, including a cold launch.
@MainActor
final class BesideNotificationInbox {
    static let shared = BesideNotificationInbox()
    private var pending: [(PlannerNotificationAction, Date)] = []
    func receive(_ action: PlannerNotificationAction, at date: Date) {
        pending.append((action, date))
        NotificationCenter.default.post(name: .besidePlannerAction, object: nil)
    }
    func drain(into presentation: BesidePresentation) {
        let actions = pending
        pending.removeAll()
        for (action, date) in actions { presentation.handleNotification(action, at: date) }
    }
}

import Foundation
import UserNotifications

/// What a tap on a planner notification asks for. The delegate turns a response into one of these
/// with `PlannerNotifications.action(for:)` and passes it to `Planner.handle(_:deliveredAt:)` with
/// `response.notification.date`, so the answer lands on the day the notification fired.
nonisolated enum PlannerNotificationAction: Sendable, Equatable {
    case medicationTaken(medID: String, time: Int)
    case groceries(Bool)
    case open
    case sidequest(day: Int)
}

/// Local notifications for the planner. No push (free personal team), at most a few a day.
/// Texts never name a medicine or a feeling, because they show on the lock screen.
/// The safety questions are never asked from a notification.
nonisolated enum PlannerNotifications {
    static let prefix = "planner."
    static let medCategory = PlannedNotification.Category.medication.rawValue
    static let shopCategory = PlannedNotification.Category.shop.rawValue

    /// Register once at launch (integrator: from the app delegate).
    static func registerCategories() {
        let taken = UNNotificationAction(identifier: "taken", title: "Taken")
        let later = UNNotificationAction(identifier: "later", title: "Remind me in 30 min")
        let yes = UNNotificationAction(identifier: "shopYes", title: "Yes")
        let no = UNNotificationAction(identifier: "shopNo", title: "Not today")
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: medCategory, actions: [taken, later], intentIdentifiers: []),
            UNNotificationCategory(identifier: shopCategory, actions: [yes, no], intentIdentifiers: []),
        ])
    }

    /// Replaces all planner notifications with the ones `NotificationPlan.daily(for:)` lists.
    static func schedule(for s: PlannerSetup) async {
        let center = UNUserNotificationCenter.current()
        await removeDailyPlan()
        for n in NotificationPlan.daily(for: s) {
            var when = DateComponents(hour: n.time / 60, minute: n.time % 60)
            // DateComponents weekday: 1 = Sunday; ISO: 1 = Monday.
            if let w = n.weekday { when.weekday = w % 7 + 1 }
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: prefix + n.id, content: content(n), trigger: trigger))
        }
    }

    /// Removes the repeating daily reminders only; a pending "Remind me in 30 min" stays.
    static func removeDailyPlan() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter(isDailyPlan)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func isDailyPlan(_ id: String) -> Bool {
        id.hasPrefix(prefix) && NotificationPlan.isDailyPlan(id.dropFirst(prefix.count))
    }

    /// Shows a planned notification after `seconds` (demo and test buttons).
    static func show(_ n: PlannedNotification, after seconds: TimeInterval = 1) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: prefix + "now." + n.id, content: content(n), trigger: trigger))
    }

    static func content(_ n: PlannedNotification) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = n.title
        c.body = n.body
        c.sound = .default
        if let cat = n.category { c.categoryIdentifier = cat.rawValue }
        if let m = n.medicationID { c.userInfo = ["medID": m, "time": n.time] }
        return c
    }

    /// One-off reminder 30 minutes from now for a dose.
    static func remindLater(medID: String, time: Int) async {
        let c = UNMutableNotificationContent()
        c.title = "Medicine time"
        c.body = "Tap Taken when done."
        c.sound = .default
        c.categoryIdentifier = medCategory
        c.userInfo = ["medID": medID, "time": time]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: prefix + "later.\(medID).\(time)", content: c, trigger: trigger))
    }

    /// Turns a notification response into an action. "Remind me later" is handled here and returns nil.
    static func action(for response: UNNotificationResponse) async -> PlannerNotificationAction? {
        let req = response.notification.request
        if req.identifier.hasPrefix("beside.sidequest."), let day = req.content.userInfo["sidequestDay"] as? Int {
            return .sidequest(day: day)
        }
        guard req.identifier.hasPrefix(prefix) else { return nil }
        let info = req.content.userInfo
        switch response.actionIdentifier {
        case "taken":
            guard let id = info["medID"] as? String, let t = info["time"] as? Int else { return .open }
            return .medicationTaken(medID: id, time: t)
        case "later":
            if let id = info["medID"] as? String, let t = info["time"] as? Int { await remindLater(medID: id, time: t) }
            return nil
        case "shopYes": return .groceries(true)
        case "shopNo": return .groceries(false)
        default: return .open
        }
    }
}

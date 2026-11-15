import Foundation
import UserNotifications

nonisolated enum SidequestReminders {
    static func identifier(_ day: Day) -> String { "beside.sidequest.\(day.jdn)" }

    static func schedule(on day: Day, at date: Date) async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw ReminderError.denied }
        } else if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
            throw ReminderError.denied
        }
        guard Day(Date()) == day, Day(date) == day, date.timeIntervalSinceNow > 0 else { throw ReminderError.expired }
        let content = UNMutableNotificationContent()
        content.title = "A small step, when you’re ready"
        content.body = "Your chosen task is here. You can make it smaller."
        content.sound = .default
        content.userInfo = ["sidequestDay": day.jdn]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let rounded = Calendar.current.date(from: components), rounded > Date(), Day(rounded) == day else { throw ReminderError.expired }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier(day), content: content, trigger: trigger))
    }

    static func cancel(on day: Day) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(day)])
        center.removeDeliveredNotifications(withIdentifiers: [identifier(day)])
    }

    enum ReminderError: LocalizedError {
        case denied, expired
        var errorDescription: String? {
            switch self {
            case .denied: "Notifications are off for Mind. You can enable them in Settings."
            case .expired: "Choose a time later today. Your task is still saved."
            }
        }
    }
}

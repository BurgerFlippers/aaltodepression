import Foundation

/// A local notification the app would schedule, as plain data (testable without iOS).
/// Store/PlannerNotifications turns these into UNNotificationRequests.
nonisolated struct PlannedNotification: Sendable, Equatable, Identifiable {
    enum Category: String, Sendable { case medication = "PLANNER_MED", shop = "PLANNER_SHOP" }

    let id: String
    let title: String
    let body: String
    /// Minutes after midnight.
    let time: Int
    /// ISO weekday (1 = Monday) for weekly ones; nil = every day.
    let weekday: Int?
    let category: Category?
    /// For medication: which dose a "Taken" tap marks.
    let medicationID: String?
}

/// What the planner reminds about. Lock-screen texts never name a medicine, a feeling or a person's
/// health, and the safety questions are never asked from a notification.
nonisolated enum NotificationPlan {
    static func daily(for s: PlannerSetup) -> [PlannedNotification] {
        var out: [PlannedNotification] = [
            .init(id: "checkin", title: "Good morning", body: "How is today feeling? Three taps is enough.",
                  time: s.checkInTime, weekday: nil, category: nil, medicationID: nil),
        ]
        for m in s.medications {
            for t in m.times {
                out.append(.init(id: "med.\(m.id).\(t)", title: "Medicine time", body: "Tap Taken when done.",
                                 time: t, weekday: nil, category: .medication, medicationID: m.id))
            }
        }
        for w in s.shoppingWeekdays.sorted() {
            out.append(.init(id: "shop.\(w)", title: "Shopping day", body: "Did you get to the shop today?",
                             time: 17 * 60, weekday: w, category: .shop, medicationID: nil))
        }
        out.append(.init(id: "winddown", title: "Evening wind-down", body: "A couple of small steps is enough.",
                         time: s.windDownTime, weekday: nil, category: nil, medicationID: nil))
        return out
    }

    /// Whether a scheduled id (without the app's prefix) belongs to the repeating daily plan.
    /// One-off ones ("later.…", "now.…") are not, so replacing the plan never drops them.
    static func isDailyPlan(_ id: Substring) -> Bool {
        id == "checkin" || id == "winddown" || id.hasPrefix("med.") || id.hasPrefix("shop.")
    }

    /// Demo only: tells the person a suggestion went to a contact (in the prototype nothing is sent).
    static func messageSent(_ m: OutgoingMessage) -> PlannedNotification {
        .init(id: "sent.\(m.id)", title: "Message to \(m.contactName)", body: "Sent (simulated): \(m.text)",
              time: 0, weekday: nil, category: nil, medicationID: nil)
    }
}

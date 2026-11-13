import Foundation
import CoreMotion

/// Core Motion keeps only the last 7 days of activity. Sums segments per day by kind.
nonisolated enum MotionSource {
    static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }
    static var isAuthorized: Bool { CMMotionActivityManager.authorizationStatus() == .authorized }

    static func read(calendar: Calendar = .current) async -> FeatureTable {
        guard isAvailable else { return FeatureTable() }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let manager = CMMotionActivityManager()
        struct Segment: Sendable { let startDate: Date; let confident: Bool; let key: String? }
        let activities: [Segment] = await withCheckedContinuation { cont in
            manager.queryActivityStarting(from: start, to: end, to: OperationQueue()) { list, _ in
                cont.resume(returning: (list ?? []).map { a in
                    Segment(startDate: a.startDate, confident: a.confidence != .low,
                            key: a.stationary ? F.stillHours : a.running ? F.runningHours : a.walking ? F.walkingHours
                                : a.automotive ? F.automotiveHours : a.cycling ? F.cyclingHours : nil)
                })
            }
        }
        var hours: [String: [Day: Double]] = [:]
        // Each segment lasts until the next one starts.
        for (i, a) in activities.enumerated() where a.confident {
            let segStart = max(a.startDate, start)
            let segEnd = i + 1 < activities.count ? activities[i + 1].startDate : end
            guard segEnd > segStart else { continue }
            guard let key = a.key else { continue }
            // Split across midnight.
            var cursor = segStart
            while cursor < segEnd {
                let dayEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: cursor)!)
                let stop = min(segEnd, dayEnd)
                hours[key, default: [:]][Day(cursor, calendar: calendar), default: 0] += stop.timeIntervalSince(cursor) / 3600
                cursor = stop
            }
        }
        var t = FeatureTable()
        for (key, days) in hours { for (d, v) in days { t.set(key, d, v) } }
        return t
    }
}

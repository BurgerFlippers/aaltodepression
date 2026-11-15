import Foundation

// Contract: sleep, activity and places, ready to show. Built by Engine/Tracking/TrackingBuilder.
// Every value already carries its text and how it compares with the person's own usual,
// so a screen only lays things out. Missing data is `.unknown`, never zero.

/// How a value compares with the person's own usual (median ± about one usual spread).
nonisolated enum Comparison: String, Codable, Sendable {
    case below, usual, above, unknown
}

/// Which direction is the healthy one, so a screen can pick neutral words (never red).
nonisolated enum GoodWhen: String, Codable, Sendable {
    case higher, lower, nearUsual
}

/// One number for a screen.
nonisolated struct TrackedValue: Sendable, Equatable, Identifiable {
    let key: String
    let title: String
    let value: Double?
    /// Formatted value, e.g. "7 h 12 min", or "–".
    let text: String
    /// Formatted usual, e.g. "usual 7 h 30 min", or nil before there is a usual (first week).
    let usualText: String?
    let comparison: Comparison
    let goodWhen: GoodWhen
    var id: String { key }
}

/// One day on a trend chart. Nil means no data that day (draw a gap, not a zero).
nonisolated struct TrendPoint: Sendable, Equatable, Identifiable {
    let day: Day
    let value: Double?
    var id: Int { day.jdn }
}

/// What the data comes from, for empty states ("Wear your Watch to bed to see sleep stages").
nonisolated enum DataCoverage: String, Sendable {
    case none, phoneOnly, phoneAndWatch
}

nonisolated struct SleepSummary: Sendable, Equatable {
    /// The morning the night ended (nights belong to the day they end).
    let night: Day
    let duration: TrackedValue
    let fellAsleep: TrackedValue
    let wokeUp: TrackedValue
    let awake: TrackedValue
    let efficiency: TrackedValue
    /// Spread of the sleep midpoint over the last 7 nights. Lower is steadier.
    let regularity: TrackedValue
    /// Nights of the last 3 clearly shorter than usual.
    let shortNights: Int
    /// Hours slept, last 28 nights.
    let trend: [TrendPoint]
    let usualHours: Double?
    let coverage: DataCoverage
    /// One plain sentence, e.g. "Shorter than your usual: 5 h 40 min against 7 h 20 min."
    let headline: String
}

nonisolated struct ActivitySummary: Sendable, Equatable {
    let day: Day
    /// Minutes after midnight the numbers run to (today is partial).
    let asOf: Int
    /// Steps so far, compared with the person's usual steps by this time of day.
    let stepsSoFar: TrackedValue
    let activeHours: TrackedValue
    let onFoot: TrackedValue
    let exercise: TrackedValue
    let daylight: TrackedValue
    let walkingSpeed: TrackedValue
    /// Steps per hour 0–23 (nil = no data for that hour).
    let hourlySteps: [Double?]
    /// Movement the planner can vouch for today (minutes), and the words that explain it.
    let movementMinutes: Double
    let movementEvidence: String?
    /// Steps per day, last 28 days.
    let trend: [TrendPoint]
    let coverage: DataCoverage
    let headline: String
}

nonisolated struct PlacesSummary: Sendable, Equatable {
    /// The last complete day (places are worked out from visits after the day ends).
    let day: Day
    let locationEnabled: Bool
    let timeAtHome: TrackedValue
    let timeAway: TrackedValue
    let places: TrackedValue
    let furthest: TrackedValue
    let variety: TrackedValue
    /// Hours away from home per day, last 28 days.
    let trend: [TrendPoint]
    let headline: String
}

/// Bonus: screen time as the person reported it (Apple lets apps read Screen Time only with a
/// special entitlement, so it comes from the optional morning question or Settings → Screen Time).
nonisolated struct ScreenTimeSummary: Sendable, Equatable {
    /// The day the report is about (yesterday).
    let day: Day
    let hours: TrackedValue
    /// Nights in the last 7 with the phone in bed after lights out (answered nights only).
    let phoneInBedNights: Int
    let answeredNights: Int
    /// Hours per day, last 28 days (nil = not reported).
    let trend: [TrendPoint]
    let headline: String
}

/// Everything the tracking screens need for one day.
nonisolated struct TrackingSnapshot: Sendable, Equatable {
    let day: Day
    let sleep: SleepSummary
    let activity: ActivitySummary
    let places: PlacesSummary
    var screenTime: ScreenTimeSummary? = nil
}

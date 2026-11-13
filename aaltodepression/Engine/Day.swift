import Foundation

/// A calendar day as an integer (Julian day number), independent of time zones.
/// Arithmetic on days is plain integer arithmetic, which keeps the engine simple.
nonisolated struct Day: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    let jdn: Int

    init(jdn: Int) { self.jdn = jdn }

    init(year: Int, month: Int, day: Int) {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    var components: (year: Int, month: Int, day: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146097
        let c = a - 146097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4800 + m / 10
        return (year, month, day)
    }

    /// Midnight at the start of this day in the given calendar's time zone.
    func start(in calendar: Calendar = .current) -> Date {
        let c = components
        return calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
    }

    static func + (lhs: Day, rhs: Int) -> Day { Day(jdn: lhs.jdn + rhs) }
    static func - (lhs: Day, rhs: Int) -> Day { Day(jdn: lhs.jdn - rhs) }
    static func - (lhs: Day, rhs: Day) -> Int { lhs.jdn - rhs.jdn }
    static func < (lhs: Day, rhs: Day) -> Bool { lhs.jdn < rhs.jdn }

    var description: String {
        let c = components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }

    /// Days in the half-open range [from, to).
    static func range(_ from: Day, _ to: Day) -> [Day] {
        guard from < to else { return [] }
        return (from.jdn..<to.jdn).map(Day.init(jdn:))
    }
}

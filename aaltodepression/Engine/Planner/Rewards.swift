import Foundation

/// The reward: every day is a row in a rag rug. Each pillar touched adds a thread, all four basics
/// add a star, asking for or getting help ties a gold knot. Nothing is ever unpicked, there are no
/// streaks, and a quiet day is a thin row that still belongs to the rug.
nonisolated enum Rewards {
    static func day(_ day: Day, items: [PlanItem], state: PlannerState) -> DayReward {
        let threads = Set(items.filter { $0.status == .done }.map(\.pillar))
        let hasMeds = items.contains { $0.pillar == .meds }
        let needed = Pillar.basics.filter { $0 != .meds || hasMeds }
        let star = needed.allSatisfy { p in
            // A pillar counts when everything open on it is done (all doses, not just one).
            let ps = items.filter { $0.pillar == p }
            return !ps.isEmpty && ps.allSatisfy { $0.status == .done }
        }
        let knots = goldKnots(day, state: state)
        let message: String?
        if star { message = "All the basics today. That's a whole day woven." }
        else if knots > 0 { message = "Reaching out counts. A gold knot for today." }
        else if threads.count >= 2 { message = "\(threads.count) threads in today's row." }
        else { message = nil }
        return DayReward(day: day, threads: threads, checkedIn: state.checkIn(on: day) != nil,
                         star: star, goldKnots: knots, message: message)
    }

    /// Help asked and answered, or time spent with someone.
    static func goldKnots(_ day: Day, state: PlannerState) -> Int {
        let replied = state.outbox.filter { $0.day == day && $0.status == .replied }.count
        let met = state.socialPlans.filter { $0.day == day && $0.met == true }.count
        return replied + met
    }

    /// Sunday summary. Counts only what happened; never compares with last week.
    static func week(ending day: Day, rewards: [DayReward]) -> String {
        let week = rewards.filter { day - $0.day < 7 && $0.day <= day }
        let stars = week.filter(\.star).count
        let threads = week.map { $0.threads.count + ($0.checkedIn ? 1 : 0) }.reduce(0, +)
        let knots = week.map(\.goldKnots).reduce(0, +)
        var parts = ["\(threads) threads"]
        if stars > 0 { parts.append("\(stars) star\(stars == 1 ? "" : "s")") }
        if knots > 0 { parts.append("\(knots) gold knot\(knots == 1 ? "" : "s")") }
        return "This week's rug is ready: " + parts.joined(separator: ", ") + "."
    }
}

/// What seems to work for this person, from their own days. Shown only with enough examples,
/// always as "seems", never as advice from a model.
nonisolated enum Insights {
    static let minimumExamples = 5

    static func compute(state: PlannerState, table: FeatureTable, through day: Day) -> [String] {
        var out: [String] = []
        // Movement today → next morning's mood.
        var after = 0, better = 0
        for d in Day.range(day - 56, day) {
            guard let today = state.checkIn(on: d), let next = state.checkIn(on: d + 1) else { continue }
            let moved = state.marks[TodayBuilder.itemID(d, .movement, "move")]?.status == .done
                || TodayBuilder.movementSeen(table, d).minutes >= 10
            guard moved else { continue }
            after += 1
            if next.mood >= today.mood { better += 1 }
        }
        if after >= minimumExamples, Double(better) / Double(after) >= 0.6 {
            out.append("After days you got outside, the next morning felt the same or better \(better) of \(after) times.")
        }
        // Wind-down → sleep a bit longer than the person's usual.
        var wound = 0, slept = 0
        for d in Day.range(day - 56, day) {
            guard state.marks[TodayBuilder.itemID(d, .sleep, "winddown")]?.status == .done,
                  let h = table.value(F.sleepHours, d + 1), let u = Baseline.usual(F.sleepHours, in: table, for: d + 1) else { continue }
            wound += 1
            if h >= u.median { slept += 1 }
        }
        if wound >= minimumExamples, Double(slept) / Double(wound) >= 0.6 {
            out.append("After an evening wind-down you slept at least your usual \(slept) of \(wound) nights.")
        }
        // Bonus, screen time: phone in bed → how long the next night was.
        var bedNights = 0, shorter = 0
        for d in Day.range(day - 56, day) where (table.value(F.phoneInBed, d) ?? 0) >= 1 {
            guard let h = table.value(F.sleepHours, d + 1), let u = Baseline.usual(F.sleepHours, in: table, for: d + 1) else { continue }
            bedNights += 1
            if h < u.median { shorter += 1 }
        }
        if bedNights >= minimumExamples, Double(shorter) / Double(bedNights) >= 0.6 {
            out.append("After evenings with the phone in bed you slept less than usual \(shorter) of \(bedNights) nights.")
        }
        // Help from people → how the following day felt.
        let helped = state.outbox.filter { $0.status == .replied && $0.day < day }
        let lifted = helped.filter { m in
            guard let a = state.checkIn(on: m.day), let b = state.checkIn(on: m.day + 1) else { return false }
            return b.mood > a.mood
        }
        if helped.count >= 3, lifted.count * 2 >= helped.count {
            out.append("The day after someone helped out felt lighter \(lifted.count) of \(helped.count) times.")
        }
        return out
    }
}

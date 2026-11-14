import Foundation

/// Basic analysis of sleep, activity and places: each value against the person's own usual
/// (28-day median and spread from Baseline), plus 28-day trends. Pure functions; reads only the
/// feature table, so it works the same for the demo and for real data.
nonisolated enum TrackingBuilder {
    static let trendDays = 28

    static func snapshot(table: FeatureTable, day: Day, minutes: Int, locationEnabled: Bool) -> TrackingSnapshot {
        TrackingSnapshot(day: day,
                         sleep: sleep(table: table, night: day),
                         activity: activity(table: table, day: day, minutes: minutes),
                         places: places(table: table, day: day - 1, enabled: locationEnabled),
                         screenTime: screenTime(table: table, day: day - 1))
    }

    // MARK: - Screen time (bonus, self-reported)

    static func screenTime(table: FeatureTable, day: Day) -> ScreenTimeSummary {
        let hours = value(F.screenTimeSelf, table, day, good: .lower)
        let week = Day.range(day - 6, day + 1)
        let answered = week.filter { table.value(F.phoneInBed, $0) != nil }.count
        let inBed = week.filter { (table.value(F.phoneInBed, $0) ?? 0) >= 1 }.count
        let headline: String
        switch hours.comparison {
        case .unknown: headline = hours.value == nil ? "No screen time reported for yesterday." : "Yesterday about \(hours.text). Your usual appears after a week of answers."
        case .above: headline = "More phone time than your usual yesterday: \(hours.text)."
        case .below: headline = "Less phone time than your usual yesterday: \(hours.text)."
        case .usual: headline = "Phone time close to your usual yesterday: \(hours.text)."
        }
        return ScreenTimeSummary(day: day, hours: hours, phoneInBedNights: inBed, answeredNights: answered,
                                 trend: trend(F.screenTimeSelf, table, through: day), headline: headline)
    }

    // MARK: - Sleep

    static func sleep(table: FeatureTable, night: Day) -> SleepSummary {
        let duration = value(F.sleepHours, table, night, good: .higher)
        let regularity = midpointSpread(table, night)
        let short = InterventionRules.shortSleepNights(table, through: night)
        let usual = Baseline.usual(F.sleepHours, in: table, for: night)?.median
        let hasWatch = table.value(F.deepMin, night) != nil || table.value(F.hrv, night) != nil
        let coverage: DataCoverage = duration.value == nil ? .none : hasWatch ? .phoneAndWatch : .phoneOnly

        let headline: String
        switch (duration.comparison, duration.value, usual) {
        case (.unknown, nil, _): headline = "No sleep data for last night."
        case (.unknown, _?, nil): headline = "Slept \(duration.text). Your usual appears after a week of nights."
        case (.below, _, let u?): headline = "Shorter than your usual: \(duration.text) against \(ValueText.hoursMinutes(u))."
        case (.above, _, let u?): headline = "Longer than your usual: \(duration.text) against \(ValueText.hoursMinutes(u))."
        default: headline = "Close to your usual: \(duration.text)."
        }
        return SleepSummary(night: night, duration: duration,
                            fellAsleep: value(F.bedtime, table, night, good: .nearUsual),
                            wokeUp: value(F.wake, table, night, good: .nearUsual),
                            awake: value(F.awakeMin, table, night, good: .lower),
                            efficiency: value(F.sleepEfficiency, table, night, good: .higher),
                            regularity: regularity, shortNights: short,
                            trend: trend(F.sleepHours, table, through: night), usualHours: usual,
                            coverage: coverage, headline: headline)
    }

    /// Standard deviation of the sleep midpoint over the last 7 nights against its usual over the baseline.
    static func midpointSpread(_ table: FeatureTable, _ night: Day) -> TrackedValue {
        func midpoints(_ days: [Day]) -> [Double] {
            days.compactMap { d in
                guard let b = table.value(F.bedtime, d), let w = table.value(F.wake, d) else { return nil }
                return (b + w + 6) / 2
            }
        }
        let week = Scorer.sd(midpoints(Day.range(night - 6, night + 1)))
        let w = Baseline.window(for: night)
        let usual = Scorer.sd(midpoints(Day.range(w.from, w.to)))
        var cmp = Comparison.unknown
        if let s = week, let u = usual { cmp = s > max(u, 0.25) * 1.5 ? .above : s < u * 0.6 ? .below : .usual }
        return TrackedValue(key: "sleepRegularity", title: "Sleep timing spread, last 7 nights", value: week,
                            text: week.map { ValueText.minutes($0 * 60) } ?? "–",
                            usualText: usual.map { "usual " + ValueText.minutes($0 * 60) }, comparison: cmp, goodWhen: .lower)
    }

    // MARK: - Activity

    static func activity(table: FeatureTable, day: Day, minutes: Int) -> ActivitySummary {
        let hour = min(24, max(0, minutes / 60))
        // Only hours that have passed (the demo has whole days of data; a real today has none ahead anyway).
        let hourly: [Double?] = (0..<24).map { $0 < hour ? table.value(F.stepsHour($0), day) : nil }
        let partial = hour < 24
        // A day "has steps" if it has a total or any hourly value; then quiet hours count as zero.
        func hasSteps(_ d: Day) -> Bool { table.value(F.steps, d) != nil || (0..<24).contains { table.value(F.stepsHour($0), d) != nil } }
        // Steps and active hours by this hour, today and on each baseline day, so a morning is never
        // compared with a whole day.
        func stepsBy(_ d: Day) -> Double? {
            guard hasSteps(d) else { return nil }
            return (0..<hour).map { table.value(F.stepsHour($0), d) ?? 0 }.reduce(0, +)
        }
        func activeHoursBy(_ d: Day) -> Double? {
            guard hasSteps(d) else { return nil }
            return Double((0..<hour).filter { (table.value(F.stepsHour($0), d) ?? 0) >= 250 }.count)
        }
        let w = Baseline.window(for: day)
        let baseDays = Day.range(w.from, w.to)
        let soFar = partial ? stepsBy(day) : table.value(F.steps, day)
        let usualBy = Baseline.usual(baseDays.compactMap { partial ? stepsBy($0) : table.value(F.steps, $0) })
        let clock = PlanFormat.clock(hour * 60)
        let steps = make(key: "stepsSoFar", title: partial ? "Steps by \(clock)" : "Steps",
                         x: soFar, usual: usualBy, format: .integer("steps"), good: .higher, floor: 250)
        let active = partial
            ? make(key: F.activeHours, title: "Hours with movement by \(clock)", x: activeHoursBy(day),
                   usual: Baseline.usual(baseDays.compactMap(activeHoursBy)), format: .integer("h"), good: .higher, floor: 1)
            : value(F.activeHours, table, day, good: .higher)
        /// Running totals can't be compared with whole days until the day is over.
        func soFarOnly(_ v: TrackedValue) -> TrackedValue {
            guard partial else { return v }
            return TrackedValue(key: v.key, title: v.title + " so far", value: v.value, text: v.text,
                                usualText: v.usualText.map { $0.replacingOccurrences(of: "usual", with: "whole-day usual") },
                                comparison: .unknown, goodWhen: v.goodWhen)
        }

        let seen = TodayBuilder.movementSeen(table, day)
        let hasWatch = table.value(F.exerciseMin, day) != nil || table.value(F.daylightMin, day) != nil
        let coverage: DataCoverage = soFar == nil && seen.minutes == 0 ? .none : hasWatch ? .phoneAndWatch : .phoneOnly
        let headline: String
        switch steps.comparison {
        case .unknown: headline = soFar == nil ? "No step data yet today." : "\(steps.text) so far. Your usual by this time appears after a week."
        case .below: headline = "Quieter than your usual so far: \(steps.text)."
        case .above: headline = "More on the move than usual: \(steps.text)."
        case .usual: headline = "About your usual so far: \(steps.text)."
        }
        let daylightKey = table.value(F.daylightMin, day) != nil ? F.daylightMin : F.daylightWalkMin
        return ActivitySummary(day: day, asOf: minutes, stepsSoFar: steps,
                               activeHours: active,
                               onFoot: soFarOnly(value(F.walkingHours, table, day, good: .higher)),
                               exercise: soFarOnly(value(F.exerciseMin, table, day, good: .higher)),
                               daylight: soFarOnly(value(daylightKey, table, day, good: .higher)),
                               walkingSpeed: value(F.walkingSpeed, table, day, good: .nearUsual),
                               hourlySteps: hourly, movementMinutes: seen.minutes, movementEvidence: seen.evidence,
                               // Complete days only: today's partial total would always end the chart on a dip.
                               trend: trend(F.steps, table, through: partial ? day - 1 : day), coverage: coverage, headline: headline)
    }

    // MARK: - Places

    static func places(table: FeatureTable, day: Day, enabled: Bool) -> PlacesSummary {
        let home = value(F.homeHours, table, day, good: .lower)
        let away = value(F.awayHours, table, day, good: .higher)
        let headline: String
        if !enabled { headline = "Location is off. Places stays empty; nothing else depends on it." }
        else {
            switch away.comparison {
            case .unknown: headline = away.value == nil ? "No places data for yesterday yet." : "Your usual appears after a week."
            case .below: headline = "More time at home than your usual yesterday."
            case .above: headline = "Out and about more than your usual yesterday."
            case .usual: headline = "Time out of home close to your usual yesterday."
            }
        }
        return PlacesSummary(day: day, locationEnabled: enabled, timeAtHome: home, timeAway: away,
                             places: value(F.placesVisited, table, day, good: .higher),
                             furthest: value(F.maxKmFromHome, table, day, good: .nearUsual),
                             variety: value(F.locationEntropy, table, day, good: .higher),
                             trend: trend(F.awayHours, table, through: day), headline: headline)
    }

    // MARK: - Helpers

    static func value(_ key: String, _ table: FeatureTable, _ day: Day, good: GoodWhen) -> TrackedValue {
        let info = FeatureCatalog.byKey[key]
        return make(key: key, title: info?.title ?? key, x: table.value(key, day),
                    usual: Baseline.usual(key, in: table, for: day), format: info?.format ?? .decimal(1, ""), good: good,
                    floor: Baseline.madFloor[key] ?? 1e-6)
    }

    static func make(key: String, title: String, x: Double?, usual: Usual?, format: ValueFormat, good: GoodWhen, floor: Double) -> TrackedValue {
        var cmp = Comparison.unknown
        if let x, let u = usual {
            let spread = 1.4826 * max(u.mad, floor)
            cmp = x < u.median - spread ? .below : x > u.median + spread ? .above : .usual
        }
        return TrackedValue(key: key, title: title, value: x, text: x.map { ValueText.format($0, format) } ?? "–",
                            usualText: usual.map { "usual " + ValueText.format($0.median, format) }, comparison: cmp, goodWhen: good)
    }

    static func trend(_ key: String, _ table: FeatureTable, through day: Day) -> [TrendPoint] {
        Day.range(day - (trendDays - 1), day + 1).map { TrendPoint(day: $0, value: table.value(key, $0)) }
    }
}

/// Turns values into short text in the signal's own unit. Shared by tracking and the test screens.
nonisolated enum ValueText {
    static func format(_ v: Double, _ f: ValueFormat) -> String {
        switch f {
        case .integer(let u): return "\(Int(v.rounded())) \(u)".trimmingCharacters(in: .whitespaces)
        case .decimal(let n, let u): return String(format: "%.\(n)f %@", v, u).trimmingCharacters(in: .whitespaces)
        case .clockAfter18: return PlanFormat.clock((Int(((v + 18) * 60).rounded()) % 1440 + 1440) % 1440)
        case .clockAfterMidnight: return PlanFormat.clock(Int((v * 60).rounded()))
        case .hoursMinutes: return hoursMinutes(v)
        case .minutes: return minutes(v)
        case .percent(let n): return String(format: "%.\(n)f %%", v)
        case .fractionPercent(let n): return String(format: "%.\(n)f %%", v * 100)
        case .text: return "\(v)"
        }
    }

    static func hoursMinutes(_ hours: Double) -> String { PlanFormat.duration(minutes: hours * 60) }
    static func minutes(_ m: Double) -> String { "\(Int(m.rounded())) min" }
}

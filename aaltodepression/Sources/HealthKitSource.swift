import Foundation
import HealthKit

/// Reads the agreed Health types as one value per day. Missing types never crash;
/// empty results are left unknown (HealthKit cannot tell "denied" from "no data").
nonisolated struct HealthKitSource: Sendable {
    struct QuantitySpec: Sendable {
        let key: String
        let id: HKQuantityTypeIdentifier
        let options: HKStatisticsOptions
        let unit: HKUnit
        var minKey: String? = nil
        var maxKey: String? = nil
        var durationKey: String? = nil
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Only the agreed data scope (docs/DATA_SCOPE.md). Everything else in Health is left unread.
    static let quantitySpecs: [QuantitySpec] = {
        let perMin = HKUnit.count().unitDivided(by: .minute())
        let mps = HKUnit.meter().unitDivided(by: .second())
        return [
            .init(key: F.dietaryEnergy, id: .dietaryEnergyConsumed, options: .cumulativeSum, unit: .kilocalorie()),
            .init(key: F.dietaryWater, id: .dietaryWater, options: .cumulativeSum, unit: .literUnit(with: .milli)),
            .init(key: F.dietaryProtein, id: .dietaryProtein, options: .cumulativeSum, unit: .gram()),
            .init(key: F.dietaryCarbs, id: .dietaryCarbohydrates, options: .cumulativeSum, unit: .gram()),
            .init(key: F.dietaryFat, id: .dietaryFatTotal, options: .cumulativeSum, unit: .gram()),
            .init(key: F.steps, id: .stepCount, options: .cumulativeSum, unit: .count()),
            .init(key: F.walkingSpeed, id: .walkingSpeed, options: .discreteAverage, unit: mps),
            .init(key: F.exerciseMin, id: .appleExerciseTime, options: .cumulativeSum, unit: .minute()),
            .init(key: F.daylightMin, id: .timeInDaylight, options: .cumulativeSum, unit: .minute()),
            .init(key: F.restingHR, id: .restingHeartRate, options: .discreteAverage, unit: perMin),
            .init(key: F.hrv, id: .heartRateVariabilitySDNN, options: .discreteAverage, unit: .secondUnit(with: .milli)),
            .init(key: F.respRate, id: .respiratoryRate, options: .discreteAverage, unit: perMin),
            .init(key: F.wristTemp, id: .appleSleepingWristTemperature, options: .discreteAverage, unit: .degreeCelsius()),
        ]
    }()

    static var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>(quantitySpecs.map { HKQuantityType($0.id) })
        // Headphone exposure is read only for its timing (late-night listening), never its level.
        types.insert(HKQuantityType(.headphoneAudioExposure))
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKCategoryType(.mindfulSession))
        types.insert(HKObjectType.workoutType())
        if #available(iOS 18.0, *) {
            types.insert(HKObjectType.stateOfMindType())
            types.insert(HKScoredAssessmentType(.PHQ9))
            types.insert(HKScoredAssessmentType(.GAD7))
        }
        // Medication dose events are not allowed in this request (HealthKit throws). Medications
        // use their own per-medication permission, asked separately with requestMedicationAccess().
        return types
    }

    /// Types the app writes: the daily check-in as State of Mind (iOS 18) and breathing sessions.
    static var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKCategoryType(.mindfulSession)]
        if #available(iOS 18.0, *) { types.insert(HKObjectType.stateOfMindType()) }
        return types
    }

    let store = HKHealthStore()

    func requestAuthorization() async throws {
        // Ask only for types this device and OS allow, so one unsupported type never crashes the request.
        let allowed = Self.readTypes.filter { !Self.disallowed.contains($0.identifier) }
        try await store.requestAuthorization(toShare: Self.shareTypes, read: allowed)
    }

    /// Types HealthKit refuses in a plain read request on some systems.
    static let disallowed: Set<String> = ["HKMedicationDoseEventTypeIdentifierMedicationDoseEvent"]

    /// Medications have their own sheet, one medication at a time. Shown only after a tap.
    func requestMedicationAccess() async {
        if #available(iOS 26.0, *) {
            try? await store.requestPerObjectReadAuthorization(for: HKObjectType.userAnnotatedMedicationType(), predicate: nil)
        }
    }

    struct ReadReport: Sendable {
        var table = FeatureTable()
        var errors: [String] = []
    }

    func read(days: Int = 365, latitude: Double, longitude: Double, calendar: Calendar = .current, keys: Set<String>? = nil) async -> FeatureTable {
        await readReport(days: days, latitude: latitude, longitude: longitude, calendar: calendar, keys: keys).table
    }

    /// Keep failed queries separate from empty, successfully read types.
    private func attempt(_ operation: @Sendable () async throws -> FeatureTable) async -> ReadReport {
        do { return ReadReport(table: try await operation()) }
        catch { return ReadReport(errors: [error.localizedDescription]) }
    }

    func readReport(days: Int = 365, latitude: Double, longitude: Double, calendar: Calendar = .current, keys: Set<String>? = nil) async -> ReadReport {
        let end = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: end)!)
        func wants(_ key: String) -> Bool { keys?.contains(key) ?? true }
        return await withTaskGroup(of: ReadReport.self) { group in
            for spec in Self.quantitySpecs where wants(spec.key) {
                group.addTask { await attempt { try await quantity(spec, from: start, to: end, calendar: calendar) } }
            }
            if [F.sleepHours, F.bedtime, F.wake, F.awakeMin, F.deepMin, F.remMin, F.coreMin, F.sleepEfficiency].contains(where: wants) {
                group.addTask { await attempt { try await sleep(from: start, to: end, calendar: calendar) } }
            }
            if wants(F.mindfulMin) {
                group.addTask { await attempt { try await mindful(from: start, to: end, calendar: calendar) } }
            }
            if wants(F.workoutMin) {
                group.addTask { await attempt { try await workouts(from: start, to: end, calendar: calendar) } }
            }
            if wants(F.nightListeningMin) {
                group.addTask { await attempt { try await nightListening(from: start, to: end, calendar: calendar) } }
            }
            if wants(F.activeHours) || wants(F.daylightWalkMin) {
                group.addTask { await attempt { try await hourlySteps(from: start, to: end, latitude: latitude, longitude: longitude, calendar: calendar) } }
            }
            if #available(iOS 18.0, *) {
                if wants(F.stateOfMindValence) || wants(F.stateOfMindCount) {
                    group.addTask { await attempt { try await stateOfMind(from: start, to: end, calendar: calendar) } }
                }
                if wants(F.phq9) || wants(F.gad7) {
                    group.addTask { await attempt { try await assessments(from: start, to: end, calendar: calendar) } }
                }
            }
            if #available(iOS 26.0, *), wants(F.medsLogged) || wants(F.medsSkipped) {
                group.addTask { await attempt { try await medications(from: start, to: end, calendar: calendar) } }
            }
            var all = ReadReport()
            for await report in group {
                all.table.merge(report.table)
                all.errors.append(contentsOf: report.errors)
            }
            return all
        }
    }

    // MARK: - Readers

    private func quantity(_ spec: QuantitySpec, from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let predicate = HKSamplePredicate.quantitySample(type: HKQuantityType(spec.id),
                                                         predicate: HKQuery.predicateForSamples(withStart: from, end: to))
        let query = HKStatisticsCollectionQueryDescriptor(predicate: predicate, options: spec.options,
                                                          anchorDate: calendar.startOfDay(for: from),
                                                          intervalComponents: DateComponents(day: 1))
        let result = try await query.result(for: store)
        var t = FeatureTable()
        result.enumerateStatistics(from: from, to: to) { stats, _ in
            let day = Day(stats.startDate, calendar: calendar)
            let q = spec.options.contains(.cumulativeSum) ? stats.sumQuantity() : stats.averageQuantity()
            if let q { t.set(spec.key, day, q.doubleValue(for: spec.unit)) }
            if let k = spec.minKey, let q = stats.minimumQuantity() { t.set(k, day, q.doubleValue(for: spec.unit)) }
            if let k = spec.maxKey, let q = stats.maximumQuantity() { t.set(k, day, q.doubleValue(for: spec.unit)) }
            if let k = spec.durationKey, let d = stats.duration() { t.set(k, day, d.doubleValue(for: .minute())) }
        }
        return t
    }

    private func samples(_ type: HKCategoryType, from: Date, to: Date) async throws -> [HKCategorySample] {
        let d = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: HKQuery.predicateForSamples(withStart: from, end: to))],
                                        sortDescriptors: [SortDescriptor(\.startDate)])
        return try await d.result(for: store)
    }

    /// Nights are assigned to the morning they end, with 18:00 as the day boundary.
    private func sleep(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let all = try await samples(HKCategoryType(.sleepAnalysis), from: calendar.date(byAdding: .hour, value: -12, to: from)!, to: to)
        // iPhone and Watch can both write a night; prefer the source with most asleep time per night.
        struct Night { var bySource: [String: [HKCategorySample]] = [:] }
        var nights: [Day: Night] = [:]
        for s in all {
            let day = Day(s.endDate.addingTimeInterval(6 * 3600), calendar: calendar)
            nights[day, default: Night()].bySource[s.sourceRevision.source.bundleIdentifier, default: []].append(s)
        }
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        var t = FeatureTable()
        for (day, night) in nights {
            func asleepMinutes(_ xs: [HKCategorySample]) -> Double {
                xs.filter { asleep.contains($0.value) }.map { $0.endDate.timeIntervalSince($0.startDate) / 60 }.reduce(0, +)
            }
            guard let samples = night.bySource.values.max(by: { asleepMinutes($0) < asleepMinutes($1) }) else { continue }
            let sleeping = samples.filter { asleep.contains($0.value) }
            guard let first = sleeping.map(\.startDate).min(), let last = sleeping.map(\.endDate).max() else { continue }
            let total = asleepMinutes(samples)
            func minutes(_ v: HKCategoryValueSleepAnalysis) -> Double {
                samples.filter { $0.value == v.rawValue }.map { $0.endDate.timeIntervalSince($0.startDate) / 60 }.reduce(0, +)
            }
            let awake = minutes(.awake)
            let dayStart = day.start(in: calendar)
            t.set(F.sleepHours, day, total / 60)
            t.set(F.bedtime, day, first.timeIntervalSince(dayStart.addingTimeInterval(-6 * 3600)) / 3600)
            t.set(F.wake, day, last.timeIntervalSince(dayStart) / 3600)
            t.set(F.awakeMin, day, awake)
            if minutes(.asleepDeep) + minutes(.asleepREM) > 0 {
                t.set(F.deepMin, day, minutes(.asleepDeep))
                t.set(F.remMin, day, minutes(.asleepREM))
                t.set(F.coreMin, day, minutes(.asleepCore))
            }
            let span = last.timeIntervalSince(first) / 60
            if span > 0 { t.set(F.sleepEfficiency, day, min(1, total / span)) }
            t.setText(F.timeZone, day, samples.compactMap { $0.metadata?[HKMetadataKeyTimeZone] as? String }.first)
        }
        return t
    }

    private func mindful(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        var mins: [Day: Double] = [:]
        for s in try await samples(HKCategoryType(.mindfulSession), from: from, to: to) {
            mins[Day(s.startDate, calendar: calendar), default: 0] += s.endDate.timeIntervalSince(s.startDate) / 60
        }
        var t = FeatureTable()
        for (d, v) in mins { t.set(F.mindfulMin, d, v) }
        return t
    }

    private func workouts(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let d = HKSampleQueryDescriptor(predicates: [.workout(HKQuery.predicateForSamples(withStart: from, end: to))],
                                        sortDescriptors: [SortDescriptor(\.startDate)])
        var mins: [Day: Double] = [:]
        for w in try await d.result(for: store) {
            mins[Day(w.startDate, calendar: calendar), default: 0] += w.duration / 60
        }
        var t = FeatureTable()
        for (day, m) in mins { t.set(F.workoutMin, day, m) }
        return t
    }

    /// From hourly steps, which Health keeps for years: hours that had real movement, and an
    /// estimate of minutes walking in daylight for people without an Apple Watch.
    private func hourlySteps(from: Date, to: Date, latitude: Double, longitude: Double, calendar: Calendar) async throws -> FeatureTable {
        let predicate = HKSamplePredicate.quantitySample(type: HKQuantityType(.stepCount),
                                                         predicate: HKQuery.predicateForSamples(withStart: from, end: to))
        let query = HKStatisticsCollectionQueryDescriptor(predicate: predicate, options: .cumulativeSum,
                                                          anchorDate: calendar.startOfDay(for: from),
                                                          intervalComponents: DateComponents(hour: 1))
        let result = try await query.result(for: store)
        var active: [Day: Double] = [:], daylight: [Day: Double] = [:]
        var sun: [Day: (Date?, Date?)] = [:]
        var perHour: [String: [Day: Double]] = [:]
        result.enumerateStatistics(from: from, to: to) { stats, _ in
            guard let steps = stats.sumQuantity()?.doubleValue(for: .count()) else { return }
            let day = Day(stats.startDate, calendar: calendar)
            perHour[F.stepsHour(calendar.component(.hour, from: stats.startDate)), default: [:]][day] = steps
            active[day, default: 0] += steps >= Self.activeHourSteps ? 1 : 0
            if sun[day] == nil {
                let s = Solar.times(date: stats.startDate, latitude: latitude, longitude: longitude, timeZone: calendar.timeZone)
                sun[day] = (s.sunrise, s.sunset)
            }
            if let rise = sun[day]?.0, let set = sun[day]?.1, stats.startDate >= rise.addingTimeInterval(-1800), stats.startDate < set {
                // About 100 steps a minute of walking; only clearly walking hours count.
                if steps >= 300 { daylight[day, default: 0] += min(60, steps / 100) }
            }
        }
        var t = FeatureTable()
        for (d, v) in active { t.set(F.activeHours, d, v) }
        for d in active.keys { t.set(F.daylightWalkMin, d, daylight[d] ?? 0) }
        for (k, days) in perHour { for (d, v) in days { t.set(k, d, v) } }
        return t
    }

    static let activeHourSteps = 250.0

    /// Minutes of headphone listening between 23:00 and 05:00, assigned to the night's morning.
    private func nightListening(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let type = HKQuantityType(.headphoneAudioExposure)
        let d = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: from, end: to))],
                                        sortDescriptors: [])
        var mins: [Day: Double] = [:]
        for s in try await d.result(for: store) {
            var cursor = s.startDate
            while cursor < s.endDate {
                let next = min(s.endDate, cursor.addingTimeInterval(60))
                let hour = calendar.component(.hour, from: cursor)
                if hour >= 23 || hour < 5 {
                    mins[Day(cursor.addingTimeInterval(6 * 3600), calendar: calendar), default: 0] += next.timeIntervalSince(cursor) / 60
                }
                cursor = next
            }
        }
        var t = FeatureTable()
        for (day, v) in mins { t.set(F.nightListeningMin, day, v.rounded()) }
        return t
    }

    @available(iOS 18.0, *)
    private func stateOfMind(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let d = HKSampleQueryDescriptor(predicates: [.stateOfMind(HKQuery.predicateForSamples(withStart: from, end: to))],
                                        sortDescriptors: [])
        var sums: [Day: (Double, Double)] = [:]
        for s in try await d.result(for: store) {
            let day = Day(s.startDate, calendar: calendar)
            let cur = sums[day] ?? (0, 0)
            sums[day] = (cur.0 + s.valence, cur.1 + 1)
        }
        var t = FeatureTable()
        for (day, v) in sums { t.set(F.stateOfMindValence, day, v.0 / v.1); t.set(F.stateOfMindCount, day, v.1) }
        return t
    }

    @available(iOS 18.0, *)
    private func assessments(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let p = HKQuery.predicateForSamples(withStart: from, end: to)
        var t = FeatureTable()
        for s in try await HKSampleQueryDescriptor(predicates: [.phq9Assessment(p)], sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store) {
            t.set(F.phq9, Day(s.startDate, calendar: calendar), Double(s.score))
        }
        for s in try await HKSampleQueryDescriptor(predicates: [.gad7Assessment(p)], sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store) {
            t.set(F.gad7, Day(s.startDate, calendar: calendar), Double(s.score))
        }
        return t
    }

    @available(iOS 26.0, *)
    private func medications(from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        let p = HKQuery.predicateForSamples(withStart: from, end: to)
        let events = try await HKSampleQueryDescriptor(predicates: [.sample(type: HKObjectType.medicationDoseEventType(), predicate: p)],
                                                       sortDescriptors: []).result(for: store)
            .compactMap { $0 as? HKMedicationDoseEvent }
        var taken: [Day: Double] = [:], skipped: [Day: Double] = [:]
        for e in events where e.scheduleType == .schedule {
            let day = Day(e.scheduledDate ?? e.startDate, calendar: calendar)
            switch e.logStatus {
            case .taken: taken[day, default: 0] += 1; skipped[day, default: 0] += 0
            case .skipped, .notInteracted, .notificationNotSent: skipped[day, default: 0] += 1; taken[day, default: 0] += 0
            default: break
            }
        }
        var t = FeatureTable()
        for (d, v) in taken { t.set(F.medsLogged, d, v) }
        for (d, v) in skipped { t.set(F.medsSkipped, d, v) }
        return t
    }
}

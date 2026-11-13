import Foundation
import HealthKit

/// Reads every available Health type as one value per day. Missing types never crash;
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

    static let quantitySpecs: [QuantitySpec] = {
        let perMin = HKUnit.count().unitDivided(by: .minute())
        let mps = HKUnit.meter().unitDivided(by: .second())
        var s: [QuantitySpec] = [
            .init(key: F.steps, id: .stepCount, options: .cumulativeSum, unit: .count()),
            .init(key: F.walkRunDistance, id: .distanceWalkingRunning, options: .cumulativeSum, unit: .meterUnit(with: .kilo)),
            .init(key: F.flights, id: .flightsClimbed, options: .cumulativeSum, unit: .count()),
            .init(key: F.walkingSpeed, id: .walkingSpeed, options: .discreteAverage, unit: mps),
            .init(key: F.stepLength, id: .walkingStepLength, options: .discreteAverage, unit: .meter()),
            .init(key: F.walkAsymmetry, id: .walkingAsymmetryPercentage, options: .discreteAverage, unit: .percent()),
            .init(key: F.doubleSupport, id: .walkingDoubleSupportPercentage, options: .discreteAverage, unit: .percent()),
            .init(key: F.stairUpSpeed, id: .stairAscentSpeed, options: .discreteAverage, unit: mps),
            .init(key: F.stairDownSpeed, id: .stairDescentSpeed, options: .discreteAverage, unit: mps),
            .init(key: F.sixMinWalk, id: .sixMinuteWalkTestDistance, options: .discreteAverage, unit: .meter()),
            .init(key: F.walkingSteadiness, id: .appleWalkingSteadiness, options: .discreteAverage, unit: .percent()),
            .init(key: F.exerciseMin, id: .appleExerciseTime, options: .cumulativeSum, unit: .minute()),
            .init(key: F.standMin, id: .appleStandTime, options: .cumulativeSum, unit: .minute()),
            .init(key: F.activeEnergy, id: .activeEnergyBurned, options: .cumulativeSum, unit: .kilocalorie()),
            .init(key: F.physicalEffort, id: .physicalEffort, options: .discreteAverage,
                  unit: .kilocalorie().unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .hour()))),
            .init(key: F.daylightMin, id: .timeInDaylight, options: .cumulativeSum, unit: .minute()),
            .init(key: F.heartRate, id: .heartRate, options: [.discreteAverage, .discreteMin, .discreteMax], unit: perMin,
                  minKey: F.heartRateMin, maxKey: F.heartRateMax),
            .init(key: F.restingHR, id: .restingHeartRate, options: .discreteAverage, unit: perMin),
            .init(key: F.walkingHR, id: .walkingHeartRateAverage, options: .discreteAverage, unit: perMin),
            .init(key: F.hrv, id: .heartRateVariabilitySDNN, options: .discreteAverage, unit: .secondUnit(with: .milli)),
            .init(key: F.hrRecovery, id: .heartRateRecoveryOneMinute, options: .discreteAverage, unit: perMin),
            .init(key: F.vo2max, id: .vo2Max, options: .discreteAverage, unit: HKUnit(from: "ml/kg*min")),
            .init(key: F.respRate, id: .respiratoryRate, options: .discreteAverage, unit: perMin),
            .init(key: F.spo2, id: .oxygenSaturation, options: .discreteAverage, unit: .percent()),
            .init(key: F.wristTemp, id: .appleSleepingWristTemperature, options: .discreteAverage, unit: .degreeCelsius()),
            .init(key: F.envSound, id: .environmentalAudioExposure, options: .discreteAverage, unit: .decibelAWeightedSoundPressureLevel()),
            .init(key: F.headphoneSound, id: .headphoneAudioExposure, options: [.discreteAverage, .duration],
                  unit: .decibelAWeightedSoundPressureLevel(), durationKey: F.headphoneMin),
            .init(key: F.caffeine, id: .dietaryCaffeine, options: .cumulativeSum, unit: .gramUnit(with: .milli)),
            .init(key: F.alcohol, id: .numberOfAlcoholicBeverages, options: .cumulativeSum, unit: .count()),
        ]
        s += [
            .init(key: F.height, id: .height, options: .discreteAverage, unit: .meterUnit(with: .centi)),
            .init(key: F.bodyMass, id: .bodyMass, options: .discreteAverage, unit: .gramUnit(with: .kilo)),
            .init(key: F.basalEnergy, id: .basalEnergyBurned, options: .cumulativeSum, unit: .kilocalorie()),
            .init(key: F.cyclingDistance, id: .distanceCycling, options: .cumulativeSum, unit: .meterUnit(with: .kilo)),
            .init(key: F.uvExposure, id: .uvExposure, options: .discreteAverage, unit: .count()),
            .init(key: F.water, id: .dietaryWater, options: .cumulativeSum, unit: .liter()),
            .init(key: F.soundReduction, id: .environmentalSoundReduction, options: .discreteAverage, unit: .decibelAWeightedSoundPressureLevel()),
            .init(key: F.falls, id: .numberOfTimesFallen, options: .cumulativeSum, unit: .count()),
        ]
        if #available(iOS 18.0, *) {
            s.append(.init(key: F.workoutEffort, id: .workoutEffortScore, options: .discreteAverage, unit: .appleEffortScore()))
        }
        if #available(iOS 18.0, *) {
            s.append(.init(key: F.breathingDisturbances, id: .appleSleepingBreathingDisturbances, options: .discreteAverage, unit: .count()))
        }
        return s
    }()

    /// Category types counted per day, with the raw values that mean "present".
    static let countedCategories: [(key: String, id: HKCategoryTypeIdentifier, present: Set<Int>?)] = [
        (F.hrHighEvents, .highHeartRateEvent, nil),
        (F.hrLowEvents, .lowHeartRateEvent, nil),
        (F.irregularRhythmEvents, .irregularHeartRhythmEvent, nil),
        (F.loudEnvEvents, .environmentalAudioExposureEvent, nil),
        (F.loudHeadphoneEvents, .headphoneAudioExposureEvent, nil),
        // Symptom logs can say "not present"; count only real entries.
        (F.symptomFatigue, .fatigue, Set([HKCategoryValueSeverity.unspecified, .mild, .moderate, .severe].map(\.rawValue))),
        (F.symptomHeadache, .headache, Set([HKCategoryValueSeverity.unspecified, .mild, .moderate, .severe].map(\.rawValue))),
        (F.symptomSleepChanges, .sleepChanges, [HKCategoryValuePresence.present.rawValue]),
        (F.symptomMoodChanges, .moodChanges, [HKCategoryValuePresence.present.rawValue]),
        (F.symptomAppetiteChanges, .appetiteChanges, [HKCategoryValueAppetiteChanges.decreased.rawValue,
                                                      HKCategoryValueAppetiteChanges.increased.rawValue]),
        (F.handwashing, .handwashingEvent, nil),
        (F.standHours, .appleStandHour, [HKCategoryValueAppleStandHour.stood.rawValue]),
        (F.lowFitnessEvents, .lowCardioFitnessEvent, nil),
        (F.toothbrushing, .toothbrushingEvent, nil),
    ]

    static var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>(quantitySpecs.map { HKQuantityType($0.id) })
        for c in countedCategories { types.insert(HKCategoryType(c.id)) }
        if #available(iOS 18.0, *) { types.insert(HKCategoryType(.sleepApneaEvent)) }
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKCharacteristicType(.dateOfBirth))
        types.insert(HKCharacteristicType(.biologicalSex))
        types.insert(HKCategoryType(.mindfulSession))
        types.insert(HKObjectType.workoutType())
        if #available(iOS 18.0, *) {
            types.insert(HKObjectType.stateOfMindType())
            types.insert(HKScoredAssessmentType(.PHQ9))
            types.insert(HKScoredAssessmentType(.GAD7))
        }
        // Medication dose events are not allowed in this request (HealthKit throws). Medications
        // use their own per-medication permission, asked from Settings with requestMedicationAccess().
        return types
    }

    let store = HKHealthStore()

    func requestAuthorization() async throws {
        // Ask only for types this device and OS allow, so one unsupported type never crashes the request.
        let allowed = Self.readTypes.filter { !Self.disallowed.contains($0.identifier) }
        try await store.requestAuthorization(toShare: [], read: allowed)
    }

    /// Types HealthKit refuses in a plain read request on some systems.
    static let disallowed: Set<String> = ["HKMedicationDoseEventTypeIdentifierMedicationDoseEvent"]

    /// Medications have their own sheet, one medication at a time. Shown from a tap in Settings.
    func requestMedicationAccess() async {
        if #available(iOS 26.0, *) {
            try? await store.requestPerObjectReadAuthorization(for: HKObjectType.userAnnotatedMedicationType(), predicate: nil)
        }
    }

    /// Reads everything concurrently. Returns the table plus how many days each feature returned.
    func read(days: Int = 365, latitude: Double, longitude: Double, calendar: Calendar = .current) async -> FeatureTable {
        let end = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: end)!)
        return await withTaskGroup(of: FeatureTable.self) { group in
            for spec in Self.quantitySpecs {
                group.addTask { (try? await quantity(spec, from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            }
            for c in Self.countedCategories {
                group.addTask { (try? await categoryCount(c.key, c.id, present: c.present, from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            }
            group.addTask { (try? await sleep(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            group.addTask { (try? await mindful(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            group.addTask { (try? await workouts(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            group.addTask { (try? await nightListening(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            group.addTask { (try? await hourlySteps(from: start, to: end, latitude: latitude, longitude: longitude, calendar: calendar)) ?? FeatureTable() }
            if #available(iOS 18.0, *) {
                group.addTask { (try? await categoryCount(F.breathingEvents, .sleepApneaEvent, present: nil, from: start, to: end, calendar: calendar)) ?? FeatureTable() }
                group.addTask { (try? await stateOfMind(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
                group.addTask { (try? await assessments(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            }
            if #available(iOS 26.0, *) {
                group.addTask { (try? await medications(from: start, to: end, calendar: calendar)) ?? FeatureTable() }
            }
            var all = FeatureTable()
            for await t in group { all.merge(t) }
            all.merge(personalDetails(calendar: calendar))
            return all
        }
    }

    // MARK: - Readers

    /// Age and biological sex, as Saunasense reads them. Stored on today's date.
    private func personalDetails(calendar: Calendar) -> FeatureTable {
        var t = FeatureTable()
        let today = Day(Date(), calendar: calendar)
        if let dob = try? store.dateOfBirthComponents(), let birth = calendar.date(from: dob),
           let years = calendar.dateComponents([.year], from: birth, to: Date()).year {
            t.set(F.age, today, Double(years))
        }
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .female: t.setText(F.sex, today, "Female")
            case .male: t.setText(F.sex, today, "Male")
            case .other: t.setText(F.sex, today, "Other")
            default: break
            }
        }
        return t
    }

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

    private func categoryCount(_ key: String, _ id: HKCategoryTypeIdentifier, present: Set<Int>?, from: Date, to: Date, calendar: Calendar) async throws -> FeatureTable {
        var counts: [Day: Double] = [:]
        for s in try await samples(HKCategoryType(id), from: from, to: to) where present?.contains(s.value) ?? true {
            counts[Day(s.startDate, calendar: calendar), default: 0] += 1
        }
        var t = FeatureTable()
        for (d, v) in counts { t.set(key, d, v) }
        return t
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
        var count: [Day: Double] = [:], mins: [Day: Double] = [:], kinds: [Day: Set<UInt>] = [:]
        for w in try await d.result(for: store) {
            let day = Day(w.startDate, calendar: calendar)
            count[day, default: 0] += 1
            mins[day, default: 0] += w.duration / 60
            kinds[day, default: []].insert(w.workoutActivityType.rawValue)
        }
        var t = FeatureTable()
        for (day, c) in count {
            t.set(F.workoutCount, day, c)
            t.set(F.workoutMin, day, mins[day])
            t.set(F.workoutTypes, day, Double(kinds[day]?.count ?? 0))
        }
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
        result.enumerateStatistics(from: from, to: to) { stats, _ in
            guard let steps = stats.sumQuantity()?.doubleValue(for: .count()) else { return }
            let day = Day(stats.startDate, calendar: calendar)
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
        for s in try await HKSampleQueryDescriptor(predicates: [.phq9Assessment(p)], sortDescriptors: []).result(for: store) {
            t.set(F.phq9, Day(s.startDate, calendar: calendar), Double(s.score))
        }
        for s in try await HKSampleQueryDescriptor(predicates: [.gad7Assessment(p)], sortDescriptors: []).result(for: store) {
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

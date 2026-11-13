import Foundation

/// Synthetic patient Perttu: 60 days of every feature, deterministic.
/// Days 0–44 steady, a cold on 30–32, a trip on 38–40, drift from day 45.
nonisolated enum DemoSource {
    static let dayCount = 60
    static let firstDay = Day(year: 2026, month: 9, day: 30)
    static let homeTimeZone = "Europe/Helsinki"
    static let tripTimeZone = "Europe/Stockholm"
    static let latitude = 60.17, longitude = 24.94   // Helsinki

    static func day(_ n: Int) -> Day { firstDay + n }
    static func number(of day: Day) -> Int { day - firstDay }

    static func table() -> FeatureTable {
        var t = FeatureTable()
        let helsinki = TimeZone(identifier: homeTimeZone)!
        for n in 0..<dayCount { add(n, to: &t, tz: helsinki) }
        return t
    }

    // MARK: - Seeded noise

    /// SplitMix64 on (feature, day) so every value is stable no matter the order of generation.
    private static func unit(_ key: String, _ n: Int, _ salt: UInt64 = 0) -> Double {
        var h: UInt64 = 0xcbf29ce484222325
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        var z = h &+ UInt64(n) &* 0x9E3779B97F4A7C15 &+ salt &* 0xD1B54A32D192ED03
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return (Double(z >> 11) + 0.5) / Double(1 << 53)
    }

    private static func normal(_ key: String, _ n: Int) -> Double {
        let u1 = unit(key, n, 1), u2 = unit(key, n, 2)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    private static func around(_ key: String, _ n: Int, _ mean: Double, _ sd: Double) -> Double {
        mean + sd * normal(key, n)
    }

    private static func uniform(_ key: String, _ n: Int, _ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * unit(key, n, 3)
    }

    private static func chance(_ key: String, _ n: Int, _ p: Double) -> Bool { unit(key, n, 4) < p }

    // MARK: - One day

    private static func add(_ n: Int, to t: inout FeatureTable, tz: TimeZone) {
        let d = day(n)
        let cold = (30...32).contains(n)
        // Single short nights before the drift. Perttu did slow breathing on each and was back the next days.
        let dip = [15, 21, 27, 35].contains(n)
        let trip = (38...40).contains(n)
        // Drift starts clearly on day 45 and is at full strength by day 46.
        let k = n >= 45 ? min(1.0, 0.75 + Double(n - 45) * 0.25) : 0.0
        func mix(_ steady: Double, _ drifted: Double) -> Double { steady + (drifted - steady) * k }

        // Sleep. Bedtime as hours after 18:00 the previous day, wake as hours after midnight.
        let bedtime = around("bed", n, mix(5.33, 6.95), mix(0.22, 1.0)) + (trip ? -0.4 : 0) + (dip ? 2.2 : 0)
        let wake = around("wake", n, mix(7.17, 7.55), mix(0.18, 0.55)) + (cold ? 0.4 : 0)
        let inBed = (wake + 6) - bedtime
        let awakeMin = max(5, around("awake", n, mix(24, 62), mix(6, 14)) + (cold ? 15 : 0) + (dip ? 35 : 0))
        let sleep = max(3.5, inBed - awakeMin / 60)
        t.set(F.bedtime, d, bedtime)
        t.set(F.wake, d, wake)
        t.set(F.awakeMin, d, awakeMin.rounded())
        t.set(F.sleepHours, d, sleep)
        let deep = sleep * 60 * around("deep", n, mix(0.16, 0.12), 0.015)
        let rem = sleep * 60 * around("rem", n, mix(0.23, 0.19), 0.02)
        t.set(F.deepMin, d, deep.rounded())
        t.set(F.remMin, d, rem.rounded())
        t.set(F.coreMin, d, (sleep * 60 - deep - rem).rounded())
        t.set(F.sleepEfficiency, d, sleep / inBed)
        t.setText(F.timeZone, d, trip ? tripTimeZone : homeTimeZone)

        // Movement.
        var steps = around("steps", n, mix(6000, 3000), mix(850, 500))
        if cold { steps = around("steps-cold", n, 3400, 400) }
        if dip { steps = around("steps-dip", n, 3600, 300) }
        if trip { steps = around("steps-trip", n, 9800, 900) }
        steps = max(400, steps)
        t.set(F.steps, d, steps.rounded())
        t.set(F.walkRunDistance, d, steps * 0.74 / 1000)
        t.set(F.flights, d, max(0, around("flights", n, mix(9, 4), 3)).rounded())
        t.set(F.walkingSpeed, d, around("speed", n, mix(1.31, 1.21), 0.035) - (cold ? 0.06 : 0))
        t.set(F.stepLength, d, around("steplen", n, mix(0.73, 0.70), 0.012))
        t.set(F.walkAsymmetry, d, max(0, around("asym", n, 0.021, 0.006)))
        t.set(F.doubleSupport, d, around("dsupport", n, mix(0.275, 0.288), 0.007))
        t.set(F.stairUpSpeed, d, around("stairup", n, mix(0.46, 0.42), 0.03))
        t.set(F.stairDownSpeed, d, around("stairdown", n, mix(0.55, 0.51), 0.03))
        if n % 7 == 3 { t.set(F.sixMinWalk, d, around("6mw", n, mix(540, 515), 8).rounded()) }
        if n % 7 == 5 { t.set(F.walkingSteadiness, d, around("steady", n, 0.96, 0.01)) }
        var exercise = max(0, around("exercise", n, mix(28, 9), mix(8, 4)))
        if cold { exercise = uniform("exercise-cold", n, 2, 6) }
        if trip { exercise = around("exercise-trip", n, 42, 6) }
        t.set(F.exerciseMin, d, exercise.rounded())
        t.set(F.standMin, d, max(30, around("stand", n, mix(190, 120), 25)).rounded())
        t.set(F.activeEnergy, d, max(80, around("energy", n, mix(430, 250), 50) * (cold ? 0.6 : 1) * (trip ? 1.4 : 1)).rounded())
        t.set(F.physicalEffort, d, max(1.2, around("effort", n, mix(2.2, 1.7), 0.2)))
        var daylight = uniform("daylight", n, 25, 35)
        if n >= 45 { daylight = mix(daylight, uniform("daylight-drift", n, 3, 9)) }
        if cold { daylight = uniform("daylight-cold", n, 6, 12) }
        if dip { daylight = uniform("daylight-dip", n, 6, 12) }
        if trip { daylight = uniform("daylight-trip", n, 40, 60) }
        t.set(F.daylightMin, d, daylight.rounded())
        // Hourly steps, spread over waking hours with a morning and an afternoon peak.
        let wakeHour = Int((7.17 + (n >= 45 ? 0.4 : 0)).rounded())
        let bedHour = min(23, Int((18 + bedtime).truncatingRemainder(dividingBy: 24)))
        var weights = [Double](repeating: 0, count: 24)
        for h in 0..<24 where h >= wakeHour && (h <= bedHour || bedHour < wakeHour) {
            weights[h] = 0.4 + (h == 8 || h == 17 ? 1.6 : 0) + (h == 12 ? 1 : 0) + unit("hw\(h)", n) * 0.8
        }
        let wsum = max(weights.reduce(0, +), 1)
        for h in 0..<24 where weights[h] > 0 { t.set(F.stepsHour(h), d, (steps * weights[h] / wsum).rounded()) }
        var activeH = around("activeh", n, mix(9, 5), mix(1, 1.2))
        if cold { activeH = around("activeh-cold", n, 4, 0.6) }
        if trip { activeH = around("activeh-trip", n, 12, 0.8) }
        t.set(F.activeHours, d, max(1, activeH).rounded())
        t.set(F.daylightWalkMin, d, max(0, daylight * 0.8 + around("dwalk", n, 0, 4)).rounded())

        // Heart and body.
        let rhr = around("rhr", n, mix(58, 60), 1.1) + (cold ? 7 : 0)
        t.set(F.restingHR, d, rhr.rounded())
        t.set(F.heartRate, d, around("hr", n, mix(72, 74), 2).rounded() + (cold ? 7 : 0))
        t.set(F.heartRateMin, d, (rhr - 6 + around("hrmin", n, 0, 1.5)).rounded())
        t.set(F.heartRateMax, d, around("hrmax", n, mix(138, 118), 9).rounded())
        t.set(F.walkingHR, d, around("walkhr", n, 96, 3).rounded() + (cold ? 6 : 0))
        t.set(F.hrv, d, max(15, around("hrv", n, mix(48, 42), 3.5) - (cold ? 9 : 0)).rounded())
        if n % 3 == 0 { t.set(F.hrRecovery, d, around("hrrec", n, mix(26, 23), 2).rounded()) }
        if n % 7 == 1 { t.set(F.vo2max, d, around("vo2", n, mix(41.5, 40.8), 0.3)) }
        t.set(F.respRate, d, around("resp", n, 14.4, 0.35) + (cold ? 1.8 : 0))
        t.set(F.spo2, d, min(1, around("spo2", n, 0.97, 0.006)))
        t.set(F.breathingDisturbances, d, max(0, around("bdist", n, 3, 1.2)) + (cold ? 2.5 : 0))
        t.set(F.wristTemp, d, around("wtemp", n, 35.62, 0.11) + (cold ? 0.7 : 0))

        // Sound.
        t.set(F.envSound, d, around("env", n, mix(63, 56), 3).rounded())
        t.set(F.headphoneSound, d, around("hp", n, 68, 3).rounded())
        t.set(F.headphoneMin, d, max(0, around("hpmin", n, mix(55, 120), 20)).rounded())
        t.set(F.nightListeningMin, d, max(0, mix(uniform("night", n, 0, 6), uniform("night-drift", n, 35, 85))).rounded())
        t.set(F.loudEnvEvents, d, chance("loudenv", n, 0.08) ? 1 : 0)
        t.set(F.loudHeadphoneEvents, d, chance("loudhp", n, 0.04) ? 1 : 0)

        // Workouts and other Health.
        let workout = n < 45 ? chance("workout", n, 0.45) : chance("workout-drift", n, 0.1)
        let workouts = trip ? 0 : (workout && !cold ? 1.0 : 0.0)
        t.set(F.workoutCount, d, workouts)
        t.set(F.workoutMin, d, workouts > 0 ? around("wmin", n, 36, 8).rounded() : 0)
        t.set(F.workoutTypes, d, workouts)
        t.set(F.mindfulMin, d, dip ? 5 : (n < 45 && chance("mindful", n, 0.25) ? 5 : 0))
        t.set(F.hrHighEvents, d, 0)
        t.set(F.hrLowEvents, d, 0)
        t.set(F.irregularRhythmEvents, d, 0)
        t.set(F.handwashing, d, around("wash", n, 6, 1.5).rounded())
        t.set(F.toothbrushing, d, n >= 45 && chance("brush", n, 0.4) ? 1 : 2)
        t.set(F.caffeine, d, max(0, around("caffeine", n, mix(190, 260), 40)).rounded())
        if chance("alcohol", n, 0.12) { t.set(F.alcohol, d, 1) }
        t.set(F.bodyMass, d, around("mass", n, 78.4, 0.3))
        if n == 0 { t.set(F.height, d, 181); t.set(F.age, d, 38); t.setText(F.sex, d, "Male") }
        t.set(F.basalEnergy, d, around("basal", n, 1720, 25).rounded())
        t.set(F.cyclingDistance, d, n < 45 && chance("cycle", n, 0.3) ? around("cyckm", n, 6, 1.5) : 0)
        t.set(F.uvExposure, d, max(0, around("uv", n, 1.2, 0.4)))
        t.set(F.water, d, max(0.3, around("water", n, mix(1.6, 1.1), 0.3)))
        t.set(F.soundReduction, d, around("anc", n, 18, 4).rounded())
        t.set(F.falls, d, 0)
        if workouts > 0 { t.set(F.workoutEffort, d, around("effortscore", n, 5.5, 1)) }
        t.set(F.standHours, d, max(3, around("standh", n, mix(11, 7), 1.2)).rounded())
        t.set(F.lowFitnessEvents, d, 0)
        t.set(F.breathingEvents, d, 0)
        t.set(F.medsLogged, d, 1)
        t.set(F.medsSkipped, d, n >= 45 && chance("skip", n, 0.35) ? 1 : 0)
        // Logged only now and then, like a real person.
        if cold { t.set(F.symptomFatigue, d, 1); t.set(F.symptomHeadache, d, n == 31 ? 1 : 0) }
        if n == 52 { t.set(F.symptomSleepChanges, d, 1) }
        if [4, 11, 19, 26].contains(n) { t.set(F.stateOfMindValence, d, around("som", n, 0.35, 0.1)); t.set(F.stateOfMindCount, d, 1) }
        if n == 0 { t.set(F.phq9, d, 6); t.set(F.gad7, d, 4) }
        if n == 0 { t.set(F.symptomMoodChanges, d, 0); t.set(F.symptomAppetiteChanges, d, 0) }

        // Core Motion (hours per day). The real source keeps only 7 days; the demo shows all.
        var still = around("still", n, mix(13.2, 16.8), 0.7)
        if cold { still = around("still-cold", n, 17.5, 0.5) }
        t.set(F.stillHours, d, still)
        t.set(F.walkingHours, d, max(0.1, around("walkh", n, mix(1.25, 0.55), 0.2) * (trip ? 1.8 : 1) * (cold ? 0.5 : 1)))
        t.set(F.runningHours, d, n < 45 && chance("run", n, 0.2) ? around("runh", n, 0.4, 0.08) : 0)
        t.set(F.automotiveHours, d, max(0, around("car", n, mix(0.9, 0.3), 0.25)) + (trip && n == 38 ? 2.5 : 0))
        t.set(F.cyclingHours, d, n < 45 && chance("cycle", n, 0.3) ? around("cyc", n, 0.5, 0.1) : 0)

        // Location, derived numbers only.
        var away = uniform("away", n, 4, 6)
        var places = (uniform("places", n, 2, 5)).rounded(.down)
        var maxKm = around("maxkm", n, 6, 2)
        if n >= 45 {
            away = mix(away, uniform("away-drift", n, 0.4, 1.6))
            places = k >= 1 ? (chance("places-drift", n, 0.4) ? 1 : 0) : max(1, places - 1)
            maxKm = mix(maxKm, uniform("maxkm-drift", n, 0.3, 1.5))
        }
        if cold { away = uniform("away-cold", n, 0.2, 0.8); places = 1; maxKm = 0.8 }
        if trip { away = uniform("away-trip", n, 12, 15); places = 5; maxKm = 400 + uniform("trip-km", n, 0, 12) }
        t.set(F.awayHours, d, away)
        t.set(F.homeHours, d, 24 - away)
        t.set(F.placesVisited, d, max(0, places))
        t.set(F.maxKmFromHome, d, max(0.1, maxKm))
        t.set(F.locationEntropy, d, places <= 1 ? (places == 0 ? 0 : 0.15) : log(places) * 0.9)

        // Sun, worked out locally.
        let sun = Solar.times(date: d.start(in: calendar(tz)), latitude: latitude, longitude: longitude, timeZone: tz)
        t.set(F.dayLengthH, d, sun.dayLengthHours)
        if let rise = sun.sunrise { t.set(F.sunrise, d, hoursAfterMidnight(rise, tz)) }
        if let set = sun.sunset { t.set(F.sunset, d, hoursAfterMidnight(set, tz)) }

        // Calendar and Photos (P2).
        t.set(F.calendarEvents, d, max(0, around("cal", n, mix(2.6, 1.1), 1)).rounded())
        t.set(F.eventHours, d, max(0, around("calh", n, mix(2.2, 0.8), 0.7)))
        let photos = max(0, around("photos", n, mix(4, 0.6), 2).rounded()) + (trip ? 18 : 0)
        t.set(F.photosTaken, d, photos)
        t.set(F.photosAwayFromHome, d, (photos * (n >= 45 ? 0.1 : 0.7)).rounded())
    }

    private static func calendar(_ tz: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    private static func hoursAfterMidnight(_ date: Date, _ tz: TimeZone) -> Double {
        let c = calendar(tz).dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }
}

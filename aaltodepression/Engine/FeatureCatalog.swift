import Foundation

/// Where a signal comes from. Drives the grouping on the Data screen.
nonisolated enum SignalSource: String, Sendable, CaseIterable {
    case health = "Apple Health"
    case motion = "Motion"
    case location = "Location"
    case computed = "Worked out on this phone"
    case selfReport = "Your own answers"
}

nonisolated enum SignalDevice: String, Sendable {
    case iPhone, watch = "Apple Watch", manual = "Logged by you", phone = "This phone"
}

nonisolated enum Priority: Int, Sendable, Comparable {
    case p0 = 0, p1 = 1, p2 = 2
    static func < (a: Priority, b: Priority) -> Bool { a.rawValue < b.rawValue }
}

/// How a value is written out for people.
nonisolated enum ValueFormat: Sendable {
    case integer(String)           // "6 012 steps"
    case decimal(Int, String)      // fraction digits, unit
    case clockAfter18              // hours after 18:00 the previous day -> "23:20"
    case clockAfterMidnight        // hours after midnight -> "07:10"
    case hoursMinutes              // hours -> "7 h 18 min"
    case minutes                   // minutes -> "25 min"
    case percent(Int)              // value already in percent
    case fractionPercent(Int)      // 0...1 -> percent
    case text
}

nonisolated struct SignalInfo: Sendable, Identifiable {
    let key: String
    let title: String
    let source: SignalSource
    let device: SignalDevice
    let priority: Priority
    let format: ValueFormat
    var note: String? = nil
    var id: String { key }
}

/// Feature keys. Some keys are no longer read (see FeatureCatalog.all); they stay defined because
/// older screens still name them, and a key without data is simply unknown.
nonisolated enum F {
    // Movement (HealthKit quantity)
    static let steps = "steps", walkRunDistance = "walkRunDistance", flights = "flights"
    static let walkingSpeed = "walkingSpeed", stepLength = "stepLength", walkAsymmetry = "walkAsymmetry"
    static let doubleSupport = "doubleSupport", stairUpSpeed = "stairUpSpeed", stairDownSpeed = "stairDownSpeed"
    static let sixMinWalk = "sixMinWalk", walkingSteadiness = "walkingSteadiness"
    static let exerciseMin = "exerciseMin", standMin = "standMin", activeEnergy = "activeEnergy"
    static let physicalEffort = "physicalEffort", daylightMin = "daylightMin"
    // Heart and body
    static let heartRate = "heartRate", heartRateMin = "heartRateMin", heartRateMax = "heartRateMax"
    static let restingHR = "restingHR", walkingHR = "walkingHR", hrv = "hrv", hrRecovery = "hrRecovery"
    static let vo2max = "vo2max", respRate = "respRate", spo2 = "spo2"
    static let breathingDisturbances = "breathingDisturbances", wristTemp = "wristTemp"
    // Sound
    static let envSound = "envSound", headphoneSound = "headphoneSound", headphoneMin = "headphoneMin"
    static let nightListeningMin = "nightListeningMin"
    // Manual
    static let caffeine = "caffeine", alcohol = "alcohol"
    // Sleep
    static let sleepHours = "sleepHours", bedtime = "bedtime", wake = "wake", awakeMin = "awakeMin"
    static let deepMin = "deepMin", remMin = "remMin", coreMin = "coreMin", sleepEfficiency = "sleepEfficiency"
    static let timeZone = "timeZone"
    // Other HealthKit
    static let dietaryEnergy = "dietaryEnergy", dietaryWater = "dietaryWater", dietaryProtein = "dietaryProtein", dietaryCarbs = "dietaryCarbs", dietaryFat = "dietaryFat"
    static let mindfulMin = "mindfulMin"
    static let workoutCount = "workoutCount", workoutMin = "workoutMin", workoutTypes = "workoutTypes"
    static let hrHighEvents = "hrHighEvents", hrLowEvents = "hrLowEvents", irregularRhythmEvents = "irregularRhythmEvents"
    static let loudEnvEvents = "loudEnvEvents", loudHeadphoneEvents = "loudHeadphoneEvents"
    static let symptomFatigue = "symptomFatigue", symptomSleepChanges = "symptomSleepChanges"
    static let symptomMoodChanges = "symptomMoodChanges", symptomAppetiteChanges = "symptomAppetiteChanges"
    static let symptomHeadache = "symptomHeadache"
    static let handwashing = "handwashing", toothbrushing = "toothbrushing"
    static let stateOfMindValence = "stateOfMindValence", stateOfMindCount = "stateOfMindCount"
    static let phq9 = "phq9", gad7 = "gad7"
    static let medsLogged = "medsLogged", medsSkipped = "medsSkipped"
    /// Steps in hour h (0 = midnight to 1), for the rhythm chart.
    static func stepsHour(_ h: Int) -> String { "stepsH\(h)" }
    static let activeHours = "activeHours", daylightWalkMin = "daylightWalkMin"
    static let height = "height", age = "age", sex = "sex"
    static let bodyMass = "bodyMass", basalEnergy = "basalEnergy", cyclingDistance = "cyclingDistance"
    static let uvExposure = "uvExposure", water = "water", soundReduction = "soundReduction", falls = "falls"
    static let workoutEffort = "workoutEffort", standHours = "standHours", lowFitnessEvents = "lowFitnessEvents"
    static let breathingEvents = "breathingEvents"
    // Motion
    static let stillHours = "stillHours", walkingHours = "walkingHours", runningHours = "runningHours"
    static let automotiveHours = "automotiveHours", cyclingHours = "cyclingHours"
    // Location
    static let homeHours = "homeHours", awayHours = "awayHours", placesVisited = "placesVisited"
    static let maxKmFromHome = "maxKmFromHome", locationEntropy = "locationEntropy"
    // Computed
    static let sunrise = "sunrise", sunset = "sunset", dayLengthH = "dayLengthH"
    // P2
    static let calendarEvents = "calendarEvents", eventHours = "eventHours"
    static let photosTaken = "photosTaken", photosAwayFromHome = "photosAwayFromHome"
    static let phoneNightMin = "phoneNightMin"
    /// Screen time the person reports (hours) and whether the phone was used in bed after lights out (0/1).
    /// Apple lets apps read Screen Time only with a special entitlement, so the person tells us.
    static let screenTimeSelf = "screenTimeSelf", phoneInBed = "phoneInBed"
    // SensorKit (research version)
    static let deviceUsageMin = "deviceUsageMin", unlocks = "unlocks", keyboardTypingSpeed = "keyboardTypingSpeed"
    static let messagesContacts = "messagesContacts", callMin = "callMin", ambientLux = "ambientLux", speechRate = "speechRate"
}

nonisolated enum FeatureCatalog {
    private static func h(_ key: String, _ title: String, _ device: SignalDevice, _ p: Priority, _ f: ValueFormat, _ note: String? = nil) -> SignalInfo {
        SignalInfo(key: key, title: title, source: .health, device: device, priority: p, format: f, note: note)
    }

    /// The agreed data scope (docs/DATA_SCOPE.md): only signals with a clear use. Calendar, photos,
    /// Screen Time, SensorKit, fitness and fall-risk measures and duplicate heart signals are not read.
    static let all: [SignalInfo] = [
        // Apple Health: movement (iPhone first, Watch adds detail)
        h(F.steps, "Steps", .iPhone, .p0, .integer("steps")),
        h(F.walkingSpeed, "Walking speed", .iPhone, .p0, .decimal(2, "m/s")),
        h(F.activeHours, "Hours with movement", .iPhone, .p0, .integer("h"), "Hours with at least 250 steps"),
        h(F.daylightWalkMin, "Walking in daylight, estimated", .iPhone, .p0, .minutes, "From steps between sunrise and sunset; used when there's no Watch daylight"),
        h(F.exerciseMin, "Exercise minutes", .watch, .p0, .minutes),
        h(F.workoutMin, "Workout time", .watch, .p1, .minutes),
        h(F.daylightMin, "Time in daylight", .watch, .p0, .minutes, "iOS 17 and later"),
        // Heart and body: autonomic state and the cold filter
        h(F.restingHR, "Resting heart rate", .watch, .p0, .integer("bpm")),
        h(F.hrv, "Heart rate variability", .watch, .p0, .integer("ms")),
        h(F.respRate, "Breathing rate", .watch, .p1, .decimal(1, "per min")),
        h(F.wristTemp, "Wrist temperature during sleep", .watch, .p0, .decimal(2, "°C"), "Apple Watch Series 8 or later"),
        // Late-night listening as a rhythm hint (time only, never what was played)
        h(F.nightListeningMin, "Listening between 23 and 5", .iPhone, .p1, .minutes),
        // Sleep
        h(F.sleepHours, "Sleep", .watch, .p0, .hoursMinutes),
        h(F.bedtime, "Fell asleep", .watch, .p0, .clockAfter18),
        h(F.wake, "Woke up", .watch, .p0, .clockAfterMidnight),
        h(F.awakeMin, "Awake during the night", .watch, .p0, .minutes),
        h(F.sleepEfficiency, "Sleep efficiency", .watch, .p0, .fractionPercent(0)),
        h(F.deepMin, "Deep sleep", .watch, .p1, .minutes, "Shown only, not scored"),
        h(F.remMin, "REM sleep", .watch, .p1, .minutes, "Shown only, not scored"),
        h(F.coreMin, "Core sleep", .watch, .p1, .minutes, "Shown only, not scored"),
        h(F.timeZone, "Time zone while asleep", .watch, .p0, .text, "Travel filter"),
        // User-requested nutrition context. Logged values do not prove meal count or completeness.
        h(F.dietaryEnergy, "Logged food energy", .manual, .p1, .integer("kcal")),
        h(F.dietaryWater, "Logged water", .manual, .p1, .integer("mL")),
        h(F.dietaryProtein, "Logged protein", .manual, .p1, .decimal(1, "g")),
        h(F.dietaryCarbs, "Logged carbohydrates", .manual, .p1, .decimal(1, "g")),
        h(F.dietaryFat, "Logged fat", .manual, .p1, .decimal(1, "g")),
        // Logged by the person in Health; shown, never scored
        h(F.mindfulMin, "Mindful minutes", .watch, .p0, .minutes),
        h(F.stateOfMindValence, "State of Mind, average", .manual, .p1, .decimal(2, ""), "Only if you already log it. iOS 18 and later"),
        h(F.stateOfMindCount, "State of Mind entries", .manual, .p1, .integer(""), "Only if you already log it. iOS 18 and later"),
        h(F.phq9, "PHQ-9 questionnaire", .manual, .p1, .integer(""), "Read only, never asked. iOS 18 and later"),
        h(F.gad7, "GAD-7 questionnaire", .manual, .p1, .integer(""), "Read only, never asked. iOS 18 and later"),
        h(F.medsLogged, "Medication doses taken", .manual, .p0, .integer(""), "iOS 26 and later"),
        h(F.medsSkipped, "Medication doses skipped", .manual, .p0, .integer(""), "iOS 26 and later"),
        // Motion
        SignalInfo(key: F.stillHours, title: "Still", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Last 7 days only"),
        SignalInfo(key: F.walkingHours, title: "On foot", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Walking and running. Last 7 days only"),
        // Location, reduced to daily numbers on the phone
        SignalInfo(key: F.homeHours, title: "Time at home", source: .location, device: .phone, priority: .p0, format: .hoursMinutes, note: "From install onward"),
        SignalInfo(key: F.awayHours, title: "Time away from home", source: .location, device: .phone, priority: .p0, format: .hoursMinutes, note: "From install onward"),
        SignalInfo(key: F.placesVisited, title: "Places visited", source: .location, device: .phone, priority: .p0, format: .integer(""), note: "From install onward"),
        SignalInfo(key: F.maxKmFromHome, title: "Furthest from home", source: .location, device: .phone, priority: .p0, format: .decimal(1, "km"), note: "From install onward"),
        SignalInfo(key: F.locationEntropy, title: "Variety of places", source: .location, device: .phone, priority: .p0, format: .decimal(2, ""), note: "From install onward"),
        // Computed
        SignalInfo(key: F.sunrise, title: "Sunrise", source: .computed, device: .phone, priority: .p0, format: .clockAfterMidnight),
        SignalInfo(key: F.sunset, title: "Sunset", source: .computed, device: .phone, priority: .p0, format: .clockAfterMidnight),
        SignalInfo(key: F.dayLengthH, title: "Length of daylight", source: .computed, device: .phone, priority: .p0, format: .hoursMinutes),
    ]

    /// The person's own answers (bonus: screen time). Kept apart from `all`, the sensor signals, because
    /// they reach the feature table only through `Planner.withAnswers` (not through AppModel's reads).
    static let selfReport: [SignalInfo] = [
        SignalInfo(key: F.screenTimeSelf, title: "Screen time, your estimate", source: .selfReport, device: .manual, priority: .p1,
                   format: .hoursMinutes, note: "From the optional morning question or iOS Settings → Screen Time"),
        SignalInfo(key: F.phoneInBed, title: "Phone in bed after lights out", source: .selfReport, device: .manual, priority: .p1,
                   format: .integer(""), note: "1 = yes, 0 = no"),
    ]

    static let byKey: [String: SignalInfo] = Dictionary(uniqueKeysWithValues: (all + selfReport).map { ($0.key, $0) })
}

import Foundation

/// Where a signal comes from. Drives the grouping on the Data screen.
nonisolated enum SignalSource: String, Sendable, CaseIterable {
    case health = "Apple Health"
    case motion = "Motion"
    case location = "Location"
    case computed = "Worked out on this phone"
    case calendar = "Calendar"
    case photos = "Photos"
    case screenTime = "Screen Time"
    case sensorKit = "SensorKit (research)"
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
    // SensorKit (research version)
    static let deviceUsageMin = "deviceUsageMin", unlocks = "unlocks", keyboardTypingSpeed = "keyboardTypingSpeed"
    static let messagesContacts = "messagesContacts", callMin = "callMin", ambientLux = "ambientLux", speechRate = "speechRate"
}

nonisolated enum FeatureCatalog {
    private static func h(_ key: String, _ title: String, _ device: SignalDevice, _ p: Priority, _ f: ValueFormat, _ note: String? = nil) -> SignalInfo {
        SignalInfo(key: key, title: title, source: .health, device: device, priority: p, format: f, note: note)
    }

    static let all: [SignalInfo] = [
        // Apple Health: movement
        h(F.steps, "Steps", .iPhone, .p0, .integer("steps")),
        h(F.walkRunDistance, "Walking and running distance", .iPhone, .p1, .decimal(1, "km")),
        h(F.flights, "Flights climbed", .iPhone, .p1, .integer("flights")),
        h(F.walkingSpeed, "Walking speed", .iPhone, .p0, .decimal(2, "m/s")),
        h(F.stepLength, "Step length", .iPhone, .p1, .decimal(2, "m")),
        h(F.walkAsymmetry, "Walking asymmetry", .iPhone, .p1, .fractionPercent(1)),
        h(F.doubleSupport, "Double support time", .iPhone, .p1, .fractionPercent(1)),
        h(F.stairUpSpeed, "Stair speed up", .iPhone, .p1, .decimal(2, "m/s")),
        h(F.stairDownSpeed, "Stair speed down", .iPhone, .p1, .decimal(2, "m/s")),
        h(F.sixMinWalk, "Six-minute walk estimate", .iPhone, .p1, .integer("m")),
        h(F.walkingSteadiness, "Walking steadiness", .iPhone, .p1, .fractionPercent(0)),
        h(F.activeHours, "Hours with movement", .iPhone, .p0, .integer("h"), "Hours with at least 250 steps"),
        h(F.daylightWalkMin, "Walking in daylight, estimated", .iPhone, .p0, .minutes, "From steps between sunrise and sunset; used when there's no Watch daylight"),
        h(F.exerciseMin, "Exercise minutes", .watch, .p0, .minutes),
        h(F.standMin, "Stand minutes", .watch, .p1, .minutes),
        h(F.activeEnergy, "Active energy", .watch, .p1, .integer("kcal")),
        h(F.physicalEffort, "Physical effort", .watch, .p1, .decimal(1, "kcal/hr·kg"), "iOS 17 and later"),
        h(F.daylightMin, "Time in daylight", .watch, .p0, .minutes, "iOS 17 and later"),
        // Heart and body
        h(F.heartRate, "Heart rate, average", .watch, .p1, .integer("bpm")),
        h(F.heartRateMin, "Heart rate, lowest", .watch, .p1, .integer("bpm")),
        h(F.heartRateMax, "Heart rate, highest", .watch, .p1, .integer("bpm")),
        h(F.restingHR, "Resting heart rate", .watch, .p0, .integer("bpm")),
        h(F.walkingHR, "Walking heart rate", .watch, .p1, .integer("bpm")),
        h(F.hrv, "Heart rate variability", .watch, .p0, .integer("ms")),
        h(F.hrRecovery, "Heart rate recovery", .watch, .p1, .integer("bpm")),
        h(F.vo2max, "Cardio fitness (VO₂ max)", .watch, .p1, .decimal(1, "ml/kg·min")),
        h(F.respRate, "Breathing rate", .watch, .p1, .decimal(1, "per min")),
        h(F.spo2, "Blood oxygen", .watch, .p1, .fractionPercent(0)),
        h(F.breathingDisturbances, "Breathing disturbances", .watch, .p1, .decimal(1, ""), "iOS 18 and later"),
        h(F.wristTemp, "Wrist temperature during sleep", .watch, .p0, .decimal(2, "°C"), "Apple Watch Series 8 or later"),
        // Sound
        h(F.envSound, "Environmental sound level", .watch, .p1, .integer("dB")),
        h(F.headphoneSound, "Headphone audio level", .iPhone, .p1, .integer("dB")),
        h(F.headphoneMin, "Headphone listening", .iPhone, .p1, .minutes),
        h(F.nightListeningMin, "Listening between 23 and 5", .iPhone, .p1, .minutes),
        // Sleep
        h(F.sleepHours, "Sleep", .watch, .p0, .hoursMinutes),
        h(F.bedtime, "Fell asleep", .watch, .p0, .clockAfter18),
        h(F.wake, "Woke up", .watch, .p0, .clockAfterMidnight),
        h(F.awakeMin, "Awake during the night", .watch, .p0, .minutes),
        h(F.deepMin, "Deep sleep", .watch, .p0, .minutes),
        h(F.remMin, "REM sleep", .watch, .p0, .minutes),
        h(F.coreMin, "Core sleep", .watch, .p0, .minutes),
        h(F.sleepEfficiency, "Sleep efficiency", .watch, .p0, .fractionPercent(0)),
        h(F.timeZone, "Time zone while asleep", .watch, .p0, .text),
        // Other Health
        h(F.mindfulMin, "Mindful minutes", .watch, .p0, .minutes),
        h(F.workoutCount, "Workouts", .watch, .p1, .integer("")),
        h(F.workoutMin, "Workout time", .watch, .p1, .minutes),
        h(F.workoutTypes, "Workout kinds", .watch, .p1, .integer("")),
        h(F.hrHighEvents, "High heart rate notifications", .watch, .p1, .integer("")),
        h(F.hrLowEvents, "Low heart rate notifications", .watch, .p1, .integer("")),
        h(F.irregularRhythmEvents, "Irregular rhythm notifications", .watch, .p1, .integer("")),
        h(F.loudEnvEvents, "Loud environment notifications", .watch, .p1, .integer("")),
        h(F.loudHeadphoneEvents, "Loud headphone notifications", .iPhone, .p1, .integer("")),
        h(F.symptomFatigue, "Logged symptom: fatigue", .manual, .p1, .integer("")),
        h(F.symptomSleepChanges, "Logged symptom: sleep changes", .manual, .p1, .integer("")),
        h(F.symptomMoodChanges, "Logged symptom: emotional changes", .manual, .p1, .integer("")),
        h(F.symptomAppetiteChanges, "Logged symptom: appetite changes", .manual, .p1, .integer("")),
        h(F.symptomHeadache, "Logged symptom: headache", .manual, .p1, .integer("")),
        h(F.handwashing, "Handwashing", .watch, .p2, .integer("")),
        h(F.toothbrushing, "Toothbrushing", .iPhone, .p2, .integer("")),
        h(F.stateOfMindValence, "State of Mind, average", .manual, .p1, .decimal(2, ""), "Only if you already log it. iOS 18 and later"),
        h(F.stateOfMindCount, "State of Mind entries", .manual, .p1, .integer(""), "Only if you already log it. iOS 18 and later"),
        h(F.phq9, "PHQ-9 questionnaire", .manual, .p1, .integer(""), "Read only, never asked. iOS 18 and later"),
        h(F.gad7, "GAD-7 questionnaire", .manual, .p1, .integer(""), "Read only, never asked. iOS 18 and later"),
        h(F.medsLogged, "Medication doses taken", .manual, .p1, .integer(""), "iOS 26 and later"),
        h(F.medsSkipped, "Medication doses skipped", .manual, .p1, .integer(""), "iOS 26 and later"),
        h(F.age, "Age", .manual, .p1, .integer("years")),
        h(F.sex, "Biological sex", .manual, .p1, .text),
        h(F.height, "Height", .manual, .p1, .integer("cm")),
        h(F.bodyMass, "Weight", .manual, .p1, .decimal(1, "kg")),
        h(F.basalEnergy, "Resting energy", .watch, .p1, .integer("kcal")),
        h(F.cyclingDistance, "Cycling distance", .watch, .p1, .decimal(1, "km")),
        h(F.uvExposure, "UV exposure", .watch, .p1, .decimal(1, "")),
        h(F.water, "Water", .manual, .p2, .decimal(1, "l")),
        h(F.soundReduction, "Noise reduced by AirPods", .iPhone, .p1, .integer("dB")),
        h(F.falls, "Falls", .watch, .p1, .integer("")),
        h(F.workoutEffort, "Workout effort", .watch, .p1, .decimal(1, ""), "iOS 18 and later"),
        h(F.standHours, "Stand hours", .watch, .p1, .integer("h")),
        h(F.lowFitnessEvents, "Low cardio fitness notifications", .watch, .p1, .integer("")),
        h(F.breathingEvents, "Breathing disturbance notifications", .watch, .p1, .integer(""), "iOS 18 and later"),
        h(F.caffeine, "Caffeine", .manual, .p2, .integer("mg")),
        h(F.alcohol, "Alcoholic drinks", .manual, .p2, .integer("")),
        // Motion
        SignalInfo(key: F.stillHours, title: "Still", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Last 7 days only"),
        SignalInfo(key: F.walkingHours, title: "Walking", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Last 7 days only"),
        SignalInfo(key: F.runningHours, title: "Running", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Last 7 days only"),
        SignalInfo(key: F.automotiveHours, title: "In a vehicle", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Last 7 days only"),
        SignalInfo(key: F.cyclingHours, title: "Cycling", source: .motion, device: .phone, priority: .p0, format: .hoursMinutes, note: "Last 7 days only"),
        // Location
        SignalInfo(key: F.homeHours, title: "Time at home", source: .location, device: .phone, priority: .p0, format: .hoursMinutes, note: "From install onward"),
        SignalInfo(key: F.awayHours, title: "Time away from home", source: .location, device: .phone, priority: .p0, format: .hoursMinutes, note: "From install onward"),
        SignalInfo(key: F.placesVisited, title: "Places visited", source: .location, device: .phone, priority: .p0, format: .integer(""), note: "From install onward"),
        SignalInfo(key: F.maxKmFromHome, title: "Furthest from home", source: .location, device: .phone, priority: .p0, format: .decimal(1, "km"), note: "From install onward"),
        SignalInfo(key: F.locationEntropy, title: "Variety of places", source: .location, device: .phone, priority: .p0, format: .decimal(2, ""), note: "From install onward"),
        // Computed
        SignalInfo(key: F.sunrise, title: "Sunrise", source: .computed, device: .phone, priority: .p0, format: .clockAfterMidnight),
        SignalInfo(key: F.sunset, title: "Sunset", source: .computed, device: .phone, priority: .p0, format: .clockAfterMidnight),
        SignalInfo(key: F.dayLengthH, title: "Length of daylight", source: .computed, device: .phone, priority: .p0, format: .hoursMinutes),
        // P2
        SignalInfo(key: F.calendarEvents, title: "Calendar events", source: .calendar, device: .phone, priority: .p2, format: .integer("")),
        SignalInfo(key: F.eventHours, title: "Time in events", source: .calendar, device: .phone, priority: .p2, format: .hoursMinutes),
        SignalInfo(key: F.photosTaken, title: "Photos taken", source: .photos, device: .phone, priority: .p2, format: .integer(""), note: "Dates only, never the pictures"),
        SignalInfo(key: F.photosAwayFromHome, title: "Photos taken away from home", source: .photos, device: .phone, priority: .p2, format: .integer(""), note: "Dates only, never the pictures"),
        SignalInfo(key: F.phoneNightMin, title: "Phone use at night", source: .screenTime, device: .phone, priority: .p2, format: .minutes, note: "Apple only lets a Screen Time report draw this; the number cannot be stored"),
        // SensorKit, research version only
        SignalInfo(key: F.deviceUsageMin, title: "Phone use", source: .sensorKit, device: .phone, priority: .p2, format: .minutes, note: "Needs an approved research study"),
        SignalInfo(key: F.unlocks, title: "Unlocks", source: .sensorKit, device: .phone, priority: .p2, format: .integer(""), note: "Needs an approved research study"),
        SignalInfo(key: F.keyboardTypingSpeed, title: "Typing speed", source: .sensorKit, device: .phone, priority: .p2, format: .decimal(1, "chars/s"), note: "Needs an approved research study"),
        SignalInfo(key: F.messagesContacts, title: "People messaged", source: .sensorKit, device: .phone, priority: .p2, format: .integer(""), note: "Needs an approved research study"),
        SignalInfo(key: F.callMin, title: "Time on calls", source: .sensorKit, device: .phone, priority: .p2, format: .minutes, note: "Needs an approved research study"),
        SignalInfo(key: F.ambientLux, title: "Ambient light", source: .sensorKit, device: .phone, priority: .p2, format: .integer("lux"), note: "Needs an approved research study"),
        SignalInfo(key: F.speechRate, title: "Speaking pace", source: .sensorKit, device: .phone, priority: .p2, format: .decimal(1, "words/s"), note: "Needs an approved research study"),
    ]

    static let byKey: [String: SignalInfo] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
}

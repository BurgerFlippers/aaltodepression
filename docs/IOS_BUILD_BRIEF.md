# iOS build brief: TMS aftercare app (Junction 2026, Aalto "Beyond the Clinic")

## Status (checked 15 November 2026)

This is the original brief the project started from. It is kept for its reasoning, data inventory and engine rules. The app built from it is MindMaintainer. For what exists now, read [APP_DESIGN.md](APP_DESIGN.md), [DATA_SCOPE.md](DATA_SCOPE.md) and [HEALTHKIT_DATA.md](HEALTHKIT_DATA.md).

Still true:

- Baseline (section 5): median and MAD over the 28 days before the current window, at least 7 values (`Engine/Baseline.swift`).
- Score scale and `closeness` / `atLeast` (section 6), the `likelyIll` and `travelling` flags, and missing data never counting as zero.
- Step engine (section 7): drift is more than 15 points below the usual day score; step 1 at 5 drift days of 7, step 2 after 10 days at step 1, back to steady at 2 or fewer (`Engine/StepEngine.swift`).
- Demo patient Perttu (section 9) in `Sources/DemoSource.swift`, used by `Tools/engine-check.sh` and the DevTools screens.

Changed:

- **Data:** reading "everything available" (section 4) was replaced by the much smaller agreed scope in DATA_SCOPE.md. The running app reads 120 days, not 365. Calendar, photos, SensorKit and most P1 types are not read. Location is collected only after the person turns it on.
- **Scores:** weights are Sleep 0.30, Rhythm 0.25, Movement 0.20, Daylight 0.10, Places 0.10, Body 0.05. Sleep also uses a 3-night mean and sleep efficiency. Rhythm compares the 7-day spread of wake and bedtime with the person's own usual spread and adds the sleep midpoint. Movement adds active hours.
- **UI:** there is no Data screen and no Plan screen, and `plan_perttu.json` is not shown. The person sees one daily task chosen from the scores, Trends with the day score and signals, For you and You (see APP_DESIGN.md).
- **Step 1 and 2:** the app does not send a local notification at step 1. At step 2 no message goes out automatically: the friend message and nurse call were not built, and every message is sent by the person.
- **Usage strings:** see `project.pbxproj`. The Health text now also covers nutrition and mind context. Calendar and Photos texts are still there but unused.
- **Storage:** SwiftData is not used by the running app. Health readings are held in memory; profile and planner state are JSON files.

The rest of this file is the original brief, unchanged.

---

Hand this file to Claude Code in an empty folder. You (the coding Claude) own the UX and the app name. Read section 1 to 3 for the why, section 4 for the data you must read, section 5 to 7 for the logic, section 8 for UX rules you must respect, then propose a name and a design direction in a few lines before you write UI code.

## 1. What this is

Users = people who just finished TMS (transcranial magnetic stimulation) treatment for depression. Relapse is common in the first year, and an early booster TMS course often works if worsening is caught early. This app is the patient side of an aftercare service:

- The nurse writes the plan in the clinic (separate web app, not in this brief). The patient's app receives it. The patient types almost nothing.
- The app reads everything it can from Apple Health and the phone, compares each signal with the person's own usual (never with population norms), and shows a few simple daily scores.
- A hidden step engine notices sustained drift and either suggests one action from the plan (step 1) or brings people in: a pre-written message to a friend and a nurse call (step 2).

No machine learning. Aalto researchers told us a real predictive model is a PhD topic. We build the loop and transparent rules, and we read as much data as possible so a future model has something to learn from.

## 2. Scope for 48 h

Must work in the demo:

1. Demo mode with synthetic patient **Perttu**: 60 days of every feature in section 4, steady until day 44, drift from day 45. Demo day selectable in Settings.
2. Real mode on our own iPhones and Watches: read every HealthKit type in section 4 that the device has, backfilled 365 days.
3. Core Motion activity history (last 7 days) and location visits from install onward.
4. Daily scores (section 6), the step engine (section 7), one local notification at step 1.
5. A **Data** screen that lists every signal read, its source, the last value and how many days of history exist. Judges should see the breadth.
6. Plan screen, read-only, loaded from `plan_perttu.json` (stand-in for the nurse's QR).

Out of scope: login, backend sync, real QR pairing, Android, ML.

## 3. Project setup

- Xcode 16+, Swift 6 concurrency, SwiftUI, SwiftData for the local feature store.
- Minimum iOS 17.0. Guard newer types with `#available` (iOS 18 and 26 types in section 4).
- Capabilities: HealthKit. Background Modes: Location updates (for visits).
- Info.plist usage strings (plain, honest):
  - `NSHealthShareUsageDescription`: "Reads sleep, movement, heart, daylight and other Health data to notice changes in your daily rhythm. Everything is worked out on this phone."
  - `NSMotionUsageDescription`: "Reads whether you were still, walking or travelling, to understand your days."
  - `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription`: "Counts time at home and places visited. Locations never leave this phone."
  - Optional P2: `NSCalendarsFullAccessUsageDescription`, `NSPhotoLibraryUsageDescription`.
- Free personal provisioning is enough. Do not use any employer developer account.
- HealthKit read permission is opaque: the app cannot tell "denied" from "no data". Treat empty results as unknown, never as zero.

## 4. Data inventory: read everything available

Priority: **P0** = must read and use in scores or context. **P1** = must read and store (shown on Data screen, available for later models). **P2** = stretch.
Store every feature as one value per day in the feature store. Backfill 365 days where the source allows it.

### 4.1 HealthKit quantity types (daily aggregate)

| Feature key | HealthKit identifier | Aggregate | Unit | Device | Priority |
|---|---|---|---|---|---|
| steps | stepCount | sum | count | iPhone | P0 |
| walkRunDistance | distanceWalkingRunning | sum | m | iPhone | P1 |
| flights | flightsClimbed | sum | count | iPhone | P1 |
| walkingSpeed | walkingSpeed | avg | m/s | iPhone | P0 |
| stepLength | walkingStepLength | avg | m | iPhone | P1 |
| walkAsymmetry | walkingAsymmetryPercentage | avg | % | iPhone | P1 |
| doubleSupport | walkingDoubleSupportPercentage | avg | % | iPhone | P1 |
| stairUpSpeed | stairAscentSpeed | avg | m/s | iPhone | P1 |
| stairDownSpeed | stairDescentSpeed | avg | m/s | iPhone | P1 |
| sixMinWalk | sixMinuteWalkTestDistance | avg | m | iPhone | P1 |
| walkingSteadiness | appleWalkingSteadiness | avg | % | iPhone | P1 |
| exerciseMin | appleExerciseTime | sum | min | Watch | P0 |
| standMin | appleStandTime | sum | min | Watch | P1 |
| activeEnergy | activeEnergyBurned | sum | kcal | Watch | P1 |
| physicalEffort | physicalEffort (iOS 17) | avg | kcal/hr·kg | Watch | P1 |
| daylightMin | timeInDaylight (iOS 17) | sum | min | Watch | P0 |
| heartRate | heartRate | avg, also min and max | count/min | Watch | P1 |
| restingHR | restingHeartRate | avg | count/min | Watch | P0 |
| walkingHR | walkingHeartRateAverage | avg | count/min | Watch | P1 |
| hrv | heartRateVariabilitySDNN | avg | ms | Watch | P0 |
| hrRecovery | heartRateRecoveryOneMinute | avg | count/min | Watch | P1 |
| vo2max | vo2Max | avg | ml/kg·min | Watch | P1 |
| respRate | respiratoryRate | avg | count/min | Watch | P1 |
| spo2 | oxygenSaturation | avg | % | Watch | P1 |
| breathingDisturbances | appleSleepingBreathingDisturbances (iOS 18) | avg | count | Watch | P1 |
| wristTemp | appleSleepingWristTemperature | avg | °C | Watch S8+ | P0 |
| envSound | environmentalAudioExposure | avg | dBASPL | Watch | P1 |
| headphoneSound | headphoneAudioExposure | avg, plus total duration | dBASPL | iPhone | P1 |
| caffeine | dietaryCaffeine | sum | mg | manual | P2 |
| alcohol | numberOfAlcoholicBeverages | sum | count | manual | P2 |

Headphone exposure samples also tell when the person listened (e.g. late at night). Store the minutes of headphone listening between 23:00 and 05:00 as `nightListeningMin` (P1).

### 4.2 HealthKit category, sample and workout types

| Feature key(s) | Source | Derived per day | Priority |
|---|---|---|---|
| sleepHours, bedtime, wake, awakeMin, deepMin, remMin, coreMin, sleepEfficiency | sleepAnalysis (stages) | night assigned to the morning it ends; bedtime as hours after 18:00 previous day; wake as hours after midnight | P0 |
| mindfulMin | mindfulSession | sum of minutes | P0 |
| workoutCount, workoutMin, workoutTypes | HKWorkout | count, minutes, distinct types | P1 |
| hrHighEvents, hrLowEvents, irregularRhythmEvents | highHeartRateEvent, lowHeartRateEvent, irregularHeartRhythmEvent | count | P1 |
| loudEnvEvents, loudHeadphoneEvents | environmentalAudioExposureEvent, headphoneAudioExposureEvent | count | P1 |
| symptomFatigue, symptomSleepChanges, symptomMoodChanges, symptomAppetiteChanges, symptomHeadache | fatigue, sleepChanges, moodChanges, appetiteChanges, headache (manual symptom logs) | count | P1 |
| handwashing, toothbrushing | handwashingEvent, toothbrushingEvent (only if a device logs them) | count | P2 |
| stateOfMindValence | HKStateOfMind (iOS 18) | mean valence, count | P1 (only if the user already logs it; never ask) |
| phq9, gad7 | scored assessments (iOS 18) | latest score | P1 (read only; never ask) |
| medsLogged, medsSkipped | medications and dose events (iOS 26: user annotated medications + dose event queries) | doses taken vs scheduled | P1 |
| timeZone | metadata `HKMetadataKeyTimeZone` on sleep samples | string | P0 (travel context) |

Not available, do not try: Apple's Sleep Score (no API as of iOS 26), Vitals app outlier flags, any per-app screen time.

Cycle tracking types exist in HealthKit but are off by default in this app. Read only if the nurse plan explicitly enables them.

### 4.3 Other iOS frameworks

| Feature key(s) | Framework | How | History | Priority |
|---|---|---|---|---|
| stillHours, walkingHours, runningHours, automotiveHours, cyclingHours | Core Motion `CMMotionActivityManager.queryActivityStarting` | sum activity segments per day, confidence ≥ medium | last 7 days only | P0 |
| homeHours, awayHours, placesVisited, maxKmFromHome, locationEntropy | Core Location visits (`startMonitoringVisits`, `CLVisit`) plus significant location changes | home = most frequent overnight place; all computed on device; store only the derived numbers, never coordinates | from install | P0 |
| sunrise, sunset, dayLengthH | computed locally (NOAA solar algorithm) from approximate location and date | needed to set a fair daylight target in a Finnish winter | any | P0 |
| calendarEvents, eventHours | EventKit, read-only full access | count and duration of events per day | backfill | P2 |
| photosTaken, photosAwayFromHome | PhotoKit metadata only (creation date, whether location differs from home) | count per day, never image content | backfill | P2 |
| phoneNightMin | DeviceActivity report extension (FamilyControls) | render-only: the extension can draw a score but cannot pass numbers back to the app | from install | P2 |

**SensorKit (not for the hackathon, design for it).** SensorKit gives research-grade phone usage, keyboard metrics, messages and call usage, visits, ambient light and speech metrics, but only with an Apple research entitlement granted per approved study. Create a `SensorKitSource` protocol stub with these feature keys so the research version with Aalto can plug it in: `deviceUsageMin`, `unlocks`, `keyboardTypingSpeed`, `messagesContacts`, `callMin`, `ambientLux`, `speechRate`.

### 4.4 Implementation pattern

One generic reader for quantity types, so adding a type is one line:

```swift
import HealthKit

struct QuantitySpec {
    let key: String
    let id: HKQuantityTypeIdentifier
    let options: HKStatisticsOptions       // .cumulativeSum or .discreteAverage (add .discreteMin/.discreteMax where listed)
    let unit: HKUnit
}

let quantitySpecs: [QuantitySpec] = [
    .init(key: "steps", id: .stepCount, options: .cumulativeSum, unit: .count()),
    .init(key: "walkingSpeed", id: .walkingSpeed, options: .discreteAverage, unit: .meter().unitDivided(by: .second())),
    .init(key: "restingHR", id: .restingHeartRate, options: .discreteAverage, unit: .count().unitDivided(by: .minute())),
    .init(key: "hrv", id: .heartRateVariabilitySDNN, options: .discreteAverage, unit: .secondUnit(with: .milli)),
    .init(key: "daylightMin", id: .timeInDaylight, options: .cumulativeSum, unit: .minute()),
    .init(key: "wristTemp", id: .appleSleepingWristTemperature, options: .discreteAverage, unit: .degreeCelsius()),
    .init(key: "envSound", id: .environmentalAudioExposure, options: .discreteAverage, unit: .decibelAWeightedSoundPressureLevel()),
    // ... every row of table 4.1
]

func dailyValues(_ spec: QuantitySpec, store: HKHealthStore, from: Date, to: Date) async throws -> [Date: Double] {
    let cal = Calendar.current
    let predicate = HKSamplePredicate.quantitySample(type: HKQuantityType(spec.id),
                                                     predicate: HKQuery.predicateForSamples(withStart: from, end: to))
    let query = HKStatisticsCollectionQueryDescriptor(predicate: predicate, options: spec.options,
                                                      anchorDate: cal.startOfDay(for: from),
                                                      intervalComponents: DateComponents(day: 1))
    let result = try await query.result(for: store)
    var out: [Date: Double] = [:]
    result.enumerateStatistics(from: from, to: to) { stats, _ in
        let q = spec.options.contains(.cumulativeSum) ? stats.sumQuantity() : stats.averageQuantity()
        if let q { out[cal.startOfDay(for: stats.startDate)] = q.doubleValue(for: spec.unit) }
    }
    return out
}
```

Sleep: query `sleepAnalysis` samples, keep asleep stages (core, deep, REM, unspecified) and awake. Assign every sample to the morning it ends, with 18:00 as the day boundary (`startOfDay(endDate + 6 h)`). Verify on a real phone that nights do not split in two.

Run all readers concurrently with a task group, write results into the SwiftData store, and log per feature how many days came back. Missing types must not crash the app.

## 5. Baseline

Per feature: median and MAD (median absolute deviation) over the 28 days before the current day window starts. In real mode this comes from Health history, including the TMS weeks, so the person has a baseline on day one. Never use population norms.

```swift
struct Usual { let median: Double; let mad: Double }

func usual(_ xs: [Double]) -> Usual? {
    guard xs.count >= 7 else { return nil }
    let s = xs.sorted(); let m = s[s.count / 2]
    let dev = xs.map { abs($0 - m) }.sorted()
    return Usual(median: m, mad: max(dev[dev.count / 2], 1e-6))
}
```

## 6. Daily scores

Every score answers one question: how close was today to your usual? 0 to 100, 100 = your usual or better.

```swift
// two-sided: being far off in either direction lowers the score
func closeness(_ x: Double, _ u: Usual) -> Double {
    let z = abs(x - u.median) / (1.4826 * u.mad)
    return max(0, 100 - z * 25)
}
// one-sided: more than usual is fine (steps, daylight, time out of home)
func atLeast(_ x: Double, _ u: Usual) -> Double {
    x >= u.median ? 100 : closeness(x, u)
}
```

| Score | Built from | Rule |
|---|---|---|
| Sleep | sleepHours, bedtime, wake, awakeMin | mean of closeness() over the four |
| Rhythm | wake and bedtime of last 7 days | SD of wake and bedtime in hours; ≤ 0.5 h = 100, ≥ 2 h = 0, linear |
| Movement | steps, exerciseMin, walkingSpeed, stillHours | atLeast() for steps and exercise, closeness() for walking speed and still hours, mean |
| Daylight | daylightMin vs target | target = 30 min, scaled down when dayLengthH < 8 (minimum 15 min); min(100, minutes / target × 100) |
| Places | awayHours, placesVisited | atLeast() for both, mean. Hidden if location is off |
| Body | restingHR, hrv, wristTemp, respRate | mean of closeness() |

Day score = weighted mean of available scores: Sleep 0.30, Rhythm 0.20, Movement 0.20, Daylight 0.10, Places 0.10, Body 0.10. Renormalise when a score is missing. Missing data never counts as zero.

Context flags (computed daily, never shown as health claims):

- `likelyIll` = restingHR ≥ usual + 5 or wristTemp ≥ usual + 0.5 °C
- `travelling` = sleep time zone differs from home time zone, or maxKmFromHome > 100

## 7. Step engine (hidden)

```
baselineDay  = median day score over the baseline window
driftDay     = dayScore < baselineDay - 15 AND NOT likelyIll AND NOT travelling
step 1       = driftDay on >= 5 of last 7 days
step 2       = step 1 has lasted >= 10 days
back to 0    = driftDay on <= 2 of last 7 days
step 3       = set by the nurse only, never by the app
```

- Step 1: show one action from the plan, preferring actions the data can confirm (daylight, walk, wake time, breathing). One local notification, maximum one per day.
- Step 2: tell the person their pre-written message to the friend goes out tomorrow at 12:00 unless they cancel, and that the nurse will call this week.
- Never show the step number, never use the words risk, relapse or mood.

## 8. UX: you choose, within these rules

You decide the name, information architecture, visual direction and components. Propose them first in 5 to 10 lines. Our only requirements:

- Name: short, works in Finnish and English, not "Tahti". Check that it is not an existing health app.
- The person sees their daily scores at a glance every day, and nothing asks them for input on a normal day.
- Scores describe what the person did and how their body was, compared with their own usual. No mood words, no diagnosis, no red, no streaks, no badges.
- Low days must not feel like failure: show one achievable next step instead of a verdict.
- Health permission and the plan arrive in one short, calm flow (the nurse already explained everything).
- The Data screen exists and is honest about what is and isn't available.
- Accessibility: Dynamic Type, VoiceOver labels on every score, 44 pt touch targets, colours that also differ in lightness, Reduce Motion respected.
- Copy: sentence case, plain verbs, buttons say what happens ("Message Ville"), no filler.
- Crisis help reachable from the home screen in one tap (placeholder number for the demo, mark it clearly).

Avoid template looks: no generic card grid with identical shadows, no all-caps labels, no gradient washes. Spend the boldness on one element that makes the daily scores memorable.

## 9. Demo data: Perttu

`DemoSource` must return every feature key above for 60 days, deterministic (seeded noise), so the demo looks the same every run.

- Days 0 to 44: steady. Bed about 23:20, wake about 07:10, sleep 7.3 h, steps about 6,000, daylight 25 to 35 min, restingHR about 58, HRV about 48 ms, 2 to 4 places a day, 4 to 6 h away from home.
- Day 30 to 32: a cold (restingHR +7, wristTemp +0.7 °C, lower steps). The engine must not escalate.
- Day 38 to 40: a trip (time zone change, maxKmFromHome 400). The engine must not escalate.
- Day 45 onward: drift. Bedtime later and irregular, awakeMin up, sleep shorter, steps down 50 %, daylight under 10 min, places 0 to 1, more still hours, nightListeningMin up, HRV down a little.

Expected result: step 1 around day 49, step 2 around day 59. Settings has a demo-day stepper (28 to 59) so we can walk through it on stage.

`Resources/plan_perttu.json`:

```json
{
  "patientName": "Perttu",
  "nurseName": "Sanna",
  "earlySigns": ["Sleep drifts late", "Mornings feel heavy", "Stops answering messages"],
  "actions": [
    {"key": "light", "title": "Morning light outside", "seenBy": "daylightMin"},
    {"key": "walk", "title": "A short walk", "seenBy": "steps"},
    {"key": "breath", "title": "Slow breathing, 5 minutes", "seenBy": "mindfulMin"},
    {"key": "call", "title": "See or call someone", "seenBy": null}
  ],
  "friendName": "Ville",
  "friendMessage": "Hei Ville, jos saat tämän, pyytäisitkö minut kävelylle tällä viikolla? Ei tarvitse kysellä mitään. – P",
  "startDate": "2026-09-30",
  "months": 12
}
```

## 10. Build order

1. Feature store, DemoSource for Perttu, baseline, scores, step engine. Print a 60-day table in the console and check: no escalation on the cold and the trip, step 1 near day 49, step 2 near day 59.
2. Propose name and UX direction, then build the home screen with the daily scores on demo data.
3. Plan screen, step 1 and step 2 states, notification.
4. Real HealthKit readers on a real iPhone + Watch, then Core Motion and location visits.
5. Data screen.
6. P2 items only after two full demo runs pass in a row.

## 11. Demo script (90 s)

1. Demo day 40: a normal day, scores near usual.
2. Demo day 31: the cold. Body score dips, nothing escalates, a calm line says why.
3. Demo day 50: scores down, one action from Perttu's plan, notification arrives.
4. Demo day 59: the friend message and nurse call state.
5. Switch demo off: the same screens with our own real Health data, then open the Data screen to show how many signals are read.

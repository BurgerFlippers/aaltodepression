# HealthKit data used by MindMaintainer

Checked against the code on 15 November 2026. Data policy: [DATA_SCOPE.md](DATA_SCOPE.md).

## Active interface

Apple Health is read only while the Apple Health switch is on (onboarding step 5 or You). Turning the switch off stops reading. It does not change Health's own permissions, which the person removes in Health → profile → Apps.

The permission request (`BesideHealthAccess` in `Features/Everyday/BesideDemoControlsView.swift`) asks to read the types below. On iOS 18 and later it also asks to save State of Mind, for a check-in that is not in the running UI, so nothing is saved to Health now.

Data is read through `HealthKitSource.readReport(days: 120, ..., keys:)` with a key allow-list supplied by `BesidePresentation`. Reads happen when the app becomes active and on pull to refresh. A type returns values only when there are shared records. Missing values stay unknown. A missing nutrition entry is not evidence that a meal was skipped. Health readings are held in memory and not saved by the app.

| Group | Values read or derived | HealthKit source | Use |
|---|---|---|---|
| Movement | Daily steps, walking speed, exercise minutes; active hours derived from hourly steps | `stepCount`, `walkingSpeed`, `appleExerciseTime` | Movement score |
| Sleep | Asleep hours, sleep onset, wake time, awake minutes, sleep efficiency, deep/REM/core minutes | `sleepAnalysis` | Sleep and Rhythm scores; stages are not scored |
| Daylight | Recorded daylight minutes | `timeInDaylight` | Daylight score |
| Heart and body | Resting heart rate, HRV (SDNN), breathing rate, sleeping wrist temperature | `restingHeartRate`, `heartRateVariabilitySDNN`, `respiratoryRate`, `appleSleepingWristTemperature` | Body score and the illness flag |
| Nutrition | Logged energy (kcal), water (mL), protein, carbohydrates and total fat (g) | `dietaryEnergyConsumed`, `dietaryWater`, `dietaryProtein`, `dietaryCarbohydrates`, `dietaryFatTotal` | Context only: Trends → Food |
| Mind | Daily average State of Mind valence, mindful minutes, latest PHQ-9 and GAD-7 score recorded on each day | `stateOfMind`, `mindfulSession`, `PHQ9`, `GAD7` | Context only: Trends → How you feel |

The active read allow-list excludes workouts, headphone exposure and medication. The older reader in `HealthKitSource` still supports those for the DevTools screens, but the running app does not ask for them or read them. The daylight estimate from steps is not used, because the Health reader gets no location.

Nutrition and Mind values are removed from the table passed to the planner and `StepEngine`. They do not change scores or tasks, do not infer meal counts and never trigger a request to another person. The app does not give PHQ-9 or GAD-7; it shows scores that already exist in Health. Which types are available depends on the OS, the device and the apps that write to Health.

## Other sources merged with Health

- **Location** (when the person turns it on): time away from home and places visited, for Getting out and the Places score. See DATA_SCOPE.md.
- **iPhone movement** (when turned on): Core Motion walking and still hours for the last 7 days, and today's pedometer steps.

## Demo data

- Demo edits, scenarios and score overrides live in an in-memory copy of the planner. They never reach Health or the live planner.
- "Use simulated data" (advanced demo menu) replaces Health with 60 simulated days ending today. Health is not read while it is on.
- Live mode scores the last complete day. Trends and the demo score the selected day.

## Reach-out suggestions

`ReachOutRules` is separate from Health scoring. A suggestion needs two previous full days with real activity in the app and the category unmarked on both. Blank days do not count. It does not queue a message, and opening Messages does not mark a task done or claim a message was sent. No current screen shows this suggestion.

Automatic-request demonstrations (`demonstrateAutomaticSupport`) need the demo planner, an enabled topic, explicit opt-in and an agreed recipient, and use the existing rate limits. They only create local records. No current screen calls them.

## Daily tasks

- Task choice reuses the Health-derived scores. The Sleep category uses the lower of Sleep and Rhythm; Move uses the lower of Movement and Daylight. Two choices come from the lower category and one from the other if its score is under 80.
- Signals older than one day, future signals and non-finite scores are ignored. Without a usable score the app says these are general ideas.
- Smaller versions are offered when the lowest category score is under 45, at step 2 (reach out) or on a likely-illness day. These are demo heuristics, not clinical thresholds.
- Nutrition, Mind, Social and medication data do not become scores. Choosing tasks does not widen the Health read scope.
- Choosing or completing a task never changes Health scores or sends a message.
- The five task categories are Eat, Move, Sleep, Social and Medicine, with six regular and smaller pairs each.

## Widget and reminders

- The widget's App Group file holds only the chosen task's day, id, wording, category, minutes, size and done state. No Health values, contacts or demo data.
- The widget cannot complete a task. Old completion receipts are deleted without being applied.
- "Remind me" sets one local notification for today with private text. It is cancelled when the task is done or changed.

## No longer shown

The routine feedback marker (each manually logged category moved the marker 1.5 points towards green, at most 9) lived in `BesideDemoBar`, which no current screen uses. Trends' Daily balance shows the Health day score without this adjustment.

## API references

- [Apple nutrition identifiers](https://developer.apple.com/documentation/healthkit/nutrition-type-identifiers)
- [Apple HealthKit data types](https://developer.apple.com/documentation/healthkit/data-types)
- [Apple HealthKit updates: mental wellbeing samples](https://developer.apple.com/documentation/updates/healthkit)
- [Apple SMS links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/SMSLinks/SMSLinks.html)

# HealthKit data used by Beside

## Active interface

The active Health connection asks for read-only access. Data is read through `HealthKitSource` for up to 120 days, with an explicit key allow-list supplied by `BesidePresentation`. A type returns values only when there are shared records. Missing values stay unknown; a missing nutrition entry is not evidence that a meal was skipped.

| Group | Values read or derived | HealthKit source | Use |
|---|---|---|---|
| Movement | Daily steps, walking speed, exercise minutes; hours with movement derived from hourly steps | `stepCount`, `walkingSpeed`, `appleExerciseTime` | Existing movement and rhythm context |
| Sleep | Asleep hours, sleep onset, wake time, awake minutes, sleep efficiency, deep/REM/core minutes | `sleepAnalysis` | Existing sleep/rhythm inputs; stages are supporting detail |
| Daylight | Recorded daylight minutes | `timeInDaylight` | Existing daylight input |
| Heart and body | Resting heart rate, HRV (SDNN), breathing rate, sleeping wrist temperature | `restingHeartRate`, `heartRateVariabilitySDNN`, `respiratoryRate`, `appleSleepingWristTemperature` | Existing body/change inputs |
| Nutrition | Logged energy (kcal), water (mL), protein, carbohydrates and total fat (g) | `dietaryEnergyConsumed`, `dietaryWater`, `dietaryProtein`, `dietaryCarbohydrates`, `dietaryFatTotal` | Context only, shown in demo controls |
| Mind | Daily average State of Mind valence, mindful minutes, latest PHQ-9 and GAD-7 score recorded on each day | `stateOfMind`, `mindfulSession`, `PHQ9`, `GAD7` | Context only, shown in demo controls |

The active read allow-list excludes workouts, headphone exposure and medication events. The shared legacy reader still supports those for older backend testing screens, but does not query them for the active interface. No location-based daylight estimate is retained without location data.

Nutrition and Mind values are separated from the table passed to the planner and StepEngine. They do not change the gradient, complete Eat, infer meal counts or trigger an automatic request. The app does not administer PHQ-9/GAD-7; it displays existing Health scores. Permissions and record availability depend on the OS/device and sources that write to Health.

## Demo and contact behaviour

Demo overrides remain in the in-memory copy, never in Health or the live planner. Live mode uses the last complete day for the gradient; the demo evaluates the selected date. The native permission sheet lets the person choose each readable type.

A missing-category reach-out suggestion is separate from Health scoring: two previous full days must have actual Beside activity, and the category must be unmarked on both. Blank days do not count. The suggestion does not queue a message. Opening Messages does not mark a task or claim that a message was sent. Automatic-request demonstrations require the demo planner, an enabled topic, explicit demo opt-in and an agreed recipient, and reuse existing rate limits. They only create local simulated records.

## API references

- [Apple nutrition identifiers](https://developer.apple.com/documentation/healthkit/nutrition-type-identifiers)
- [Apple HealthKit data types](https://developer.apple.com/documentation/healthkit/data-types)
- [Apple HealthKit updates: mental wellbeing samples](https://developer.apple.com/documentation/updates/healthkit)
- [Apple SMS links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/SMSLinks/SMSLinks.html)

## Routine display feedback

The displayed marker adds a small presentation adjustment to the Health-based position: 1.5 percentage points towards green for each distinct manually logged category on the selected day, capped at 9 points. The raw Health scores, baseline, support decisions and automatic-message rules remain unchanged. Repeated same-category marks cannot accumulate extra credit, and undo removes the contribution when no done mark remains in that category. Even the maximum adjustment keeps an active call signal in the red. Demo controls show the Health evaluation day and the routine-feedback day separately.

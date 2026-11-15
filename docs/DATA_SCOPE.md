# MindMaintainer: what data is collected

This is the team's data policy. The rules below were agreed earlier. Change them only with the team's agreement. The "In the app now" notes say what the code does today (checked 15 November 2026). Where the code does not yet meet a rule, the rule still applies and the gap is listed under Open gaps.

The policy came from a research run with four views (research evidence, iOS feasibility, privacy and acceptability, fit to the challenge) and two critics (a privacy sceptic and a Junction judge). The agents found the references, and they have not been checked one by one. Check them before using them in a pitch.

Exact Health types read: [HEALTHKIT_DATA.md](HEALTHKIT_DATA.md).

## Rules

1. **Daily values only.** Raw data stays in HealthKit. The app keeps one value per signal per day, about 25 signals in all.
2. **Content is never read.** Messages, calendar, photos, audio and camera images are not stored. Optional measurements (tier C) keep only numbers.
3. **Phone first, wearable adds detail.** Scores work with an iPhone alone. A Watch or ring makes them more precise. Each source has its own baseline, so Watch and Oura HRV values are not mixed.
4. **Missing data is never drift.** The same goes for contact: silence never starts a message to anyone.
5. **Self-report is not scored.** It is shown for comparison and may at most calibrate weights (see Open decisions 2).
6. **Each source is asked for separately and can be turned off.** Sensitive data is tier C and also gets "Pause for 7 days".

## Tier A: core (iPhone and HealthKit, no wearable)

| Signal | Source | Why | Rule | In the app now |
|---|---|---|---|---|
| Steps and hourly steps | HealthKit `stepCount` | Movement, daily rhythm | Keep hourly data at most 14 days | Daily steps read. Hourly steps are read from Health to work out active hours and are not stored. With iPhone movement on, today's pedometer steps are also used. |
| Active hours, first and last active hour | From hourly steps | Rhythm | | Active hours: yes. First and last active hour: not built. |
| Interdaily stability, intradaily variability | From hourly steps | Rhythm regularity (Saeb 2015, Stamatis 2024; linked to symptoms, does not predict) | | Not built |
| Walking speed | HealthKit `walkingSpeed` | Psychomotor slowing (moderate evidence) | | Read |
| Walking and still hours | Core Motion | Movement | Store daily, because iOS keeps only 7 days | Read for the last 7 days when iPhone movement is on. Held in memory, not stored. |
| Home and away, places, furthest distance, spread | Core Location visits | Strongest passive early sign: more time at home than usual, symptoms 1–2 weeks later (Stamatis 2024) | Delete coordinates after the nightly calculation. Keep only one rounded home point. | Off until the person turns on Location (onboarding step 5 or You). Then visits and significant location changes are recorded on this iPhone from that day on. Feeds Getting out and the Places score. Storage does not yet meet the rule (see Open gaps). |
| Sleep timing without a Watch | iPhone sleep schedule (inBed), charging and motion | Sleep and rhythm without a wearable (weak proxy) | | Not built |
| Daylight estimate | Steps between sunrise and 11:00 | Daylight without a Watch (proxy) | | Not used: the running app gives the Health reader no location |
| Sunrise, sunset, time zone | Worked out on the phone | Context, travel filter | | Code exists. Not used by the running app. |
| Mindful minutes | HealthKit | Shows whether a breathing exercise was done | Not scored | Read as context, not scored. The running app does not write them. |

## Tier B: wearable (Watch, Oura, Garmin and others through HealthKit)

| Signal | Source | Why | Rule | In the app now |
|---|---|---|---|---|
| Sleep duration, efficiency, time awake, midpoint | `sleepAnalysis` | Strongest relapse evidence (RADAR-MDD, Matcham 2024) | | Read. Sleep score. |
| Sleep regularity (7-day spread of midpoint and duration) | Worked out | Irregular sleep predicted a worse course | | Rhythm score uses the 7-day spread of wake and bedtime against the person's own usual spread, and the 3-night midpoint against the usual midpoint |
| Resting heart rate | `restingHeartRate` | Autonomic state, illness filter | | Read. Body score and illness filter. |
| HRV | `heartRateVariabilitySDNN` | The autonomic signal the challenge names | Half weight. Own baseline per source. | Read. Full weight inside Body (Body is 5 % of the day score). No per-source baseline yet. |
| Breathing rate, wrist temperature | HealthKit | Mainly the illness filter | | Read. Body score. Wrist temperature is also in the illness filter. |
| Daylight minutes (and before 11:00) | `timeInDaylight` | Daylight, response to morning light | Split before and after 11:00 | Daily total read. Split not built. |
| Exercise minutes, workouts | HealthKit | Movement, response to a walk | | Exercise minutes read. Workouts not read by the running app. |
| Sleep stages, heart rate recovery | HealthKit | Weak evidence | Show, do not score | Stages read, not scored. Heart rate recovery not read. |

**Body score:** resting heart rate, HRV, breathing rate and wrist temperature. The illness filter works on top of them.

## Tier C: optional, light active measurement

At most **one prompt a day** on this tier.

| Measurement | How often | Use | In the app now |
|---|---|---|---|
| "How did it go?" after an action | One tap | Subjective side of the closed loop | Not built |
| Finger pulse with the camera (60 s, flash on, red-channel PPG → HR and RMSSD) | Before and after breathing, if wanted | HRV and response without a wearable | Not built |
| Voice check (same sentence for 15 s, analysed on the phone: pitch variation, pause ratio, speech rate) | Once a week, if wanted. Turned on in onboarding, never at a crisis moment. | Shown as a trend to the person (and nurse), not scored. Audio deleted at once. | Not built |
| State of Mind, PHQ-9 and GAD-7 from Health | Only if the person logs them | Shown for comparison | Read as context (iOS 18 and later). Shown in Trends under How you feel. Not scored. The app does not give these questionnaires. The Health request also asks to save State of Mind (for a check-in), but no current screen saves it. |
| PHQ-2 in the app | Every 2 weeks | Anchor that shows whether scores follow real wellbeing. A high score needs a defined response (crisis guidance). | Not built |

## Not collected

- **Calendar** (`calendarEvents`, `eventHours`) and **photo library** (`photosTaken`, `photosAwayFromHome`). Decision: remove `CalendarPhotosSource.swift` and the `NSCalendars…` and `NSPhotoLibrary…` usage strings. Now: nothing calls `CalendarPhotosSource.swift`, but the file and both usage strings in `project.pbxproj` are still there.
- **Passive microphone, camera or facial expression, call and message logs, keyboard analysis, Wi-Fi, makers' cloud APIs:** too much privacy harm. Recognition from faces is high risk under the EU AI Act.
- **Screen Time and SensorKit:** not available on a personal team or without research approval. `SensorKitSource` is only an empty protocol. (The backend also has an optional self-reported screen-time question. No current screen asks it.)
- **Fall risk and fitness:** walking asymmetry, double support, step length, stairs, 6-minute walk, walking steadiness, falls, VO₂max, low fitness.
- **Duplicates:** heart rate (average, min, max, walking), active and resting energy, physical effort, standing, flights, distances, cycling, vehicle, workout types and effort.
- **Heart and apnea alerts:** high, low and irregular heart rate, SpO₂, breathing disturbances.
- **Sound and other environment signals:** environment and headphone sound level, loud sounds, AirPods attenuation, UV, water, night listening. Now: the old reader in `HealthKitSource` can still read headphone timing and workouts for the DevTools screens. The running app does not ask for them or read them.
- **Other:** handwashing, toothbrushing, weight, height, age, sex (weight can cause anxiety). Now: older profile fields for these are cleared when the app starts.
- **Caffeine, alcohol and medication:** stigma. See Open decisions 3. Now: the running app reads no medication data. Medicine tasks exist, but the app has no dose data.
- **Symptom logs:** rarely used. Fatigue and headache could feed the illness filter.

The exception for nutrition and Mind data is in the update at the end of this file.

## Other data the app keeps

All of this stays on the phone. There is no server.

- **Profile** (`Application Support/Everyday/profile-v1.json`): first name, chosen people (name, phone number, loved one or friend), wake-up time and bedtime, the iPhone movement switch and today's step reading. The Health and Location switches are kept in the app's user defaults.
- **Planner state** (`planner.json`): setup, contacts and whether each has agreed, support preferences, daily tasks and their state, local records of prepared requests.
- **Contacts:** the system picker needs no permission. Contact suggestions ask for Contacts access and read given name, family name and first phone number. Only the people the person chooses are saved.
- **Widget** (App Group `sidequest-widget.json`): only the chosen task's day, id, wording, category, minutes, size and done state.
- **Health readings** are held in memory while the app runs. They are not saved by the app.
- **Location:** `visits.json` (see Open gaps).

## Closed loop: what works for this person

Not built. The plan: the old rule ("helped if Steadiness returns in 7 days") mostly measures regression to the mean. Instead, each action gets a **fast response** and a **next night response**, compared with the person's own drift days without the action. The person can start an action on any day ("Try one"), so data builds up faster. Counting the results gives an order, and no machine learning is needed.

| Action | Fast response | Next night or week |
|---|---|---|
| Slow breathing | RMSSD and heart rate during the session vs before (Watch or camera pulse), plus "How did it go?" | Falling asleep, time awake |
| Morning light | Daylight before 11:00 (or the step estimate) | Shift in midpoint and its spread |
| Short walk | Steps or workout in the window, places | Sleep efficiency, morning resting heart rate |

The person would see, for example: "Your heart rate slowed by 6 bpm in four of five sessions."

## What leaves the phone

Rules:

- **Nothing by default.** Sending starts only after the phone is paired with the clinic by QR code.
- **Content:** step, Steadiness, a one-line reason from a fixed template without location, and the actions tried and whether they helped.
- **Before any escalation** the person sees exactly what goes out and chooses "Send" or "Not now". A message to a friend is always sent by the person.
- **Lock-screen notifications are neutral,** for example "MindMaintainer has a suggestion".
- **Crisis guidance (112) is visible** in onboarding and at every step.
- **The app is described honestly:** "research prototype, not a medical device".

In the app now:

- There is no clinic pairing and no network code in the running app. Nothing is sent to a clinic.
- Reach out and task invitations open Messages with a draft. The person taps Send.
- The SMS demo runs the person's own Apple Shortcut, which sends one fixed test text to the contact the person set up in it. The app passes only an opaque run token: no Health values, phone number or message text.
- Notifications show only if the person has allowed them (the app asks when they set a task reminder). The task reminder says "A small step, when you're ready", with no task or Health details. The planner also schedules repeating notifications from its default setup: "Good morning" at 07:30, "Shopping day" on Tuesday and Saturday at 17:00 and "Evening wind-down" before bedtime. None of them names a health detail.
- 112 and the MIELI Crisis Helpline are shown in For you → Get support (for information only in the demo). Onboarding does not show them yet.

## Open decisions

1. **Location:** settled in practice as opt-in. It is off until the person turns it on, it is asked for separately with a reason, and scores work without it (Places is then left out).
2. **Personal weighting:** after about 4 PHQ-2 answers, should scores whose drop came before this person's worse answers get more weight? A strong "learns what works" point, but self-report would then affect the calculation indirectly.
3. **Caffeine, alcohol and medication:** drop them entirely (judge's view) or keep medication as an opt-in that is shown but never sent (privacy critic's view)?
4. **What from tier C goes into the demo?** Suggestion: first "How did it go?" and camera pulse, then the voice check, PHQ-2 last.

## Open gaps (code does not yet meet a rule)

- **Location storage:** `LocationSource` keeps every visited place's centre (rounded to 3 decimals, about 100 m) and the visits from the last 400 days in `visits.json` (complete file protection). The rule is one rounded home point, with coordinates deleted after the nightly calculation.
- **Calendar and photos:** `CalendarPhotosSource.swift` and the two usage strings are still in the repo.
- **HRV:** full weight inside Body and no per-source baseline.
- **Walking and still hours** are not stored daily, so only the last 7 days exist.
- **Crisis guidance** is not shown in onboarding.
- **Pause for 7 days** is not built (no tier C measurement exists yet).

## Facts to check before the pitch

- **HealthKit background delivery:** does the entitlement work on a free personal team? The app does not use it now. Health is read when the app becomes active.
- **Oura and WHOOP HRV:** do they write HRV to the `SDNN` type, and is the value then really RMSSD-like?
- **File protection:** use `completeUntilFirstUserAuthentication`, not `complete`, or a night-time calculation on a locked phone fails. Profile and planner files already use it. `visits.json` uses `complete`.
- **References:** check Stamatis 2024, Matcham 2024, Hernandez 2025 and Zhang 2022 from the originals.

## Beside demo scope update, 14 November 2026

The user explicitly requested the following additions for the demo: logged dietary energy, water, protein, carbohydrates and total fat, plus existing State of Mind, mindful minutes and PHQ-9/GAD-7 results. The active interface requests these read-only and displays them as context, separated from scoring and automatic contact rules. Missing records remain unknown; no meal count or diagnosis is inferred. The exact active read allow-list is documented in HEALTHKIT_DATA.md. This update supersedes earlier exclusions only for these explicitly named types.

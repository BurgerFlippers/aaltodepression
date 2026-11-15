# Usual

**Aftercare for people who just finished TMS treatment for depression.**
Junction 2026 · Aalto University challenge "Beyond the Clinic".

## The idea

TMS often works, but relapse is common in the first year. An early booster course often helps if worsening is caught early. Today, catching it early depends on the person noticing it themselves and asking for help, which is the hardest thing to do when things start to slip.

Usual is the patient side of an aftercare service. The phone and Apple Watch already measure how a person sleeps, moves and spends their days. Usual compares each day with **that person's own usual**, never with population norms, and notices when the days start to drift. When they do, it doesn't give a verdict. It brings in the plan the person made with their nurse:

1. **Days look like my usual** → nothing needed. The person types nothing on a normal day.
2. **Rhythm starts to drift** → Usual suggests one small action from the plan (morning light, a short walk, slow breathing) and picks the one that helped this person before.
3. **It doesn't settle in about 10 days** → a message the person wrote in advance goes to a friend ("Hei Ville, pyytäisitkö minut kävelylle…"), and the nurse calls.
4. **If that's not enough** → the nurse can offer a booster TMS session.

The difference isn't another wellness score. It's the service around it: the plan, the friend, the nurse and the booster, triggered early by transparent rules.

## How it works

```
Apple Health + iPhone sensors ─▶ one value per signal per day (≈100 signals, 365 days back)
        │
        ▼
Your usual: median and MAD of each signal over 28 days (the week just before is left out)
        │
        ▼
Six scores, 0–100 where 100 = your usual or better
  Sleep · Rhythm · Movement · Daylight · Places · Body
        │
        ▼
Steadiness = weighted mean (how close the day was to your usual)
        │
        ▼
Hidden step engine: a drift day = Steadiness more than 15 below your usual
  step 1: 5 of the last 7 days drifted   step 2: step 1 lasted 10 days
  Colds (resting HR, wrist temperature up) and travel (time zone, distance) never count.
```

- **No machine learning.** Every rule is readable, and every number can be traced back to the signals that moved it ("Sleep 5 h 11 min, usual 7 h 13 min, pulls down 11").
- **Sleep comes first.** Last night's sleep is part of today, because sleep shapes the next day more than the day shapes the next night. Rhythm compares your sleep timing regularity with your own usual regularity.
- **Missing data is unknown, never zero.** HealthKit cannot tell "denied" from "no data".
- **Everything stays on the phone.** Locations are reduced to daily numbers. An optional clinic endpoint receives only the step, Steadiness, a one-line reason and the actions tried.
- **No mood words, no red, no streaks, no badges.** State of Mind from Apple Health is never scored. It is shown next to Steadiness only to compare whether the two move together.

## Screens

- **Today**: one quiet line or one action row, Steadiness, and the six stripes. Tap any of them to drill in, as in Apple Health: a chart over week, month or all time, what moved the day, a sleep and activity chart, and the State of Mind comparison.
- **Plan**: the four rungs above with "You are here", each action's track record ("Helped 3 of 3 times"), the friend message, and Send now / Not this time.

## Demo

Settings → Demo mode. Perttu is synthetic: 60 days, steady until day 44, a cold on days 30–32, a trip on days 38–40, then a drift.

1. **Day 40**: nothing needed, close to his usual.
2. **Day 31**: a cold. Body drops, nothing escalates.
3. **Day 50**: "Slow breathing, 5 minutes?" Do a Breathe session on a real Apple Watch, and the row turns into "Done today" within seconds. Settings → Simulate a breathing session is the fallback.
4. **Day 59**: "Your message to Ville goes out tomorrow." Send now opens Messages, pre-filled. Laura will call.
5. **Demo off**: the same screens with your own Health data.

## Evidence it builds on

- About half of people who respond to TMS still meet response criteria at 6–12 months. Senova et al. 2019, *Brain Stimulation*.
- Restarting TMS when worsening was caught early brought most patients back. Janicak et al. 2010, *Brain Stimulation*.
- Sleep quality predicts next-day affect more than the reverse. Triantafillou et al. 2019, *JMIR Mental Health*.
- Sleep regularity predicts outcomes beyond sleep duration. Windred et al. 2024, *Sleep*; in recurrent depression, Matcham et al. 2024, *J Affect Disord*.
- More time at home than one's own average predicted higher depression scores two weeks later. Stamatis et al. 2024, *npj Mental Health Research*.
- Daylight exposure is linked to lower odds of depression. Burns et al. 2021, *J Affect Disord*.
- Variation within one person is larger than between people, so personal baselines beat population norms. Fisher et al. 2018, *PNAS*.

Using passive sensing to trigger an early TMS booster is the hypothesis this prototype is built to test, not an established fact.

## Build

### Xcode quick start

1. Open `aaltodepression.xcodeproj` in Xcode (this checkout was verified with Xcode 27.2).
2. Select the shared **aaltodepression** scheme and an **iPhone simulator** as the run destination.
3. Press **⌘R**. The app starts in demo mode on a fresh install; no Apple account or backend is needed for the simulator.
4. For a physical iPhone, add your Apple account in **Xcode → Settings → Accounts**, then choose your own team in the target's **Signing & Capabilities**. The checked-in team belongs to the original project setup. HealthKit requires a team/provisioning profile that supports that capability; if a Personal Team cannot provision it, use an eligible Apple Developer Program team.

Command-line simulator build (no signing required):

```sh
xcodebuild -project aaltodepression.xcodeproj \
  -scheme aaltodepression -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO
```

There is no XCTest target yet. Run the existing engine checks with `Tools/engine-check.sh`.
Use a physical iPhone and Apple Watch for real sensor data and Messages testing.

- Xcode 27, Swift 6, SwiftUI, SwiftData, HealthKit, Core Motion, Core Location, EventKit, PhotoKit. Minimum iOS 17.
- Run on a device with your own personal team (Signing & Capabilities). When Health asks how much history to share, choose **All Recorded Data**.
- Check the engine without Xcode: `Tools/engine-check.sh` prints Perttu's 60 days and verifies no escalation on the cold or the trip, step 1 on day 49 and step 2 on day 59.

| Folder | What's in it |
|---|---|
| `aaltodepression/Engine` | Pure Swift: baseline, scores, Steadiness, step engine, action history |
| `aaltodepression/Sources` | HealthKit, Core Motion, location visits, calendar, photos, solar times, demo data |
| `aaltodepression/UI` | Today, Plan, detail pages, settings |
| `docs/` | The original build brief |

A prototype, not a medical device. It doesn't diagnose anything.

## Beside first iPhone version

The active interface is `Features/Everyday/EverydayRootView.swift`: English onboarding, personal profile and contact suggestions with Loved one/Friend roles. Today shows Eat, Move, Sleep and Connect with circular completion controls, followed by visible Reminders. Household checks are spaced out. Social invitations open the system Messages composer for the user to send. Background support delivery remains a local prototype; the backend integration is described below.

Run `Tools/everyday-check.sh` for the new local planner and persistence checks; `Tools/engine-check.sh` still checks the original sensing engine.

### Revision 2

The active UI is English with native wheel/time pickers. Today shows four task toggles and Reminders; Your people lives under You. Optional Motion & Fitness reads today's steps; 500 observed steps can fill the movement row, with manual correction. Optional Apple Health reads recorded asleep intervals without double-counting overlapping sources. No phone inactivity is presented as confirmed sleep. MIELI is the support call action. Sensor reads refresh while Today is open and when the app becomes active. Background support delivery remains a local demo.

### Backend UI integration

The active frontend now owns `Backend` through `BesidePresentation`: the planner supplies task state, reminders, check-ins and social plans; tracking receives available real Motion and sleep signals. The earlier Everyday store retains profile/sensor inputs for migration, not the active home task state. Eat explicitly marks a meal, separately from grocery shopping. Connect stores a social/connect mark in the planner; medication moves to Reminders. Messages use the supplied templates plus editable text and native compose result handling.

Demobar is a visibility-only overlay of the actual Backend instance: real check-ins, available sensor readings, the resulting day plan and backend call suggestions. It never switches to sample data. The overlay can be hidden in You → About Beside → Show Demobar; Debug builds show it by default and Release builds hide it by default. The light-green to dark-red gradient presents backend capacity and call suggestions. A dashed marker identifies the provisional plan when check-in and sensor readings are unavailable. Completion feedback is driven by backend task state and respects Reduce Motion.

The new backend still simulates support delivery locally, as documented in `docs/BACKEND_API.md`. The UI labels requests accordingly. Automatic delivery to another person's phone is not provided by this pull.

### Day-by-day judging controls

Tap the Demobar controls icon to browse up to 120 days of available Health history. Select a date to open an isolated, in-memory copy of the real planner, inspect readings and apply labelled demo overrides. Edits are session-only, never written to Health or the live planner. Return to live today restores the live instance. Hiding the bar also returns to live mode.

The Health connection requests read-only access for steps, walking speed, exercise, daylight, resting heart rate, HRV, breathing rate, wrist temperature and recorded sleep. Shared daily readings flow through the existing StepEngine; the bar visualises its changes from the personal baseline. Live mode uses the last complete day, while the demo evaluates the selected day. Missing data remains unknown and the provisional fallback marker is dashed. This is a prototype change indicator, not a depression diagnosis.

Home starts with Eat, Move, Sleep, Social, Medicine and Cleaning. The pencil opens native reorder/delete controls, hidden presets and custom boxes; layout preferences persist locally. Generic Medicine and Cleaning marks do not create dosing schedules or infer a specific chore's completion. Profile entry now asks for name only; the retired demographic fields are cleared when the interface starts. Your people keeps the contact list and per-person role picker. Get support puts personal contacts before the Emergency helpline section.

### Actions and user-led contact

The six category boxes keep their size and add short subtitles. Actions replaces Reminders. The check-in uses coloured cards and the clearer “How is your energy today?” question. Reach out opens Messages for the selected person without a body or app-side send tracking; optional writing help is collapsed by default and uses the system composer for an editable draft.

Support choices are grocery shopping, pharmacy visits, home cleaning and social contact. `ReachOutRules` only proposes contact after two active days with an unmarked category; it does not queue a message or infer what happened outside Beside. The separate automatic-request judging scene is gated by sandbox mode, opt-in and recipient agreement and reuses existing message limits. No automatic messages are delivered.

[HealthKit read scope](docs/HEALTHKIT_DATA.md) lists every active signal. Nutrition and Mind are optional read-only context, separated from automatic scoring and contact rules. Rules and message templates remain in Engine, persistence and orchestration in Store, Health reads in Sources, and screen state and composition in Features.

### Routine feedback and flat profile

Routine replaces the Today tab label. The profile page shows name, daily rhythm and people in one scrollable page, titled with the person's name. Contacts use ID-resolved role bindings so deleting a row while its menu closes cannot access a stale array index.

The Demobar now presents the Health-based position plus small, explicitly labelled routine feedback. Each manually logged category contributes a 1.5 percentage-point greenward shift, up to 9; undo and day selection recompute it from saved marks. This does not alter the Health engine or suppress support suggestions.

### Challenge demo and widget (2026-11-15)

Routine now offers three daily tasks from a 30-task library across Eat, Move, Sleep, Social and Medicine. Task type, icon and shade distinguish choices within one category. Tap a task to choose it and receive encouragement. Invite someone (where relevant) and Remind me are optional; there is no manual completion step. The reminder requests permission only when explicitly saved, uses a native time wheel and opens the current live task. Messages are reviewed and sent by the user.

Add Mind's **Your small step** widget to the Home Screen after opening the updated app. It shows the live selected task without a completion button. Legacy widget completion receipts are discarded. Before a task is selected, the widget opens the daily choices. Demo overrides, Health measurements and contacts are not shared with the widget. Widget refresh scheduling is controlled by iOS.

The app and widget share their signing identity via `Config/Signing.xcconfig`. For local development, create ignored `Config/LocalSigning.xcconfig` with `BESIDE_HOST_BUNDLE_IDENTIFIER = your.unique.bundle` and `BESIDE_DEVELOPMENT_TEAM = YOURTEAMID`. The private App Group is `group.<host bundle identifier>` and must be provisioned for both targets. Never commit the local override file.

### Native challenge and Demo tabs (2026-11-15)

Routine shows only today's live challenges. Choose directly on a card; its single heading contains the task. Selection time is saved without marking completion. The Trends tab holds the single date picker, demobar, category context, daily readings and actual challenge selection. Browsing a past day or editing demo readings never changes today's live challenge. Check-in and general Reach out remain available in You.

Demo's Phone SMS test uses the saved Konsta contact, with no hardcoded number. Review the harmless draft and tap Send in native Messages. Sent confirmation comes from MessageUI, with a five-minute cooldown. This is a phone-originated test, not the optional simulated automatic-support service.

### Mind appearance (2026-11-15)

The app and widget now display the name Mind. The existing bundle identifiers and stored data remain compatible. All active screens use a dark system palette with amethyst accents. The home screen has three purple challenge tiles, each with one symbol and the short task as its only heading. Tap a tile to choose it; no Start, Make smaller or duration controls are shown inside the choices. Existing low-capacity rules can still offer the smaller version automatically.

### Selection and Health recovery (2026-11-15)

Choosing is the only required challenge interaction. Trends distinguishes a saved choice, assumed completion and supporting passive activity. Daily step/daylight/nutrition totals can be compared with the snapshot at selection; backfilled daily logs do not prove a particular task was performed. Sleep preparation, social and medication tasks remain unverified when no suitable evidence is available. No missing-data penalty or clinical score is introduced.

Health reads now report query failures rather than silently presenting them as empty entries. Overlapping foreground refreshes are queued, and a wholly failed read preserves the last in-memory snapshot. The repair release requests the existing read permissions once; Trends also exposes manual access review and refresh. Previously denied types require enabling them in Health. Each date still shows only its own readings. Category scores are shown only for Sleep and Move when a baseline exists; other categories show context or missing-source status.

Trends initially opens the most recent complete day with shared readings. Today remains available in its single native calendar and is labelled as a partial day. Both the main tab and reading editor show the selected date and how many measurement types have entries, so unrecorded nutrition or assessment types are not confused with a failed connection.

### Trends and foreground message demo (2026-11-15)

Trends shows daily balance and expandable Eat, Move, Sleep, Social and Medicine summaries. Health readings are in a separate sheet; the toolbar's Demo button opens the judging controls. For you now contains Check in and Reach out. The back arrow on a selected challenge returns to its three choices.

For the message demo, open Trends → Demo, choose a saved test recipient and enable **Prepare a test request automatically**. Drag the slider towards Harder days and release it. The simulated input history is evaluated by the existing scoring and support rules; a support signal prepares one pending call request. On an iPhone, Messages opens for review and the person taps Send. Every test draft starts with **Mind DEMO TEST — no action needed**. Submission confirmation comes only from MessageUI, with a five-minute cooldown; delivery is not verified. Cancel/failure do not mark a send. Reset restores the real reading snapshot and clears the in-memory scenario. Health and live records remain unchanged.

The current transport is native foreground Messages, not a background SMS service. A server sender still needs its endpoint and authentication contract. No service secrets belong in this repository.

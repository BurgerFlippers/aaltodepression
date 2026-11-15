# Backend API for the frontend

One object, plain data in, one method per tap. Everything here is in the backend's folders
(`Engine/`, `Store/`, `Sources/`), so wiring it up never needs a backend file changed.

Checked against the code on 15 November 2026. The backend test screens in `DevTools/` open only from the old
`UI/SettingsView` ("Backend testing"), which the running app does not show.

## 1. Who owns `Backend`

`BesidePresentation` (`Features/Everyday/BesidePresentation.swift`) owns the live `Backend` and, while Trends is open,
an in-memory demo copy (a sandbox `Backend` with `isDemo: true`). Views read `presentation.backend`, which points to
whichever is active, or `presentation.liveBackend`.

```swift
let backend = Backend()                    // real data, saved on the phone
// let backend = Backend.demo(day: 50)     // demo user Perttu, synthetic day 1–59 (tests and DevTools)

// After every Health read and when the app becomes active:
backend.refresh(table: table, history: history, locationEnabled: usesLocation)
```

`Backend` holds three services: `planner` (the daily planner), `tracking` (sleep, activity, places)
and `permissions`. All are `@Observable`, so screens update by themselves.

`BesidePresentation.refresh()` reads Health (`HealthKitSource.readReport`, 120 days, key allow-list), Location
(`LocationSource`) and Core Motion, removes the context-only Nutrition and Mind keys, runs `StepEngine.run(...)`, then calls
`backend.refresh(...)` and `planner.prepareSidequests(signal:)`. The Health permission sheet is opened by
`BesideHealthAccess.request()` in Features, not by `permissions.request(.health)`.

## 2. Used by the running app

| Screen | Reads | Calls |
|---|---|---|
| Onboarding and You: name, rhythm, people | `planner.setup`, `planner.isSetUp` | `planner.updateSetup(_)` (via `BesidePresentation.syncSetup()`; also reschedules daily notifications) |
| Onboarding and You: support in advance | `planner.setup.supportPreferences`, `planner.setup.contacts` | `planner.updateSetup(_)` |
| One thing: three tasks | `planner.state.sidequests[day.jdn]` (`SidequestDay`), `planner.currentDay` | `prepareSidequests(signal:replaceUnchosen:)`, `startSidequest(_:smaller:on:observations:)`, `changeSidequest(on:)`, `completeSidequest(on:)`, `completeAnotherSidequest(_:on:)`, `setSidequestReminder(_:on:)` |
| One thing: demo task preview | `SidequestDemoRules.preview(day:scores:)` | – |
| Trends: balance and signals | `StepDay` from `StepEngine.run` (`presentation.healthHistory`), readings from the presentation's feature table | – |
| Trends: SMS demo (sandbox only) | – | `planner.prepareDemoSMS()` |
| Reach out and invitations | `planner.setup.contacts`, `MessageTemplates.reachOut(_:contact:)`, `Sidequest.invitation` | – (the person sends in Messages) |
| App delegate | – | `PlannerNotifications.registerCategories()`; `action(for:)` → `planner.handle(_:deliveredAt:)` |

`planner.mark(_:_:)` is still called for the legacy home-box marks in `BesidePresentation`; no current screen shows those boxes.

## 3. Available, not used by the running app

These work and are covered by `Tools/engine-check.sh`, but no current screen calls them:

| Feature | Reads | Calls |
|---|---|---|
| Permissions | `permissions.status[kind]`, `PermissionKind.title`, `.reason` | `await permissions.request(kind)`, `requestAll()` |
| Contacts from the picker | `ContactIntake.problem(contact)` | `planner.addContacts([(name, phone)])` |
| Check-in | `planner.today.needsCheckIn`, `QuestionCatalog.checkIn` | `planner.submitCheckIn([questionID: Answer])` (also saves State of Mind to Health outside the demo) |
| Shop question | `planner.today.asksAboutGroceries` | `planner.answerGroceries(_)` |
| Plans with people | `planner.today.upcomingPlans`, `.asksAboutSocial` | `acceptSocial(_)`, `answerSocial(planID:met:)` |
| Screen time (self-report) | `planner.today.asksAboutScreenTime`, `QuestionCatalog.screenTimeQuestions` | `planner.answerScreenTime([questionID: Answer])` |
| Today's list | `planner.today.items` | `planner.mark(item, .done / .skipped / .open)`, `planner.shrink(item)` |
| Cards | `planner.today.cards` | `send(_)`, `dismiss(_)`, `acceptSocial(_)`, `startSafety()` |
| Reach-out suggestion | `planner.today.reachOutPrompt` | `dismissReachOutPrompt(_)` |
| Messages | `planner.messagesToday`, `planner.openMessages` | `confirm(messageID:)`, `cancel(messageID:)`, `receiveReply(messageID:)` (demo) |
| Automatic support demo | `planner.setup.supportPreferences` | `demonstrateAutomaticSupport(_)` (demo planner only) |
| Safety questions | `planner.safety?.step`, `SafetyCopy` | `safetyContinue()`, `safetyAnswer(_)`, `finishSafety()` |
| Crisis lines | `planner.crisisLines` | – |
| Rewards | `planner.today.reward`, `planner.rug`, `planner.weekSummary` | – |
| Sleep, activity, places, screen time | `tracking.sleep`, `.activity`, `.places`, `tracking.snapshot?.screenTime` | – |
| Erase | – | `planner.eraseAll()` |

## 4. Shapes worth knowing

- **Tasks** (`Engine/Contracts/Sidequest.swift`): `Sidequest { id, category, regular, smaller }` with
  `SidequestCategory` `sleep / movement / nutrition / social / medicine`. `SidequestDay` holds the three options, the
  reason, the signal day, `startsSmall`, the chosen id, `useSmaller`, start, completion, reminder and `alsoDoneIDs`.
  The catalog is `SidequestRules.catalog` (30 tasks).
- **Scores** (`Engine/Scores.swift`, `Engine/StepEngine.swift`): `StepDay.result.scores[ScoreKind]`,
  `.result.steadiness` (day score), `.step` (`steady / nudge / reachOut`), `.driftDaysInLastWeek`, `.baselineDay`
  (nil while the usual is still being learned).
- **Questions** (`Engine/Contracts/Questions.swift`): every question is `Question { id, prompt, kind }`.
  `AnswerKind` is one of `likert(1...5)`, `scale`, `multiSelect`, `singleChoice`, `yesNo`, `numeric(range, step, unit)`,
  so one component per kind renders all of them. Answers are `Answer.number / .option / .options / .yes`.
- **Tracked values** (`Engine/Contracts/Tracking.swift`): `TrackedValue` already has `text`
  ("7 h 12 min"), `usualText` ("usual 7 h 30 min") and `comparison` (`below / usual / above / unknown`).
  Missing data is `unknown` with text "–", never zero. `TrendPoint.value == nil` means a gap.
- **Today** (`Engine/Contracts/TodayPlan.swift`): `PlanItem` has title, detail, time, status, who ticked
  it (`doneBy`: person, sensors, Health) and `evidence` ("Your phone saw a 15-minute walk").
- **Support preferences** (`Engine/Contracts/Support.swift`): optional `PlannerSetup.supportPreferences`, decoding older
  setups unchanged. Topics: groceries, pharmacy, cleaning and social, each with a chosen person, plus `automaticDemo`.
  `HelpKind` has `pharmacyRun` and `homeCleaning`.
- **Messages**: in the prototype nothing is sent by the backend. `OutgoingMessage.status` goes pending → sent →
  replied (demo: `receiveReply`), or cancelled. `planner.notifySimulatedSends` shows a local notice.
- **SMS demo**: `prepareDemoSMS()` queues one pending request from the existing call-signal rule and never confirms it.
  The running app's SMS demo (`BesideSMSDemo` in Features) does not use it: `DemoShortcutSender` (`Store/`) opens the
  person's "Mind Demo SMS" shortcut (`DemoShortcutLink`) with "number\nmessage" as text input and keeps a one-minute cooldown.
- **Notifications**: `NotificationPlan.daily(for: setup)` lists the repeating notifications. `updateSetup(_)`
  schedules them outside the demo while `Planner.schedulesDailyPlan` is true; the running app sets it to false.
  `SidequestReminders` handles the one-off task reminder.
- **Health reads**: `HealthKitSource.read(..., keys:)` and `readReport(..., keys:)` take an optional allow-list;
  omitting it keeps the older full read. See [HEALTHKIT_DATA.md](HEALTHKIT_DATA.md).

## 5. Rules the backend already enforces

Messages to contacts: only agreed contacts, at most two a week, only 08–20, never health words,
never again after Cancel. The running app always sets `helpConsent = .askEachTime`, so nothing is sent automatically.
Safety questions: once a day, never from a notification, answers never stored.
Rewards: nothing is ever taken away. Data: only the agreed signals ([DATA_SCOPE.md](DATA_SCOPE.md)).

Reach-out suggestions (`ReachOutRules`) need two preceding full days with real activity in the app and an unmarked
category, and respect completion and dismissal. Silent days do not count. A default Medicine box does not establish
medicine use. `demonstrateAutomaticSupport` works only when `isDemo`, the topic and the automatic demo are enabled, and
the chosen contact is agreed and supports that kind. It creates local records only.

## 6. Checks

`Tools/engine-check.sh` compiles all of `Engine/` without SwiftUI, with `Sources/DemoSource.swift` and
`Sources/DemoPlannerSource.swift`, and runs the step-engine table and the backend, planner, reach-out, task, demo
scenario and SMS demo checks.
It must print `ALL CHECKS PASSED` before a backend commit. `Tools/everyday-check.sh` checks the profile store.

# Backend API for the frontend

One object, plain data in, one method per tap. Everything here is in the backend's folders
(`Engine/`, `Store/`, `Sources/`), so wiring it up never needs a backend file changed.
Try every piece in the app: **Settings → Backend testing**.

## 1. Own one `Backend` (integrator, AppModel)

```swift
let backend = Backend()                    // real data, saved on the phone
// let backend = Backend.demo(day: 50)     // Demo user, synthetic day 1–59

// After every Health read and when the app becomes active:
backend.refresh(table: table, history: history, locationEnabled: location.isEnabled)
```

`Backend` holds three services: `planner` (the daily planner), `tracking` (sleep, activity, places)
and `permissions`. All are `@Observable`, so screens update by themselves.

## 2. What each screen reads and calls

| Screen | Reads | Calls |
|---|---|---|
| Onboarding: permissions | `permissions.status[kind]` (Backend refreshes it; call `await permissions.refresh()` on screen appear to be sure), `PermissionKind.title`, `.reason` | `await permissions.request(kind)`, `requestAll()` |
| Onboarding: contacts | `planner.setup.contacts`, `ContactIntake.problem(contact)` | system picker → `planner.addContacts([(name, phone)])` |
| Onboarding: times, medication, must-dos, clinic | `planner.setup` | `planner.updateSetup(_)` (also schedules reminders) |
| Home: check-in | `planner.today.needsCheckIn`, `QuestionCatalog.checkIn` | `planner.submitCheckIn([questionID: Answer])` |
| Home: shop question | `planner.today.asksAboutGroceries` | `planner.answerGroceries(_)` |
| Home: plans with people | `planner.today.upcomingPlans`, `planner.today.asksAboutSocial` | `acceptSocial(_)`, `answerSocial(planID:met:)` |
| Home: screen time (bonus, optional) | `planner.today.asksAboutScreenTime`, `QuestionCatalog.screenTimeQuestions` | `planner.answerScreenTime([questionID: Answer])` |
| Home: today's list | `planner.today.items` | `planner.mark(item, .done / .skipped / .open)`, `planner.shrink(item)` |
| Home: one card | `planner.today.cards.first` | `send(_)`, `dismiss(_)`, `acceptSocial(_)`, `startSafety()` |
| Home: messages | `planner.messagesToday`, `planner.openMessages` | `confirm(messageID:)`, `cancel(messageID:)` |
| Safety sheet | `planner.safety?.step`, `SafetyCopy` | `safetyContinue()`, `safetyAnswer(_)`, `finishSafety()` |
| Get help now | `planner.crisisLines` | – |
| Reward | `planner.today.reward`, `planner.rug`, `planner.weekSummary` | – |
| Sleep, activity, places | `tracking.sleep`, `.activity`, `.places` | – |
| Screen time (bonus) | `tracking.snapshot?.screenTime` | – |
| App delegate | – | `PlannerNotifications.registerCategories()`; `action(for:)` → `planner.handle(_:deliveredAt:)` |
| Settings: erase | – | `planner.eraseAll()` |

## 3. Shapes worth knowing

- **Questions** (`Engine/Contracts/Questions.swift`): every question is `Question { id, prompt, kind }`.
  `AnswerKind` is one of `likert(1...5)`, `scale`, `multiSelect`, `singleChoice`, `yesNo`, `numeric(range, step, unit)`,
  so one component per kind renders all of them. Answers are `Answer.number / .option / .options / .yes`.
- **Tracked values** (`Engine/Contracts/Tracking.swift`): `TrackedValue` already has `text`
  ("7 h 12 min"), `usualText` ("usual 7 h 30 min") and `comparison` (`below / usual / above / unknown`).
  Missing data is `unknown` with text "–", never zero. `TrendPoint.value == nil` means a gap.
- **Today** (`Engine/Contracts/TodayPlan.swift`): `PlanItem` has title, detail, time, status, who ticked
  it (`doneBy`: person, sensors, Health) and `evidence` ("Your phone saw a 15-minute walk").
- **Messages**: in the prototype nothing is sent. `OutgoingMessage.status` goes pending → sent →
  replied (demo: `receiveReply`), or cancelled. `planner.notifySimulatedSends` shows a local notice.
- **Notifications**: `NotificationPlan.daily(for: setup)` lists what goes on the lock screen.
- **Screen time (bonus)**: Apple lets apps read Screen Time only with the Family Controls entitlement and a
  report extension (not possible on a free team), so the person answers an optional morning question: a range,
  or the exact minutes from Settings → Screen Time, plus "phone in bed?". It becomes the signals
  `screenTimeSelf` and `phoneInBed`, is compared with the person's own usual, and steers the wind-down step.
  Switch off with `setup.asksScreenTime = false`.

## 4. Rules the backend already enforces

Messages to contacts: only agreed contacts, at most two a week, only 08–20, never health words,
never again after Cancel. Safety questions: once a day, never from a notification, answers never stored.
Rewards: nothing is ever taken away. Data: only the agreed signals (docs/DATA_SCOPE.md).

## 5. Checks

`Tools/engine-check.sh` compiles all of `Engine/` without SwiftUI and runs the demo scenarios.
It must print `ALL CHECKS PASSED` before a backend commit.

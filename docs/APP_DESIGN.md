# MindMaintainer: app design

What the app is and how it works today. Data rules: [DATA_SCOPE.md](DATA_SCOPE.md). Health types read: [HEALTHKIT_DATA.md](HEALTHKIT_DATA.md). Backend calls: [BACKEND_API.md](BACKEND_API.md).

Last checked against the code: 15 November 2026.

## 1. What it is

An iPhone app for people in their first year after TMS treatment for depression. It compares Apple Health and phone signals with the person's own usual, offers one small daily task, and helps them reach the people they chose in advance.

- Display name: MindMaintainer (app and widget). Swift identifiers still use `Beside`, `Everyday` and `Usual` from earlier names.
- iOS 17 or later, SwiftUI, Swift 6. Dark appearance, English UI.
- Root view: `EverydayRootView` (`Features/Everyday/`). The old "Usual" UI in `aaltodepression/UI/**` and `AppModel.swift` is still in the repo but does not run.
- Everything is worked out on the phone. There is no server.

## 2. Principles in the code

- Compare with the person's own history only (median and MAD over the previous 28 days). No population norms, no machine learning.
- Missing data stays unknown. It never counts as zero or as a bad day.
- The support step is hidden and never shown as a number.
- Nutrition and Mind readings are context only. They never change scores, tasks or contact rules.
- Nothing is sent to another person without the person's own action (see section 7).

## 3. Onboarding

A welcome page, then five steps. Steps 1 to 3 have "I'll do this later"; everything can be finished later in the You tab.

1. **Your name:** first name only.
2. **Your people:** pick from Contacts, from contact suggestions, or enter a number. Each person is a loved one (practical help) or a friend (company).
3. **Support in advance:** choose practical topics (grocery shopping, pharmacy visits, home cleaning, social contact), a helper for each, and the Automatic support switch.
4. **Your rhythm:** usual wake-up time and bedtime.
5. **Ready:** switches for Apple Health, Location and iPhone movement.

## 4. Tabs

### Today's one thing (tab "One thing")

- Three task choices for today, built by `SidequestRules` from the last complete day's Health scores (section 6).
- Tapping a card chooses it. Then: "Mark as done", "Invite someone" (for tasks that suit company) and "Remind me" (one reminder today).
- After Mark as done the app shows praise and lets the person mark the other two as extra, only if they want.
- "Why these challenges?" shows the reason for today's choices.
- "Show more tasks (demo)" opens a preview with sliders for the six score areas. It shows which tasks those scores would pick. Nothing is saved.

### Trends

- Day picker: today and the previous 120 days. It opens on the latest complete day with readings.
- **Switch to demo data:** three scenarios (Steady, A few harder days, A harder stretch) on simulated history. Real data is untouched, and leaving the tab clears it.
- **Send SMS demo:** shown only with A harder stretch (section 7).
- **Daily balance:** the day score (0 to 100) on a scale from "Your usual" to "More support", a 4-week chart with a 7-day average, and how many of the last 7 days were further from usual.
- **Your signals:** eight rows (Sleep, Daily rhythm, Getting out, Movement, Daylight, Body, How you feel, Food). The first six show their area score. How you feel and Food are not scored. Getting out needs Location.
- **Advanced demo menu:** triple tap on the Trends title. It holds the SMS message test, "Use simulated data" (60 simulated days ending today instead of Health), the current challenges, per-area score sliders, a demo difficulty slider, and "Health readings and fine-tuning" for editing readings. All edits stay in an in-memory copy.

### For you

- **Reach out:** choose a person and a topic. "Help me write it" makes a short first-person draft that greets the person by first name. The app copies the draft and opens that person's Messages conversation. The person sends it.
- **Get support:** call a saved person with one tap. Below that, MIELI Crisis Helpline 09 2525 0111 and 112 are shown for information only and cannot be tapped (demo).

### You

The same settings as onboarding, in the same order: name, your people, support in advance, daily rhythm, and Health, Location and iPhone movement.

## 5. Widget and reminders

- Widget "Your small step" (small and medium) shows the chosen task for today. Tapping opens the app. It cannot mark the task done.
- The widget's App Group file holds only the task's day, id, wording, category, minutes, size and whether it is done. No Health values, contacts or demo data.
- "Remind me" schedules one local notification today with private text ("A small step, when you're ready"). It is removed when the task is done or changed. Notification permission is asked only here.
- The planner's repeating daily notifications (morning check-in, medicine, shopping day, wind-down) are off in the running app: `BesidePresentation` sets `Planner.schedulesDailyPlan = false`, which also removes any already pending. The only notification is the task reminder from "Remind me".

## 6. How the day is decided

All of this is in `Engine/`.

- **Scores** (`Scores.swift`): Sleep, Rhythm, Movement, Daylight, Places and Body, each 0 to 100 where 100 is your usual or better. Day score is their weighted mean: Sleep 0.30, Rhythm 0.25, Movement 0.20, Daylight 0.10, Places 0.10, Body 0.05, renormalised over the areas that have data. Places only counts when Location is in use.
- **Context flags:** `likelyIll` (resting heart rate or wrist temperature above usual) and `travelling` (other time zone or more than 100 km from home). On those days a low score is not drift.
- **Step engine** (`StepEngine.swift`): a drift day is more than 15 points below the person's usual day score. 5 drift days in the last 7 give step 1 ("A little support could help"). 10 more days give step 2 ("Time to reach out"). 2 or fewer drift days in the last 7 return to steady.
- **Tasks** (`Planner/SidequestRules.swift`): 30 tasks, six for each of Eat, Move, Sleep, Social and Medicine, each with a regular and a smaller version.
  - The Sleep category uses the lower of the Sleep and Rhythm scores. Move uses the lower of Movement and Daylight.
  - Two choices come from the lower category. The third comes from the other category if its score is under 80.
  - Smaller versions are used when the lowest score is under 45, on a `likelyIll` day, or at step 2.
  - Without usable scores the app offers three general ideas and says so.
  - Health data older than one day is not used.
  - Completing a task never changes scores or sends anything.

## 7. Support and messages

- The running app always saves the contact setting as "ask each time". It never sends a message by itself.
- Reach out and task invitations open Messages, and the person taps Send.
- The Automatic support switch saves the person's choice and marks the chosen helpers as agreed. In this prototype no automatic request is delivered.
- **SMS demo:** in a demo scenario that reaches a support step, the app can run the person's own Apple Shortcut "Mind Demo SMS". The shortcut sends one fixed test text to a contact named Konsta. The app passes only an opaque run token, at most one attempt per five minutes, and a finished shortcut is not proof of delivery.
- Backend rules for automatic suggestions: only agreed contacts, at most two a week, only between 08 and 20, no health words, never again after Cancel. They are in `Engine/Planner/` and are still enforced.

## 8. Code layout

Ownership is in [CLAUDE.md](../CLAUDE.md). Logic does not live in `Features/`.

| Folder | Contents |
|---|---|
| `Engine/` | Pure Swift, no SwiftUI: baseline, scores, step engine, planner rules, task catalog, message templates, safety flow. `Engine/Contracts/` is the shared contract. |
| `Sources/` | HealthKit, Core Motion, Core Location, contacts, simulated and demo data. |
| `Store/` | `Backend`, `Planner`, saved state, permissions, notifications, SMS demo sender. |
| `Features/Everyday/` | All running SwiftUI views and `BesidePresentation`, the adapter between views and `Backend`. |
| `BesideWidget/`, `SharedSidequest/` | Widget target and the App Group file it shares with the app. |
| `UI/`, `AppModel.swift` | Old "Usual" prototype. Not shown. `UI/MessageCompose.swift` is still used. |
| `DevTools/` | Backend test screens. Only reachable from the old `UI/SettingsView`, so not from the running app. |

Checks: `Tools/engine-check.sh` (engine and demo scenarios) and `Tools/everyday-check.sh` (profile store).

## 9. Built but not in the running UI

These exist in `Engine/` and `Store/` but no current screen uses them:

- daily check-in (mood and energy), and saving it to Health as State of Mind;
- safety questions (`SafetyFlow`, `SafetyCopy`). The texts are drafts for a doctor to review;
- cards for food help, social plans and the clinic;
- the old daily list, grocery and screen-time questions, rewards, and medication reminders.

The earlier "Loimi" plan (woven rug reward, Food and Evening tabs, medication tab) was not built.

## 10. Open items

- `CalendarPhotosSource.swift` and the Calendar and Photos permission texts in `project.pbxproj` are still in the repo, although calendar and photos are outside the data scope.
- Location storage does not yet meet the rule in [DATA_SCOPE.md](DATA_SCOPE.md) (see there).
- Automatic support delivery needs a real sending service and an agreement from the recipient.

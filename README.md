# MindMaintainer

An iPhone app for people in their first year after TMS treatment for depression. It compares Apple Health and phone signals with the person's own usual, offers one small task each day, and makes it easier to reach the people they chose in advance. Built at Junction 2026 for the Aalto University challenge "Beyond the Clinic".

A prototype, not a medical device. It does not diagnose anything.

## Why

TMS often works, but relapse is common in the first year, and an early booster course helps more when worsening is caught early. Today that depends on the person noticing the change and asking for help, which is hardest to do when things start to slip. MindMaintainer watches for drift from the person's own baseline and responds with small, concrete steps and the people they picked, not with a verdict.

## The app

Display name MindMaintainer. iOS 17 or later, SwiftUI, Swift 6, English UI. The running interface starts at `Features/Everyday/EverydayRootView.swift`.

**Onboarding:** a welcome page and five steps: first name; your people (from Contacts, suggestions or a typed number, each a loved one or a friend); support in advance (grocery shopping, pharmacy visits, home cleaning, social contact, a helper for each, and an Automatic support switch); usual wake-up and bedtime; and switches for Apple Health, Location and iPhone movement. Steps 1 to 3 can be skipped and finished later.

**Tabs:**

- **One thing** ("Today's one thing"): three task choices built from the last complete day's Health scores. Choose one, then Mark as done, Invite someone or Remind me. After Mark as done the app offers the other two as optional extras.
- **Trends:** Daily balance (day score from "Your usual" to "More support"), a 4-week chart, and eight signal rows: Sleep, Daily rhythm, Getting out, Movement, Daylight, Body, How you feel, Food. How you feel and Food are shown but never scored. Getting out needs Location.
- **For you:** Reach out (pick a person and a topic, optionally get a short draft that greets them by first name, then send it yourself in Messages) and Get support (call a saved person; MIELI Crisis Helpline and 112 are listed for information and cannot be tapped in this demo).
- **You:** every onboarding setting, in the same order.

**Widget:** "Your small step" (small and medium) shows today's chosen task and opens the app. It cannot mark the task done and holds no Health values or contacts.

## How the day is decided

All rules are in `Engine/`, in plain Swift with no machine learning.

```
Apple Health + iPhone sensors -> one value per signal per day
Your usual: median and MAD of each signal over the previous 28 days
Six area scores, 0-100 (100 = your usual or better):
  Sleep 0.30 · Rhythm 0.25 · Movement 0.20 · Daylight 0.10 · Places 0.10 · Body 0.05
Day score = weighted mean over the areas that have data
Hidden step engine: a drift day is more than 15 points below your usual day score
  step 1: 5 drift days in the last 7     step 2: 10 more days
  Likely illness (resting HR or wrist temperature up) and travel never count as drift.
```

Tasks come from a 30-task library (Eat, Move, Sleep, Social, Medicine), aimed at the weakest areas, with smaller versions when scores are low, on a likely-ill day or at step 2. Missing data stays unknown and never counts as a bad day. The step is never shown as a number. Details: [docs/APP_DESIGN.md](docs/APP_DESIGN.md).

## Demo

- **Trends → Switch to demo data:** three scenarios (Steady, A few harder days, A harder stretch) on a simulated history. Real data is untouched, and leaving the tab clears it.
- **Send SMS demo:** appears with A harder stretch. It runs the person's own Apple Shortcut named **Mind Demo SMS**, which sends one fixed test text to a contact named Konsta. The sheet explains the one-time setup. The app allows one attempt per five minutes and passes no Health data, contacts or message text to the shortcut. A finished shortcut is not proof of delivery.
- **One thing → Show more tasks (demo):** sliders for the six areas show which tasks those scores would pick. Nothing is saved.
- **Advanced demo menu:** triple tap the Trends title. It has the SMS test, 60 simulated days instead of Health, per-area score sliders, a difficulty slider, and editing of Health readings. Everything stays in an in-memory copy.

`Tools/engine-check.sh` also runs the synthetic patient Perttu (60 days, a cold on days 30 to 32, a trip on days 38 to 40, then drift) and checks that the cold and trip do not escalate, step 1 comes around day 49 and step 2 around day 59.

## Data and privacy

Everything is computed on the phone and there is no server. Health is read only for the types the person allows, and Location and iPhone movement stay off until the person turns them on. Messages are drafted by the app and sent by the person; the only automatic send is the opt-in SMS demo shortcut above. The Automatic support switch saves the person's choice, but no automatic request is delivered in this prototype.

- What may be collected and why: [docs/DATA_SCOPE.md](docs/DATA_SCOPE.md) (includes the places where the code does not yet meet a rule)
- Exact Health types read: [docs/HEALTHKIT_DATA.md](docs/HEALTHKIT_DATA.md)

## Build and run

Requires Xcode with the iOS 17+ SDK.

**Simulator:** open `aaltodepression.xcodeproj`, choose the **aaltodepression** scheme and an iPhone simulator, and press ⌘R. The simulator has no Health data, so One thing offers general ideas; use Trends → Switch to demo data to see the scoring. Command line, no signing:

```sh
xcodebuild -project aaltodepression.xcodeproj -scheme aaltodepression -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO -quiet
```

**Device:** the app and widget take their bundle id and team from `Config/Signing.xcconfig`. To use your own, create `Config/LocalSigning.xcconfig` (ignored by Git):

```
BESIDE_HOST_BUNDLE_IDENTIFIER = your.unique.bundle
BESIDE_DEVELOPMENT_TEAM = YOURTEAMID
```

Both targets need HealthKit and the App Group `group.<your bundle id>`. Never commit the local override or signing changes in `project.pbxproj`. Use a real iPhone (and Apple Watch, if available) for Health data, Messages and the SMS demo.

**Checks** (no Xcode project needed, only `swiftc`):

- `Tools/engine-check.sh` compiles all of `Engine/` with the demo sources, without SwiftUI, and runs the step engine, planner, task and SMS demo checks.
- `Tools/everyday-check.sh` checks the profile store.

There is no XCTest target.

## Repository layout

| Path | Contents |
|---|---|
| `aaltodepression/Engine/` | Pure Swift, no SwiftUI or UIKit: baseline, scores, step engine, planner and task rules, message templates. `Engine/Contracts/` is the shared contract between backend and frontend. |
| `aaltodepression/Sources/` | HealthKit, Core Motion, Core Location, contacts, simulated and demo data. |
| `aaltodepression/Store/` | `Backend`, `Planner`, saved state, permissions, notifications, SMS demo sender. |
| `aaltodepression/Features/Everyday/` | All running SwiftUI views and `BesidePresentation`, the adapter between views and `Backend`. |
| `BesideWidget/`, `SharedSidequest/` | Widget target and the App Group file it shares with the app. |
| `aaltodepression/UI/`, `AppModel.swift` | Legacy "Usual" prototype, not shown by the running app (`UI/MessageCompose.swift` is still used). |
| `aaltodepression/DevTools/` | Backend test screens, reachable only from the legacy `UI/SettingsView`. |
| `Config/` | Info.plist, entitlements, signing xcconfig. |
| `Tools/` | Engine and profile store checks. |
| `docs/` | Design, data and API docs. |

Swift type names still use `Beside`, `Everyday` and `Usual` from earlier project names. Team rules for parallel work: [CLAUDE.md](CLAUDE.md).

## Docs

- [docs/APP_DESIGN.md](docs/APP_DESIGN.md): what the app does and how, in detail
- [docs/DATA_SCOPE.md](docs/DATA_SCOPE.md): data policy
- [docs/HEALTHKIT_DATA.md](docs/HEALTHKIT_DATA.md): Health types and where they are used
- [docs/BACKEND_API.md](docs/BACKEND_API.md): how the views call the backend
- [docs/demo-page-handoff.md](docs/demo-page-handoff.md): rebuilding One thing, Trends and For you as web components
- [docs/IOS_BUILD_BRIEF.md](docs/IOS_BUILD_BRIEF.md): the original build brief, with a status note on what changed
- [docs/HANDOFF.md](docs/HANDOFF.md): append-only team board

## Evidence it builds on

- About half of people who respond to TMS still meet response criteria at 6 to 12 months. Senova et al. 2019, *Brain Stimulation*.
- Restarting TMS when worsening was caught early brought most patients back. Janicak et al. 2010, *Brain Stimulation*.
- Sleep quality predicts next-day affect more than the reverse. Triantafillou et al. 2019, *JMIR Mental Health*.
- Sleep regularity predicts outcomes beyond sleep duration. Windred et al. 2024, *Sleep*; in recurrent depression, Matcham et al. 2024, *J Affect Disord*.
- More time at home than one's own average predicted higher depression scores two weeks later. Stamatis et al. 2024, *npj Mental Health Research*.
- Daylight exposure is linked to lower odds of depression. Burns et al. 2021, *J Affect Disord*.
- Variation within one person is larger than between people, so personal baselines beat population norms. Fisher et al. 2018, *PNAS*.

Using passive sensing to trigger early support and a TMS booster is the hypothesis this prototype is built to test, not an established fact.

# Demo page handoff: One thing, Trends and For you as web components

iOS limits the demo, so it will run as a web page in another repo. This file explains how to rebuild three tabs as web components: **One thing**, **Trends** and **For you**. It lists what each page shows, its states, the exact copy, the rules to port and the data you need.

The source of truth is the Swift code. Each section names the files to copy from. All visible text is English, the same as in the app.

---

## 0. Shared basics

### Design tokens (from `Features/Everyday/EverydayDesign.swift`)

The app is always in dark mode (`.preferredColorScheme(.dark)`).

| Token | Value | Use |
|---|---|---|
| paper | system background (black in dark mode, `#000000`) | page background |
| surface | iOS secondary grouped background (dark: about `#1C1C1E`) | cards, lists |
| accent | `rgb(194, 166, 247)` (0.76, 0.65, 0.97) | icons, links, tint, praise text |
| action | `rgb(112, 71, 179)` (0.44, 0.28, 0.70) | primary filled buttons |
| task card | `rgb(56, 43, 79)` (0.22, 0.17, 0.31) | One thing task tiles |
| lavender | `rgb(56, 41, 77)` | For you cards, support cards |
| mint | `rgb(48, 38, 69)` | toggle groups, selected person |
| card radius | 32 px, continuous (squircle) corners | every card |
| balance scale | 4 steps: `#8CCC80`, `#EDC74D`, `#E67340`, `#B32938` | Daily balance bar |

Balance colour for a 0–100 value: ≥ 80 green, ≥ 60 yellow, ≥ 40 orange, otherwise red (`BalanceScale.color(for:)`).

Logo: `aaltodepression/Assets.xcassets/MindLogo.imageset/MindLogo.png` (violet, 1024 px). The app name is **MindMaintainer**.

Typography: the iOS system font (SF Pro). On the web, use `-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif`. Page titles are bold and about 28 px, sitting at the left of the header row.

Layout target: iPhone 14 Pro, 393 × 852 pt. Pages are a phone-width column with 16–20 px side padding.

### What has to be simulated on the web

| In the app | On the web |
|---|---|
| Apple Health readings | Static JSON fixtures (see "Data" in Trends) |
| Planner state and persistence (`Store/Planner.swift`) | In-memory state; reset on reload |
| Contacts (`Contact`) | A fixed list of demo people |
| Opening Messages, `tel:` links, Apple Shortcuts SMS | Show the copied message text or a "Demo: would open Messages" toast. Never place real calls or send messages. |
| Notifications, widget, Location | Leave out |

### Porting the rules

Port the small rule files directly, since they are plain Swift with no UI:

- `Engine/Planner/SidequestDemoRules.swift`: the demo task pools and the choice rule for six score categories
- `Engine/Planner/SidequestRules.swift`: the live task catalog (`catalog`) and the live choice rule
- `Engine/Planner/MessageTemplates.swift`: the Reach out drafts
- `Engine/Contracts/Sidequest.swift`: the task model, `canInvite`, `invitation`, and done and extra-done logic
- `Engine/Contracts/Support.swift`: support topics and their titles

Do **not** port the scoring engine (`Engine/Scores.swift`, `Engine/StepEngine.swift`). Precompute its output instead (see "Data" in Trends). It needs a 90-day history and baselines, which a demo page does not.

---

## 1. One thing (tab title "Today's one thing")

Sources: `Features/Everyday/EverydayTodayView.swift`, `Features/Everyday/BesideSidequestView.swift`, `Features/Everyday/BesideTaskPreview.swift`.

### Data model

```ts
type Category = "sleep" | "movement" | "nutrition" | "social" | "medicine";
type ScoreKind = "sleep" | "rhythm" | "movement" | "daylight" | "places" | "body";

interface TaskVersion { title: string; instruction: string; minutes: number }
interface Task { id: string; category: Category; regular: TaskVersion; smaller: TaskVersion }

interface DayOffer {
  options: Task[];          // always 3, distinct
  reason: string;           // shown behind the (i) button
  startsSmall: boolean;     // show the "smaller" (easy) versions
  selectedID?: string;
  completedAt?: string;     // ISO date; the chosen task is done
  alsoDoneIDs?: string[];   // optional extra tasks done after the chosen one
}
```

Card text uses the **short brief**, not `regular.title`. Copy the `BesideQuestStyle.brief(_:smaller:)` table from `BesideSidequestView.swift`, including the icon per task (`BesideQuestStyle.visual`). The icons are SF Symbols, so map them to similar web icons such as Lucide or Material Symbols.

### States and copy

1. **Not chosen**
   - Header: "Pick the one that fits today", with a smaller line under it: "You can also do more if you feel like it."
   - An (i) button opens an alert titled "Why these challenges?" with `offer.reason`.
   - Three tall tiles (min 150 px, task card colour, radius 32): icon on top and the brief centred under it. Tapping a tile chooses it.
2. **Chosen, not done**
   - Header: "Your choice for today", plus a back arrow button (choose another).
   - All three tiles stay. The chosen one has a 2 px accent border and a check-circle icon at the top right. The others fade to 35 % opacity and can't be tapped.
   - Under the tiles: "A good choice. One small step is enough." in accent.
   - Primary button "Mark as done".
   - Text buttons: "Invite someone" (only when `canInvite`) and "Remind me". On the web, Remind me can show a demo toast.
3. **Done**
   - Header: "Done for today".
   - The chosen tile shows a filled check. The other tiles return to full opacity and can be tapped, which picks them as an extra and gives them the accent border.
   - Praise in accent headline:
     - 0 extras: "Well done! You did today's one thing."
     - 1 extra: "One more done. That's a lot to be proud of."
     - 2 extras: "All done. What a day. Remember to rest too."
   - If an extra is picked: "Mark as done" marks it done. Otherwise, while some are left: "Feeling like a bit more? Pick another one above. Only if it feels good."

### "Show more tasks (demo)"

- Plain accent text link under the tiles, with no background.
- Tapping it replaces the page with the demo layout, on the same black background:
  - **Top panel**, titled "Scores for this demo":
    - Six compact rows, each with a label (82 px), a 0–100 slider and the value. The rows are Sleep, Rhythm, Movement, Daylight, Getting out (= `places`) and Body.
    - "Task focus": the score categories the tasks came from, lowest first, e.g. "Getting out 38 · Body 62".
    - "Task difficulty": "Easy" or "Normal".
    - Caption: "The lowest scores choose the tasks. Below 50 they get easier. Demo only: your day is unchanged."
  - **Bottom:** three compact cards (min 58 px, radius 18), each with the icon, the score category in small grey text and the brief.
  - Link "Hide demo".
- On iPhone 14 Pro size, everything fits on one screen without scrolling.
- Starting values: today's scores. Use 70 for any that are missing.
- Rule (`SidequestDemoRules.preview`): sort the six scores ascending (ties keep the order sleep, rhythm, movement, daylight, places, body). Take two tasks from the lowest category. Take the third from the next category if its score is below 80; otherwise take it from the lowest too. Pick within a pool by `dayNumber % pool.length`, skipping tasks already chosen. Use easy versions when the lowest score is below 50.
- Leaving the tab resets the demo and nothing is saved. The demo never changes the real offer.

---

## 2. Trends

Sources: `Features/Everyday/BesideDemoView.swift` (page, `TrendArea`, `BesideTrendBalanceView`, `BesideBalanceTrend`), `Features/Everyday/BesidePresentation.swift` (`TrendScenario`, `balanceTitle`), `Features/Everyday/BesideSMSDemoView.swift`.

### Layout, top to bottom

1. **Header row:** the title "Trends" on the left, and on the right a previous-day arrow, a date label ("Today" or "15 Nov") and a next-day arrow. You can browse back up to 120 days but not past today.
2. **Demo controls:**
   - A full-width bordered button, "Switch to demo data". While demo data is on it reads "Show my data".
   - While demo data is on, a segmented picker with three options: **Steady**, **A few harder days** and **A harder stretch**.
   - With "A harder stretch" selected, a bordered button **"Send SMS demo"** appears.
3. **Daily balance card:**
   - Title "Daily balance", with the value at the right ("72" in large bold digits and "/100" small).
   - `balanceTitle`:
     - "Learning your usual" (no value yet)
     - "Your daily balance" (steady)
     - "A little support could help" (nudge)
     - "Time to reach out" (reach out)
   - The 4-step balance scale with a white dot (black 3 px outline). The dot sits at `1 − value/100` across the width.
   - Under it, small grey "Your usual" on the left and "More support" on the right.
   - **Last 4 weeks:** a bar per day, coloured by the balance scale at 55 % opacity, with a primary-colour 7-day average line. The Y axis is 0/50/100, X labels fall every 7 days, and it is 120 px tall. Header: "Last 4 weeks", with "7-day average NN" at the right.
   - Caption: "Every day this week was near your usual." or "N of the last 7 days were further from your usual."
   - With demo data on, an accent label: "Demo data · <scenario> · your data is unchanged".
4. **"Your signals":** one list card with eight expandable rows, in this order:
   - Sleep, Daily rhythm, Getting out, Movement, Daylight, Body, How you feel, Food
   - Each row: icon, title, a summary ("Close to your usual" if the score is ≥ 70, otherwise "Different from your usual") and the score at the right.
   - How you feel and Food have no score.
   - Expanded: the metric rows, plus for Daily rhythm the "Bedtime regularity" and "Wake-up regularity" rows, plus the note text. Copy the `TrendArea` titles, icons, metrics and notes from `BesideDemoView.swift`.
5. A small caption with how many readings were shared for the day (`selectedDayAvailability`).

These parts of the app are **not** in the web version: the advanced demo menu (triple tap on the title) and Health readings.

### Data

Precompute fixtures with the Swift engine, so the web page never reimplements scoring. For each scenario (`steady`, `someHarderDays`, `harderStretch`) export one JSON:

```ts
interface TrendsFixture {
  scenario: "steady" | "someHarderDays" | "harderStretch";
  days: Array<{
    date: string;                       // ISO day
    steadiness: number | null;          // Daily balance 0–100
    step: "steady" | "nudge" | "reachOut";
    scores: Partial<Record<ScoreKind, number>>;
    readings: Record<string, number>;   // BesideHealthMetric keys -> value for that day
    driftDaysInLastWeek: number;
  }>;                                   // the last 120 days, ending today
}
```

How the app builds the demo data (`BesidePresentation.displayedTable`): it takes the steady part of `SimulatedSource` (`SimulatedSource.table(endingOn: day + 15).truncated(through: day)`). On top of that it applies `DemoScenarioRules.table(ending:load:source:)` with load 0, 0.5 or 1. It then runs `StepEngine.run(...)` and reads `healthHistory`.

Suggested exporter: a small command-line target next to `Tools/EngineCheck` (it already compiles `Engine/` and `Sources/DemoSource.swift` without SwiftUI). It calls those functions and prints the JSON. Use one fixture for "my data" as well, e.g. the steady one with real-looking variation, since a web page cannot read Apple Health.

### Send SMS demo

- In the app this runs the user's Apple Shortcut, "Mind Demo SMS".
- On the web, open a sheet titled "Send SMS demo" with:
  - "To: Konsta"
  - A toggle, "Send a demo text automatically"
  - The status "Support signal detected"
  - When the toggle is on, show the fixed message: "Mind DEMO TEST: automatic support signal reached. No action needed."
  - A footer saying a real send needs the iPhone app
- Never send anything from the web.

---

## 3. For you

Sources: `Features/Everyday/BesideForYouView.swift`, `Features/Everyday/EverydaySocialView.swift` (Reach out), `EverydayHelpView` in `Features/Everyday/EverydayProfileView.swift` (Get support), `Engine/Planner/MessageTemplates.swift`.

### Page

- The title "For you".
- Two large cards (min 128 px, task card colour, radius 32): icon on the left, title and detail text, chevron on the right.
  - **Reach out:** "A little company, in your own words.", icon "two speech bubbles"
  - **Get support:** "Call someone you know, or find urgent help.", icon "two people"

### Reach out sheet

- Title: "Who would you like to hear from?"
- **"Your people":** up to three people as selectable rows (checkmark circle; the selected one uses the mint background), plus a "More people" menu if there are more. With no people: "Choose someone you know. You can message them in your usual way." and an "Add someone" button.
- An expandable **"Help me write it"** box:
  - A text editor with the draft.
  - "Use suggested words" fills it with `MessageTemplates.reachOut(nil, contact)`: "Hi <first name>! I thought of you. How are you doing?". Asking about a topic uses the topic lines in the same function.
  - Greetings use the first name only.
- Primary button "Message <name>". It is disabled while the draft is empty.
  - The app copies the draft and opens Messages. On the web, copy the text to the clipboard and show "Copied. In the app this opens <name>'s conversation."
- Caption: "Your message is copied when you tap Message. In Messages, just paste it into the conversation and send."

### Get support sheet

- Title "Get support", with a "Done" button.
- **"Your people":** a big card per person with the name, role ("Loved one" or "Friend") and a phone icon. Loved ones come first, on the mint background; friends use lavender. In the app, tapping a card calls the person (iOS shows its own confirmation). On the web it must be a non-calling demo action.
- **"Emergency":** the subtitle "Demo · these numbers can't be called from here.", then two rows that can't be tapped:
  - "MIELI Crisis Helpline", "09 2525 0111", "Confidential phone support, 24/7"
  - "Emergency number", "112", "Immediate danger to life or health"
- Keep these numbers as plain text on the web too. Do not turn them into `tel:` links.

---

## 4. Checklist for the web repo

- [ ] Dark theme with the tokens above, the system font and 32 px squircle cards.
- [ ] One thing: three states, Mark as done, praise copy, extras, and the "Show more tasks (demo)" panel with the six-category rule.
- [ ] Trends: demo data toggle, three scenarios, the balance card, the 4-week chart, eight signal rows, and Send SMS demo with A harder stretch.
- [ ] For you: Reach out (people, draft, copy) and Get support (people, non-tappable emergency numbers).
- [ ] Fixtures exported from the Swift engine rather than re-implemented scoring.
- [ ] Nothing calls, messages or reads real data; every action that would leave the page is a demo toast.

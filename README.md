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

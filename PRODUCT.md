# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

SwiftUI, Swift 6 concurrency, SwiftData as the local feature store, HealthKit, Core Motion, Core Location. Minimum iOS 17.0; newer HealthKit types guarded with `#available`. iPhone app; Apple Watch contributes data through Apple Health (no watch app in scope). Source brief: `docs/IOS_BUILD_BRIEF.md`.

## Users

People who have just finished TMS (transcranial magnetic stimulation) treatment for depression and are in their first year of aftercare. A clinic nurse has already explained the service to them in person. They use the app on their own iPhone, usually with an Apple Watch, and are not expected to type or log anything on a normal day.

Secondary audience for the hackathon: Junction 2026 judges (Aalto "Beyond the Clinic" challenge) watching a 90-second demo.

## Product Purpose

The patient side of a TMS aftercare service. Relapse is common in the first year, and an early booster TMS course often works if worsening is caught early. The app reads what it can from Apple Health and the phone, compares each signal with the person's own usual, and shows a few simple daily scores. A hidden step engine notices sustained drift and either suggests one action from the nurse's plan (step 1) or brings people in: a pre-written message to a friend and a nurse call (step 2).

Success: the person glances at the app daily without being asked for input, low days lead to one achievable action, and sustained drift reaches the friend and nurse early enough for a booster course.

## Positioning

Every signal is compared only with the person's own history (median and MAD over the previous 28 days), never with population norms. The rules are transparent; there is no machine learning. The plan comes from the person's own nurse, and escalation goes to people they chose in advance.

## Operating Context

- The nurse writes the plan in a separate clinic web app; the patient app receives it (demo: `plan_perttu.json` stands in for a QR pairing).
- Health permission and the plan arrive in one short, calm flow.
- Demo mode uses a synthetic patient, Perttu: 60 days, steady until day 44, a cold on days 30–32, a trip on days 38–40, drift from day 45. A demo-day stepper (28–59) in Settings drives the stage demo.
- Real mode reads the team's own iPhones and Watches, backfilled 365 days.

## Capabilities and Constraints

- Daily scores 0–100, where 100 = your usual or better: Sleep, Rhythm, Movement, Daylight, Places, Body; weighted day score with renormalisation. Missing data never counts as zero.
- Context flags `likelyIll` and `travelling` suppress escalation and are never shown as health claims.
- Step engine is hidden: step 1 = one action from the plan + at most one local notification per day; step 2 = friend message goes out tomorrow at 12:00 unless cancelled, nurse calls this week; step 3 is nurse-only.
- Data screen lists every signal, its source, last value and days of history, honest about what is unavailable.
- HealthKit read permission is opaque: empty results are unknown, never zero.
- Locations never leave the phone; only derived numbers are stored, never coordinates.
- Out of scope: login, backend sync, real QR pairing, Android, ML.
- Product name: Usual (chosen for the hackathon; no existing App Store health app found under that name).

## Brand Commitments

- Never show the step number. Never use the words risk, relapse or mood.
- No mood words, no diagnosis, no red, no streaks, no badges.
- Copy: sentence case, plain verbs, buttons say what happens ("Message Ville"), no filler.
- Low days must not feel like failure: one achievable next step instead of a verdict.

## Evidence on Hand

- `docs/IOS_BUILD_BRIEF.md`: full build brief, data inventory, scoring and step rules.
- `plan_perttu.json` (demo plan): patient Perttu, nurse Laura, friend Ville, four plan actions.
- No real patient data, testimonials, clinical outcomes or partner claims exist; do not fabricate any. The crisis number in the demo is a placeholder and must be marked as one.

## Product Principles

1. Compare only with yourself.
2. Ask nothing on a normal day.
3. A low day gets one achievable next step, never a verdict.
4. Transparent rules over opaque predictions.
5. Honest about data: unknown is not zero, and the phone keeps what it reads.

## Accessibility & Inclusion

Dynamic Type, VoiceOver labels on every score, 44 pt touch targets, colours that also differ in lightness, Reduce Motion respected. Crisis help reachable from the home screen in one tap.

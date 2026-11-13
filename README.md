# Usual

TMS aftercare iPhone app for Junction 2026 (Aalto, "Beyond the Clinic"). It reads Apple Health, Core Motion and location visits, compares each day with the person's own usual (median and MAD of the previous 28 days), and shows six daily scores as stripes. A hidden step engine suggests one action from the nurse's plan when days drift, and after a longer drift tells the person a pre-written message goes to a friend and the nurse will call.

- Brief: [docs/IOS_BUILD_BRIEF.md](docs/IOS_BUILD_BRIEF.md), product context: [PRODUCT.md](PRODUCT.md)
- Engine (pure Swift): `aaltodepression/Engine`. Check it without Xcode: `Tools/engine-check.sh` prints the 60-day demo table and verifies no escalation on the cold and the trip, step 1 on day 49, step 2 on day 59.
- Demo: Settings → Demo mode, demo day 28–59 (Perttu, synthetic).
- Real mode: run on your own iPhone with free personal provisioning (set your own team in Signing). Minimum iOS 17.

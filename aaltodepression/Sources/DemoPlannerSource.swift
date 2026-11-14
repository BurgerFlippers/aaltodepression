import Foundation

/// Demo user's planner days, matching the 60 days of synthetic signals in DemoSource:
/// steady with a good stretch on days 20–24 (coffee with Ville), a cold on 30–32, a trip on 38–40,
/// heavier days from 45, the shop skipped on day 50 (Sanna helps), "anxious" on day 52.
nonisolated enum DemoPlannerSource {
    static let setup = PlannerSetup(
        personName: "Demo user",
        wakeTime: 7 * 60, bedtime: 22 * 60 + 30, checkInTime: 7 * 60 + 30,
        shoppingWeekdays: [2, 4, 6],
        contacts: [
            Contact(id: "sanna", name: "Sanna", phone: "+358 40 000 0001", relation: .sibling,
                    canHelpWith: [.inviteToEat, .groceryRun, .shopTogether, .call]),
            Contact(id: "ville", name: "Ville", phone: "+358 40 000 0002", relation: .friend,
                    canHelpWith: [.call, .doSomethingFun, .shopTogether]),
            Contact(id: "mum", name: "Mum", phone: "+358 40 000 0003", relation: .parent,
                    canHelpWith: [.inviteToEat, .call]),
        ],
        medications: [Medication(id: "m1", name: "Morning tablet", times: [8 * 60])],
        chores: [Chore(id: "laundry", title: "Laundry", everyDays: 7),
                 Chore(id: "bills", title: "Pay bills", everyDays: 14),
                 Chore(id: "rubbish", title: "Take out the rubbish", everyDays: 3)],
        helpConsent: .sendRightAway,
        clinicName: "the TMS clinic", clinicPhone: "09 000 0000",
        goodThings: ["Coffee on the balcony", "Sauna", "Calling Ville"])

    /// Check-in for demo day `n`, or nil on the rare day the demo user skipped it.
    static func checkIn(_ n: Int) -> CheckIn? {
        let day = DemoSource.day(n)
        let at = day.start().addingTimeInterval(7 * 3600 + 35 * 60)
        func c(_ mood: Int, _ e: Energy, _ f: Set<Feeling>, food: FoodAtHome = .enough) -> CheckIn {
            CheckIn(day: day, at: at, mood: mood, energy: e, feelings: f, foodAtHome: food)
        }
        switch n {
        case 20...24: return c(5, .plenty, [.good])
        case 30...32: return c(3, .low, [.tired])
        case 45...47: return c(3, .some, [.tired])
        case 48, 49: return c(2, .low, [.tired, .low])
        case 50: return c(2, .low, [.low], food: .runningLow)
        case 51: return c(3, .some, [.tired], food: .runningLow)
        case 52: return c(2, .low, [.anxious])
        case 53...56: return c(n % 2 == 0 ? 2 : 3, .low, [.low])
        case 57...: return c(2, .low, [.tired, .low])
        default:
            if n % 11 == 5 { return nil }
            return c(n % 3 == 0 ? 3 : 4, n % 4 == 0 ? .plenty : .some, n % 3 == 0 ? [.calm] : [.good])
        }
    }

    /// "Did you get to the shop?" answers: yes on shopping days, except day 50.
    static func groceriesDone(_ n: Int) -> Bool? {
        guard setup.shoppingWeekdays.contains(DemoSource.day(n).isoWeekday) else { return nil }
        return n != 50
    }

    /// Planner state with every day before demo day `n` filled in. With `includeToday`, day `n`'s
    /// check-in is included too; without it the demo opens on the check-in.
    static func state(through n: Int, includeToday: Bool = false) -> PlannerState {
        var s = PlannerState(setup: setup)
        let last = includeToday ? n : n - 1
        guard last >= 0 else { return s }
        for i in 0...last {
            let day = DemoSource.day(i)
            if let c = checkIn(i) { s.record(c) }
            if let g = groceriesDone(i) { s.answerGroceries(g, day: day) }
            // Bonus, screen time about the day before: about 2–3 h before the drift, then more, and in bed.
            if i >= 1, i % 9 != 4 {
                let drift = i >= 46
                let hours = drift ? [4.5, 5.5, 6.0, 5.0][i % 4] : [2.0, 2.5, 3.0, 1.5][i % 4]
                s.recordScreenTime(ScreenTimeReport(hours: hours, phoneInBed: drift ? i % 3 != 0 : i % 7 == 0, exact: i % 2 == 0),
                                   day: DemoSource.day(i - 1))
            }
            guard i < n else { continue }
            let at = day.start().addingTimeInterval(20 * 3600)
            // Wind-down on most steady evenings, rarely once the days got heavier.
            if i < 45 ? i % 4 != 3 : i % 5 == 0 {
                s.marks[TodayBuilder.itemID(day, .sleep, "winddown")] = ItemMark(status: .done, at: at)
            }
            // Chores roughly on time before the drift.
            if i < 45 {
                for chore in setup.chores where i % chore.everyDays == 0 { s.choreDone[chore.id] = day.jdn }
            }
        }
        // Day 22: the good stretch led to coffee with Ville on day 23.
        if n > 22 {
            s.socialOfferedDays.insert(DemoSource.day(22).jdn)
            s.socialPlans.append(SocialPlan(id: "demo-coffee", day: DemoSource.day(23), contactName: "Ville",
                                            activity: "have a coffee", met: n > 23 ? true : nil))
        }
        // Day 50: the shop didn't happen; Sanna brought groceries and stayed to eat.
        if n > 50 {
            let d = DemoSource.day(50)
            s.outbox.append(OutgoingMessage(id: "demo-help-50", day: d, createdAt: d.start().addingTimeInterval(17 * 3600 + 5 * 60),
                                            contactID: "sanna", contactName: "Sanna", kind: .groceryRun,
                                            text: MessageTemplates.help(.groceryRun, contact: setup.contacts[0], person: "Demo user",
                                                                        groceries: GroceryPlanner.list(for: .low)),
                                            status: .replied, simulatedReply: MessageTemplates.simulatedReply(.groceryRun)))
        }
        // Day 48: feeling low on top of short nights opened the safety questions (all "no").
        if n > 48 { s.safetyAskedDays.insert(DemoSource.day(48).jdn) }
        // Day 48: the clinic card came up too; the demo user tapped "Not now", so it rests for a week.
        if n > 48 { s.dismissedCards["clinic"] = DemoSource.day(48).jdn }
        // Day 52: "anxious" opened the safety questions.
        if n > 52 { s.safetyAskedDays.insert(DemoSource.day(52).jdn) }
        return s
    }
}

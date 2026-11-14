import Foundation

/// Inputs for one day. Kept in one place so the engine stays a pure function.
nonisolated struct PlannerContext: Sendable {
    let day: Day
    /// Minutes after midnight, "now".
    let now: Int
    let state: PlannerState
    /// Signals, including today's partial values (steps so far, medication logged in Health).
    let table: FeatureTable
    /// Step engine result per day. Today's capacity uses yesterday's entry, the last complete day.
    let steps: [Day: StepDay]

    init(day: Day, now: Int, state: PlannerState, table: FeatureTable, history: [StepDay]) {
        self.day = day; self.now = now; self.state = state; self.table = table
        var s: [Day: StepDay] = [:]
        for d in history { s[d.day] = d }
        self.steps = s
    }

    var checkIn: CheckIn? { state.checkIn(on: day) }
    var yesterday: StepDay? { steps[day - 1] }
    /// After safety answers that point to talking with someone, the day stays light.
    var heavyDay: Bool { state.heavySafetyDays.contains(day.jdn) }
    var capacity: Capacity { heavyDay ? .low : CapacityEstimator.estimate(checkIn: checkIn, stepDay: yesterday) }
    var isShoppingDay: Bool { state.setup.shoppingWeekdays.contains(day.isoWeekday) }
    /// Nil until the person answers "Did you get to the shop today?".
    var groceriesDone: Bool? { state.groceryAnswers[day.jdn] }
}

/// Builds today's list: the four basics sized to the day, plus must-dos and plans when there is room.
nonisolated enum TodayBuilder {
    static func build(_ ctx: PlannerContext) -> TodayPlan {
        let capacity = ctx.capacity
        let items = self.items(ctx, capacity: capacity)
        let cards = InterventionRules.cards(ctx, capacity: capacity, items: items)
        let reward = Rewards.day(ctx.day, items: items, state: ctx.state)
        return TodayPlan(day: ctx.day, capacity: capacity, headline: headline(capacity, checkedIn: ctx.checkIn != nil),
                         items: items, cards: cards, needsCheckIn: ctx.checkIn == nil,
                         asksAboutGroceries: ctx.isShoppingDay && ctx.groceriesDone == nil,
                         asksAboutScreenTime: ctx.state.setup.asksScreenTime && ctx.state.screenTime[(ctx.day - 1).jdn] == nil,
                         asksAboutSocial: ctx.state.socialPlans.filter { $0.met == nil && $0.day < ctx.day && ctx.day - $0.day <= 3 }
                            .max { $0.day < $1.day },
                         upcomingPlans: ctx.state.socialPlans.filter { $0.day >= ctx.day }.sorted { $0.day < $1.day },
                         reward: reward, insights: Insights.compute(state: ctx.state, table: ctx.table, through: ctx.day), reachOutPrompt: ReachOutRules.prompt(ctx))
    }

    /// Only the day's reward: the list without cards or insights (cheap, used for past rug rows).
    static func reward(_ ctx: PlannerContext) -> DayReward {
        Rewards.day(ctx.day, items: items(ctx, capacity: ctx.capacity), state: ctx.state)
    }

    static func items(_ ctx: PlannerContext, capacity: Capacity) -> [PlanItem] {
        var items: [PlanItem] = []
        items += medicationItems(ctx)
        items.append(movementItem(ctx, capacity: capacity))
        items.append(foodItem(ctx, capacity: capacity))
        items.append(sleepItem(ctx, capacity: capacity))
        items += socialItems(ctx)
        items += choreItems(ctx, capacity: capacity)
        return items.map { apply(ctx.state.marks[$0.id], to: $0) }
    }

    static func headline(_ c: Capacity, checkedIn: Bool) -> String {
        guard checkedIn else { return "Good morning. How is today feeling?" }
        switch c {
        case .low: return "Today, a little is enough. Whatever gets done counts; nothing else costs anything."
        case .ok: return "An ordinary day. A few small things."
        case .good: return "There's some energy today. Maybe plan something nice?"
        }
    }

    static func itemID(_ day: Day, _ pillar: Pillar, _ slug: String) -> String { "\(day.jdn)|\(pillar.rawValue)|\(slug)" }

    /// The person's own tap wins over sensors. A mark that only changed the size leaves the status alone
    /// (sizes are applied by each builder), so sensors can still confirm a smaller item.
    static func apply(_ mark: ItemMark?, to item: PlanItem) -> PlanItem {
        var i = item
        guard let status = mark?.status else { return i }
        i.status = status
        i.doneBy = status == .done ? .person : nil
        if status != .done { i.evidence = nil }
        return i
    }

    static func isDone(_ ctx: PlannerContext, _ id: String) -> Bool { ctx.state.marks[id]?.status == .done }

    // MARK: - Medication

    static func medicationItems(_ ctx: PlannerContext) -> [PlanItem] {
        let meds = ctx.state.setup.medications
        guard !meds.isEmpty else { return [] }
        var slots: [(Medication, Int)] = meds.flatMap { m in m.times.map { (m, $0) } }
        slots.sort { $0.1 < $1.1 }
        // Health's dose log (iOS 26) confirms as many doses as it has, earliest first.
        let loggedInHealth = Int(ctx.table.value(F.medsLogged, ctx.day) ?? 0)
        return slots.enumerated().map { i, slot in
            var item = PlanItem(id: itemID(ctx.day, .meds, "\(slot.0.id)|\(slot.1)"), pillar: .meds,
                                title: slot.0.name, detail: "Take as prescribed", size: .tiny, time: slot.1)
            if i < loggedInHealth {
                item.status = .done; item.doneBy = .health; item.evidence = "Logged in Health"
            }
            return item
        }
    }

    // MARK: - Movement

    /// Minutes of movement the data can vouch for today, with the words that explain it.
    static func movementSeen(_ table: FeatureTable, _ day: Day) -> (minutes: Double, evidence: String?) {
        var best: (Double, String?) = (0, nil)
        func consider(_ m: Double?, _ text: (Double) -> String) {
            guard let m, m > best.0 else { return }
            best = (m, text(m))
        }
        consider(table.value(F.exerciseMin, day)) { "Apple Watch counted \(Int($0)) exercise minutes" }
        consider(table.value(F.workoutMin, day)) { "A \(Int($0))-minute workout is in Health" }
        consider(table.value(F.walkingHours, day).map { $0 * 60 }) { "Your phone saw about \(Int($0)) minutes on foot" }
        // An hour with 800+ steps is roughly ten minutes of walking.
        let burstHours = (0..<24).filter { (table.value(F.stepsHour($0), day) ?? 0) >= 800 }.count
        consider(burstHours > 0 ? Double(burstHours * 10) : nil) { "Your phone saw walking, about \(Int($0)) minutes" }
        return best
    }

    static let movementMinutes: [ItemSize: Double] = [.tiny: 10, .small: 20, .normal: 30]

    static func movementSize(_ ctx: PlannerContext, capacity: Capacity) -> ItemSize {
        var size: ItemSize = capacity == .low ? .tiny : capacity == .ok ? .small : .normal
        // Learned: if this size has been skipped or shrunk three times in two weeks, start smaller.
        let recent = Day.range(ctx.day - 14, ctx.day)
        let misses = recent.filter { d in
            guard let m = ctx.state.marks[itemID(d, .movement, "move")] else { return false }
            return m.status == .skipped || (m.size.map { $0 < size } ?? false)
        }.count
        if misses >= 3, let smaller = size.smaller { size = smaller }
        return size
    }

    static func movementItem(_ ctx: PlannerContext, capacity: Capacity) -> PlanItem {
        let id = itemID(ctx.day, .movement, "move")
        var item = PlanItem(id: id, pillar: .movement, title: "",
                            size: ctx.state.marks[id]?.size ?? movementSize(ctx, capacity: capacity), canShrink: true)
        if let sunset = ctx.table.value(F.sunset, ctx.day) {
            let left = sunset * 60 - Double(ctx.now)
            if left > 0 { item.detail = "Daylight for \(PlanFormat.duration(minutes: left))" }
        }
        return resized(item, seen: movementSeen(ctx.table, ctx.day))
    }

    /// Titles follow the size; sensors confirm when they saw enough.
    static func resized(_ item: PlanItem, seen: (minutes: Double, evidence: String?)? = nil) -> PlanItem {
        var i = item
        switch i.pillar {
        case .movement:
            switch i.size {
            case .tiny: i.title = "A breath of fresh air, 10 minutes outside"
            case .small: i.title = "A 20-minute walk"
            case .normal: i.title = "30 minutes of movement you like"
            }
            i.canShrink = i.size > .tiny
            if let seen, seen.minutes >= (movementMinutes[i.size] ?? 10), i.status == .open {
                i.status = .done; i.doneBy = .sensors; i.evidence = seen.evidence
            }
        case .sleep:
            i.title = i.size == .tiny ? "One wind-down step before bed" : "Evening wind-down"
        default: break
        }
        return i
    }

    // MARK: - Food

    static func foodItem(_ ctx: PlannerContext, capacity: Capacity) -> PlanItem {
        let food = ctx.checkIn?.foodAtHome
        let needsShop = food == .empty || food == .runningLow
        let shopID = itemID(ctx.day, .food, "shop"), mealID = itemID(ctx.day, .food, "meal")
        // Whatever was ticked today stays on the list, even if a later check-in changes the plan.
        let shop = (ctx.isShoppingDay || needsShop || isDone(ctx, shopID) || ctx.groceriesDone == true) && !isDone(ctx, mealID)
        if shop {
            let list = GroceryPlanner.list(for: capacity)
            var item = PlanItem(id: itemID(ctx.day, .food, "shop"), pillar: .food,
                                title: capacity == .low ? "A quick grocery run, easy foods" : "Grocery run",
                                detail: "List ready (\(list.count) items)", size: capacity == .low ? .tiny : .small,
                                groceries: list)
            if ctx.groceriesDone == true { item.status = .done; item.doneBy = .person }
            return item
        }
        return PlanItem(id: itemID(ctx.day, .food, "meal"), pillar: .food,
                        title: capacity == .low ? "One easy plate" : "One proper meal",
                        detail: GroceryPlanner.plate(for: capacity, day: ctx.day), size: capacity == .low ? .tiny : .small)
    }

    // MARK: - Sleep

    static func sleepItem(_ ctx: PlannerContext, capacity: Capacity) -> PlanItem {
        let id = itemID(ctx.day, .sleep, "winddown")
        let size = ctx.state.marks[id]?.size ?? (capacity == .low ? .tiny : .small)
        var item = PlanItem(id: id, pillar: .sleep, title: "",
                            detail: "Screens away, lights low, park tomorrow's worries, same wake-up time",
                            size: size, time: ctx.state.setup.windDownTime, canShrink: size > .tiny)
        if size == .tiny { item.detail = "Dim the lights or write down one worry for tomorrow" }
        // Bonus, screen time: the phone in bed on 3 of the last 7 nights makes it the one step to try.
        let inBed = Day.range(ctx.day - 7, ctx.day).filter { (ctx.table.value(F.phoneInBed, $0) ?? 0) >= 1 }.count
        if inBed >= 3 { item.detail = "Tonight, try leaving the phone outside the bedroom" }
        return resized(item)
    }

    // MARK: - People and must-dos

    static func socialItems(_ ctx: PlannerContext) -> [PlanItem] {
        ctx.state.socialPlans.filter { $0.day == ctx.day }.map { p in
            var item = PlanItem(id: itemID(ctx.day, .social, p.id), pillar: .social,
                                title: p.contactName.map { "\(p.activity.capitalizedFirst) with \($0)" } ?? p.activity.capitalizedFirst,
                                size: .small)
            if p.met == true { item.status = .done; item.doneBy = .person }
            return item
        }
    }

    /// Last day a chore was done before `day`, from the marks and the stored last-done day.
    static func lastDone(_ ctx: PlannerContext, _ chore: Chore) -> Int? {
        let fromMarks = ctx.state.marks.compactMap { k, v -> Int? in
            let p = k.split(separator: "|").map(String.init)
            guard p.count >= 3, p[1] == Pillar.chores.rawValue, p[2] == chore.id, v.status == .done, let d = Int(p[0]), d < ctx.day.jdn else { return nil }
            return d
        }.max()
        let stored = ctx.state.choreDone[chore.id].flatMap { $0 < ctx.day.jdn ? $0 : nil }
        return [fromMarks, stored].compactMap { $0 }.max()
    }

    /// Due chores. None on a low day, one on an ordinary day, two on a good day. A chore ticked today
    /// always stays on the list, whatever the room.
    static func choreItems(_ ctx: PlannerContext, capacity: Capacity) -> [PlanItem] {
        let room = capacity == .low ? 0 : capacity == .ok ? 1 : 2
        let doneToday = ctx.state.setup.chores.filter { isDone(ctx, itemID(ctx.day, .chores, $0.id)) || ctx.state.choreDone[$0.id] == ctx.day.jdn }
        let due = ctx.state.setup.chores.filter { c in !doneToday.contains(c) }.compactMap { c -> (Chore, Int)? in
            let since = lastDone(ctx, c).map { ctx.day.jdn - $0 } ?? c.everyDays
            return since >= c.everyDays ? (c, since - c.everyDays) : nil
        }
        let open = due.sorted { $0.1 > $1.1 }.prefix(max(0, room - doneToday.count)).map(\.0)
        return (doneToday + open).map { c in
            var item = PlanItem(id: itemID(ctx.day, .chores, c.id), pillar: .chores, title: c.title, size: .small)
            if doneToday.contains(c) { item.status = .done; item.doneBy = .person }
            return item
        }
    }
}

/// Formatting used inside engine texts. (The screens have their own `Format`.)
nonisolated enum PlanFormat {
    static func duration(minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}

extension String {
    nonisolated var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

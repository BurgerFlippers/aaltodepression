import Foundation

/// Every question the app asks, in one place, and how answers become planner state.
nonisolated enum QuestionCatalog {
    static let moodLabels = ["😞", "🙁", "😐", "🙂", "😄"]

    static let mood = Question(id: "mood", prompt: "How is today feeling?", kind: .likert(1...5, labels: moodLabels))
    static let energy = Question(id: "energy", prompt: "How much do you have in you today?", kind: .scale(Energy.allCases.map(\.title)))
    static let feelings = Question(id: "feelings", prompt: "Any of these?", kind: .multiSelect(Feeling.allCases.map(\.title)), optional: true)
    static let food = Question(id: "foodAtHome", prompt: "Is there food at home for the next couple of days?",
                               kind: .singleChoice(FoodAtHome.allCases.map(\.title)), optional: true)
    static let groceries = Question(id: "groceries", prompt: "Did you get to the shop today?", kind: .yesNo)
    static let metSomeone = Question(id: "socialMet", prompt: "Did you get to meet?", kind: .yesNo)

    // Bonus: screen time. Apple lets apps read Screen Time only with a special entitlement, so the person
    // tells us, roughly or exactly from Settings → Screen Time. Optional and easy to switch off.
    static let screenTimeRanges: [(label: String, hours: Double)] = [
        ("Under 1 h", 0.5), ("1–2 h", 1.5), ("2–4 h", 3), ("4–6 h", 5), ("Over 6 h", 7),
    ]
    static let screenTime = Question(id: "screenTime", prompt: "Roughly how long were you on your phone yesterday?",
                                     kind: .singleChoice(screenTimeRanges.map(\.label)), optional: true)
    static let screenTimeExact = Question(id: "screenTimeExact", prompt: "Or the exact time from Settings → Screen Time",
                                          kind: .numeric(0...960, step: 15, unit: "min"), optional: true,
                                          hint: "Settings → Screen Time → See All App & Website Activity → yesterday")
    static let phoneInBed = Question(id: "phoneInBed", prompt: "Did you use the phone in bed after lights out?", kind: .yesNo, optional: true)
    static let screenTimeQuestions: [Question] = [screenTime, screenTimeExact, phoneInBed]

    /// A screen-time report from answers; the exact minutes win over the range. Nil when nothing usable was given.
    static func screenTimeReport(from answers: [String: Answer]) -> ScreenTimeReport? {
        var hours: Double?
        var exact = false
        if case .number(let m)? = answers[screenTimeExact.id], m >= 0 { hours = Double(m) / 60; exact = true }
        else if case .option(let i)? = answers[screenTime.id], screenTimeRanges.indices.contains(i) { hours = screenTimeRanges[i].hours }
        var inBed: Bool?
        if case .yes(let b)? = answers[phoneInBed.id] { inBed = b }
        guard hours != nil || inBed != nil else { return nil }
        return ScreenTimeReport(hours: hours ?? -1, phoneInBed: inBed, exact: exact)
    }

    /// The morning check-in: about 15 seconds of taps.
    static let checkIn: [Question] = [mood, energy, feelings, food]

    /// A safety question in the same shape. Answers go to `Planner.safetyAnswer`, never to the log.
    static func safety(_ q: SafetyQuestion) -> Question {
        Question(id: "safety.\(q.rawValue)", prompt: SafetyCopy.text(q), kind: .yesNo, hint: SafetyCopy.timeframe)
    }

    /// Builds a check-in from answers keyed by question id. Nil when mood or energy is missing.
    static func checkIn(from answers: [String: Answer], day: Day, at: Date) -> CheckIn? {
        guard case .number(let m)? = answers[mood.id], (1...5).contains(m),
              case .option(let e)? = answers[energy.id], Energy.allCases.indices.contains(e) else { return nil }
        var feels: Set<Feeling> = []
        if case .options(let set)? = answers[feelings.id] {
            feels = Set(set.compactMap { Feeling.allCases.indices.contains($0) ? Feeling.allCases[$0] : nil })
        }
        var foodAtHome: FoodAtHome?
        if case .option(let f)? = answers[food.id], FoodAtHome.allCases.indices.contains(f) { foodAtHome = FoodAtHome.allCases[f] }
        return CheckIn(day: day, at: at, mood: m, energy: Energy.allCases[e], feelings: feels, foodAtHome: foodAtHome)
    }

    /// The same check-in as answers, e.g. to prefill a redo.
    static func answers(for c: CheckIn) -> [String: Answer] {
        var out: [String: Answer] = [mood.id: .number(c.mood),
                                     energy.id: .option(Energy.allCases.firstIndex(of: c.energy) ?? 1)]
        // Feelings is optional: no words picked means the question was skipped, not an empty answer.
        if !c.feelings.isEmpty { out[feelings.id] = .options(Set(c.feelings.compactMap { Feeling.allCases.firstIndex(of: $0) })) }
        if let f = c.foodAtHome, let i = FoodAtHome.allCases.firstIndex(of: f) { out[food.id] = .option(i) }
        return out
    }
}

extension PlannerState {
    /// Keeps the answers in the log (newest last, at most 500).
    nonisolated mutating func log(_ answers: [String: Answer], day: Day, at: Date) {
        for (id, a) in answers.sorted(by: { $0.key < $1.key }) where !id.hasPrefix("safety.") {
            answerLog.append(AnswerRecord(questionID: id, answer: a, day: day, at: at))
        }
        if answerLog.count > 500 { answerLog.removeFirst(answerLog.count - 500) }
    }
}

import Foundation

/// "Show more tasks (demo)" only. Every score category has its own small task pool, so a tester can
/// see each area drive the choice. The live day keeps `SidequestRules` and its catalog unchanged.
nonisolated struct SidequestPreview: Sendable {
    /// Score categories the options were drawn from, lowest first, with their scores.
    var focus: [ScoreKind]
    var focusScores: [ScoreKind: Double]
    var options: [Sidequest]
    /// Score category each option came from, by option id.
    var kinds: [String: ScoreKind]
    /// Easy (smaller) versions when the lowest focus score is below `SidequestDemoRules.easyBelow`.
    var easy: Bool
}

nonisolated enum SidequestDemoRules {
    static let easyBelow = 50.0

    /// Same shape as the live rule: two options from the lowest score, one from the next if it is below 80.
    static func preview(day: Day, scores: [ScoreKind: Double]) -> SidequestPreview {
        var ranked: [(ScoreKind, Double)] = []
        for kind in ScoreKind.allCases {
            if let value = scores[kind], value.isFinite { ranked.append((kind, value)) }
        }
        // Stable sort keeps ScoreKind order for equal scores.
        ranked = ranked.enumerated().sorted { a, b in
            a.element.1 == b.element.1 ? a.offset < b.offset : a.element.1 < b.element.1
        }.map(\.element)
        guard let first = ranked.first else {
            return SidequestPreview(focus: [], focusScores: [:], options: [], kinds: [:], easy: false)
        }
        var picks = [first.0, first.0, first.0]
        if ranked.count > 1, ranked[1].1 < 80 { picks[2] = ranked[1].0 }
        var options: [Sidequest] = []
        var kinds: [String: ScoreKind] = [:]
        for kind in picks {
            let pool = (pools[kind] ?? []).filter { quest in !options.contains { $0.id == quest.id } }
            guard !pool.isEmpty else { continue }
            let quest = pool[((day.jdn % pool.count) + pool.count) % pool.count]
            options.append(quest)
            kinds[quest.id] = kind
        }
        var focus: [ScoreKind] = []
        for kind in picks where !focus.contains(kind) { focus.append(kind) }
        return SidequestPreview(focus: focus, focusScores: Dictionary(uniqueKeysWithValues: focus.map { ($0, scores[$0] ?? 0) }),
                                options: options, kinds: kinds, easy: first.1 < easyBelow)
    }

    /// Three or more tasks per score category, so one category can fill all three options, each with a normal and an easy version.
    static let pools: [ScoreKind: [Sidequest]] = [
        .sleep: existing("soft-landing", "cosy-corner", "quiet-song"),
        .rhythm: existing("tomorrow-you", "morning-plan") + [steadyWake, regularMeal],
        .movement: existing("colour-walk", "one-song", "new-view", "favourite-route", "stretch-break"),
        .daylight: existing("morning-light", "park-explorer") + [daylightDrink],
        .places: [smallErrand, favouriteSpot, newStreet],
        .body: [slowBreaths, waterRest, restBreak],
    ]

    private static func existing(_ ids: String...) -> [Sidequest] {
        ids.compactMap { id in SidequestRules.catalog.first { $0.id == id } }
    }

    private static func quest(_ id: String, _ category: SidequestCategory, _ title: String, _ minutes: Int, _ instruction: String,
                              _ easyTitle: String, _ easyMinutes: Int, _ easyInstruction: String) -> Sidequest {
        Sidequest(id: id, category: category,
                  regular: SidequestVersion(title: title, instruction: instruction, minutes: minutes),
                  smaller: SidequestVersion(title: easyTitle, instruction: easyInstruction, minutes: easyMinutes))
    }

    static let steadyWake = quest("steady-wake", .sleep,
        "Get up at your usual time tomorrow", 2, "Set an alarm for your usual wake-up time and get up when it rings.",
        "Check your usual alarm is set", 1, "Check that tomorrow's alarm matches your usual wake-up time.")
    static let regularMeal = quest("regular-meal", .nutrition,
        "Have a meal at your usual time today", 10, "Have something to eat at your usual mealtime. A simple meal is fine.",
        "Have a snack around your usual mealtime", 2, "Have one familiar snack around the time you usually eat.")
    static let daylightDrink = quest("daylight-drink", .movement,
        "Have a drink outside or by an open window", 10, "During daylight, have a drink outside or by an open window.",
        "Sit by a window for a minute", 1, "During daylight, sit by a window for a minute and look outside.")
    static let smallErrand = quest("small-errand", .movement,
        "Do one small errand outside your home", 15, "Do one small errand outside, like a short shop visit or posting a letter.",
        "Take out the rubbish", 3, "Take the rubbish or recycling out.")
    static let favouriteSpot = quest("favourite-spot", .movement,
        "Visit a café, library or shop you like", 20, "Visit a café, library or shop you like. A short visit is enough.",
        "Step out to your balcony, yard or stairwell", 2, "Step out to your balcony, yard or stairwell for a couple of minutes.")
    static let newStreet = quest("new-street", .movement,
        "Walk down a street you rarely take", 15, "Walk along a street or path you don't usually use. Turn back whenever you want.",
        "Look out at the street for a minute", 1, "Look out of a window or door at the street for a minute.")
    static let restBreak = quest("rest-break", .sleep,
        "Take a couple of breaks today", 10, "Take two or three short breaks today. Sit down, stretch or look out of a window.",
        "Sit or lie down for five minutes", 5, "Sit or lie down for five minutes and let your shoulders relax.")
    static let slowBreaths = quest("slow-breaths", .sleep,
        "Take ten minutes of slow, calm breathing", 10, "Sit comfortably and breathe slowly for ten minutes. Stop if it feels uncomfortable.",
        "Take a short moment of calm breathing", 1, "Pause for a moment and breathe slowly and calmly. Let your shoulders relax.")
    static let waterRest = quest("water-rest", .nutrition,
        "Remember to drink water throughout the day", 1, "Keep a glass or bottle of water nearby and drink some now and then during the day.",
        "Get a glass of water when you're thirsty", 1, "When you feel thirsty, get yourself a glass of water.")
}

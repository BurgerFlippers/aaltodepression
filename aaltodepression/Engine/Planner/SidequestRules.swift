import Foundation

/// Small, explainable demo rules. No missing-data penalties or clinical severity claims.
nonisolated enum SidequestRules {
    static func make(day: Day, signal: StepDay?, hasMedication: Bool) -> SidequestDay {
        let usable = signal.flatMap { day - $0.day >= 0 && day - $0.day <= 1 ? $0 : nil }
        let scores = usable?.result.scores ?? [:]
        var candidates: [(SidequestCategory, Double)] = []
        if let sleep = [scores[.sleep], scores[.rhythm]].compactMap({ $0 }).filter(\.isFinite).min() {
            candidates.append((.sleep, sleep))
        }
        if let movement = scores[.movement], movement.isFinite { candidates.append((.movement, movement)) }
        candidates.sort { $0.1 == $1.1 ? $0.0.rawValue < $1.0.rawValue : $0.1 < $1.1 }
        let small = usable?.result.likelyIll == true || usable?.step == .reachOut || candidates.first.map { $0.1 < 45 } == true
        var categories: [SidequestCategory]
        let reason: String
        if let first = candidates.first {
            categories = [first.0, first.0, first.0]
            if candidates.count > 1, candidates[1].1 < 75, candidates[1].1 <= first.1 + 20 {
                categories[2] = candidates[1].0
            }
            reason = categories[2] != first.0 ? "A little support for your sleep and movement, based on shared Health readings." : first.0 == .sleep ? "A small way to support your sleep, based on shared Health readings." : "A little movement, based on shared Health readings."
        } else {
            categories = [.movement, .nutrition, .social]
            if hasMedication && day.jdn % 5 == 0 { categories[1] = .medicine }
            reason = "No comparable Health readings yet. Here are three gentle ideas to choose from."
        }
        var chosen: [Sidequest] = []
        for category in categories {
            let pool = catalog.filter { $0.category == category && !chosen.map(\.id).contains($0.id) }
            if !pool.isEmpty { chosen.append(pool[((day.jdn % pool.count) + pool.count) % pool.count]) }
        }
        return SidequestDay(options: chosen, reason: reason, signalDay: candidates.isEmpty ? nil : usable?.day, startsSmall: small)
    }

    private static func quest(_ id: String, _ category: SidequestCategory, _ title: String, _ minutes: Int, _ instruction: String,
                              _ smallTitle: String, _ smallMinutes: Int, _ smallInstruction: String) -> Sidequest {
        Sidequest(id: id, category: category,
                  regular: SidequestVersion(title: title, instruction: instruction, minutes: minutes),
                  smaller: SidequestVersion(title: smallTitle, instruction: smallInstruction, minutes: smallMinutes))
    }

    static let catalog: [Sidequest] = [
        quest("colour-walk", .movement, "Find three colourful things on a walk", 10, "Take a 10-minute walk outside. Find three things in your favourite colour.", "Find one thing in your favourite colour", 1, "From a comfortable spot, find one thing in your favourite colour."),
        quest("one-song", .movement, "Move gently to one favourite song", 4, "Play a favourite song and move or stretch comfortably, seated or standing.", "Try one comfortable movement to music", 1, "Play a little of a favourite song. Try one comfortable movement, even just your hands."),
        quest("new-view", .movement, "Take a five-minute walk or roll somewhere nearby", 5, "Walk or roll to a nearby spot for five minutes. Notice one interesting detail.", "Move to a different comfortable spot in your room", 1, "Move to another comfortable spot in your room. Notice one thing you can see."),
        quest("park-explorer", .movement, "Spend 15 minutes in a nearby park", 15, "Spend 15 minutes in a nearby park. Find a tree, leaf or view you like.", "Spend two minutes just outside your door", 2, "If comfortable and accessible, spend two minutes just outside your door."),
        quest("tomorrow-you", .sleep, "Put one thing ready for tomorrow morning", 5, "Put out a mug, clothes or a breakfast bowl to make tomorrow morning easier.", "Put your morning mug or clothes within reach", 1, "Choose just one useful thing and place it where you will see it in the morning."),
        quest("soft-landing", .sleep, "Dim the lights and unwind for five minutes tonight", 5, "Before your usual bedtime, dim a light and enjoy five minutes of calm music or reading.", "Dim one light before your usual bedtime", 1, "Before your usual bedtime, dim one light and take a quiet moment. Nothing else to prepare."),
        quest("morning-light", .sleep, "Take a five-minute daylight break outside", 5, "Take a five-minute daylight break outside. Notice the sky and sounds around you.", "Open the curtains and sit by a window for a moment", 1, "During daylight hours, open the curtains and spend a moment by a window. An outdoor break can wait."),
        quest("cosy-corner", .sleep, "Clear a small space beside your bed for tonight", 5, "Clear one small spot by your bed. Put a familiar book within reach for tonight.", "Move one thing from your bedside", 1, "Move just one thing from your bedside to make a little space for tonight."),
        quest("easy-snack", .nutrition, "Have two easy foods you enjoy together", 3, "Have two easy foods you enjoy, such as yoghurt and fruit. Choose what suits your dietary needs.", "Put a familiar ready-to-eat snack within reach", 1, "Put one familiar, ready-to-eat food within reach. Choose what suits your dietary needs."),
        quest("simple-meal", .nutrition, "Make a simple meal with three familiar foods", 10, "Make a meal from ready soup, bread and a topping you like, or another familiar combination.", "Take the first step to prepare a ready meal", 2, "Choose a familiar ready meal or leftovers. Follow its first preparation step."),
        quest("food-favour", .nutrition, "Ask someone to share an easy meal", 3, "Ask someone: ‘Could we eat something easy together?’ A shared ready meal counts.", "Invite someone to share a snack", 1, "Send someone: ‘Fancy sharing a snack sometime?’ You do not need to arrange everything now."),
        quest("send-song", .social, "Send a friend a song that reminds you of them", 3, "Send a friend a favourite song and a quick ‘thought of you’.", "Send a short hello or an emoji to a friend", 1, "Send someone you like a short hello or an emoji. No long explanation needed."),
        quest("tea-invite", .social, "Invite a friend over for a cup of tea", 5, "Invite a friend over for tea, or suggest visiting them. Keep it short; no tidying needed.", "Tell a friend you would like to see them soon", 1, "Send: ‘Would be nice to see you soon.’ Pick the details together another time."),
        quest("walk-talk", .social, "Ask a friend to join you for a short walk", 5, "Ask a friend to join a short walk, roll or seated catch-up. Sending the invitation counts.", "Ask a friend for a quick call", 1, "Send: ‘Got a moment for a quick call sometime?’ Sending the invitation is enough for this quest."),
        quest("medicine-reminder", .medicine, "Check your existing medication reminder", 3, "Check your reminder for your existing medication routine. Keep your prescribed dose and schedule.", "Open your medication reminder and check its time", 1, "Open your medication reminder and check its time. Keep your prescribed dose and schedule."),
        quest("medicine-stock", .medicine, "Check your medication supply", 3, "Check your regular medication supply. If it is running low, note the next pharmacy step.", "Find your regular medication and check the supply", 1, "Find your regular medication and check whether a refill needs planning."),
        quest("pharmacy-company", .medicine, "Ask someone to join a needed pharmacy visit", 3, "If a pharmacy visit is due, ask someone to join you or help arrange it.", "Ask someone if they can help with a pharmacy visit", 1, "Ask someone: ‘Could you help with a pharmacy visit when I need it?’"),
        quest("favourite-route", .movement, "Walk or roll a familiar route for ten minutes", 10, "Walk or roll a familiar route for ten minutes. Turn back whenever you want.", "Move towards your front door", 1, "Take a comfortable step towards the door, seated or standing. Going outside can wait."),
        quest("stretch-break", .movement, "Take a three-minute stretch break", 3, "Spend three minutes gently moving your shoulders, hands or feet. Stop if it hurts.", "Relax your shoulders once", 1, "Make one gentle shoulder movement or another comfortable movement. That is enough."),
        quest("quiet-song", .sleep, "Choose one calm song for your evening", 4, "Before your usual bedtime, listen to one calm, familiar song at a comfortable volume.", "Play a little calm music tonight", 1, "Listen to a short part of a calm song before your usual bedtime."),
        quest("morning-plan", .sleep, "Write down one easy thing for tomorrow morning", 3, "Write down one easy morning action, like opening the curtains. Leave the note where you will see it.", "Choose your first small step for tomorrow", 1, "Pick one easy morning action in your mind. No list needed."),
        quest("easy-breakfast", .nutrition, "Put an easy breakfast ready for tomorrow", 5, "Put an easy breakfast ready for tomorrow. Keep chilled food in the fridge.", "Choose one easy breakfast food", 1, "Pick one familiar food you could have tomorrow. No preparation needed."),
        quest("food-check", .nutrition, "Find one easy meal you already have at home", 3, "Look in one cupboard or the fridge. Find a familiar meal or snack that suits you.", "Look in one cupboard for a snack", 1, "Find one familiar ready-to-eat food. You do not need to organise the cupboard."),
        quest("shared-meal", .nutrition, "Invite someone to share a simple meal", 5, "Invite a friend or someone close to share a simple meal. A ready meal is fine.", "Ask someone about eating together", 1, "Send a short invitation. You can work out the food and time together later."),
        quest("send-photo", .social, "Send a friend a photo of something you noticed", 3, "Send a friend a photo of something you noticed. Add a short hello if you like.", "Send a friend one emoji", 1, "Pick an emoji that feels like you today and send it to someone you like."),
        quest("thank-person", .social, "Thank someone for one small thing", 3, "Send someone a short thank-you for a kind gesture, useful favour or funny moment.", "Send a quick thank-you", 1, "A short ‘thanks for being there’ is enough."),
        quest("voice-hello", .social, "Send a friend a short voice hello", 3, "Send a friend a short voice hello in your usual messaging app. A typed message works too.", "Tell someone you are thinking of them", 1, "Send a short hello in whichever way feels easiest."),
        quest("pharmacy-note", .medicine, "Save one question for your next pharmacy visit", 3, "Write one medication question for your pharmacist. Keep following your prescribed instructions.", "Think of one medication question", 1, "Think of one question about your medication instructions to ask a pharmacist."),
        quest("medicine-place", .medicine, "Check your medication is stored as instructed", 3, "Check medication storage instructions. Keep it in original packaging and out of children’s reach.", "Read the storage line on your medication", 1, "Read the storage instructions on your medication. Leave it where it is if you are unsure."),
        quest("medicine-routine", .medicine, "Review your next scheduled medication reminder", 3, "Check your next medication reminder against your prescribed schedule. Do not take an extra dose.", "Check the next reminder in your tracker", 1, "Look at your next medication reminder. Keep following your prescribed instructions.")
    ]
}

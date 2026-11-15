import SwiftUI

/// The entire tile is the choice. No navigation or secondary controls inside a challenge.
struct BesideSidequestView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showReason = false
    @State private var showMessages = false
    @State private var showReminder = false
    @State private var celebration = false
    @State private var extraPick: String?

    var body: some View {
        if let offer = presentation.sidequest {
            let day = presentation.day
            let finished = offer.completedAt != nil
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.selected == nil ? "Pick the one that fits today" : finished ? "Done for today" : "Your choice for today")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if offer.selected == nil {
                            Text("You can also do more if you feel like it.").font(.footnote).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button { showReason = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }
                        .accessibilityLabel("Why these challenges?")
                    if offer.selected != nil {
                        // Works in every state, also after tasks are marked done.
                        Button {
                            extraPick = nil
                            presentation.backend.planner.revertSidequest(on: day)
                        } label: {
                            Label("Revert", systemImage: "arrow.uturn.backward").font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        .accessibilityHint("Clears today's choice and anything marked done")
                        .accessibilityIdentifier("challenge-revert")
                    }
                }
                if let quest = offer.selected {
                    // All three stay in place. Before the chosen one is done the others step back;
                    // afterwards they come back as optional extras.
                    ForEach(Array(offer.options.enumerated()), id: \.element.id) { index, option in
                        let chosen = option.id == quest.id
                        let done = offer.isDone(option.id)
                        let picked = chosen || extraPick == option.id
                        let tile = MindChallengeTile(quest: option, smaller: chosen ? offer.useSmaller : offer.startsSmall, index: index)
                            .overlay {
                                RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous)
                                    .strokeBorder(EverydayStyle.accent, lineWidth: picked && !(finished && chosen && extraPick != nil) ? 2 : 0)
                            }
                            .overlay(alignment: .topTrailing) {
                                if done || chosen {
                                    Label(done ? "Done" : "Chosen", systemImage: done ? "checkmark.circle.fill" : "circle")
                                        .labelStyle(.iconOnly).font(.title2)
                                        .foregroundStyle(EverydayStyle.accent).padding(16)
                                }
                            }
                            .opacity(chosen || done || finished ? 1 : 0.35)
                        if finished && !done {
                            Button { extraPick = option.id } label: { tile }
                                .buttonStyle(.plain)
                                .accessibilityLabel(BesideQuestStyle.brief(option, smaller: offer.startsSmall))
                                .accessibilityHint("Double-tap to pick this as an extra")
                                .accessibilityAddTraits(extraPick == option.id ? .isSelected : [])
                        } else {
                            tile.accessibilityElement(children: .combine)
                                .accessibilityAddTraits(chosen ? .isSelected : [])
                        }
                    }
                    if !finished {
                        Text("A good choice. One small step is enough.")
                            .font(.subheadline).foregroundStyle(EverydayStyle.accent)
                            .multilineTextAlignment(.center).accessibilityIdentifier("challenge-encouragement")
                        Button("Mark as done") {
                            if presentation.backend.planner.completeSidequest(on: day) { celebration.toggle() }
                        }.buttonStyle(EverydayPrimaryButton()).accessibilityIdentifier("challenge-done")
                        HStack(spacing: 24) {
                            if quest.canInvite { Button("Invite someone") { showMessages = true } }
                            Button("Remind me") { showReminder = true }
                        }.font(.subheadline).padding(.top, 4)
                    } else {
                        let extras = offer.alsoDoneIDs?.count ?? 0
                        let remaining = offer.options.filter { !offer.isDone($0.id) }
                        Text(Self.praise(extras: extras))
                            .font(.headline).foregroundStyle(EverydayStyle.accent)
                            .multilineTextAlignment(.center).accessibilityIdentifier("challenge-praise")
                        if let pick = extraPick, remaining.contains(where: { $0.id == pick }) {
                            Button("Mark as done") {
                                if presentation.backend.planner.completeAnotherSidequest(pick, on: day) { extraPick = nil; celebration.toggle() }
                            }.buttonStyle(EverydayPrimaryButton()).accessibilityIdentifier("challenge-extra-done")
                        } else if !remaining.isEmpty {
                            Text("Feeling like a bit more? Pick another one above. Only if it feels good.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }
                } else {
                    ForEach(Array(offer.options.enumerated()), id: \.element.id) { index, quest in
                        choice(quest, smaller: offer.startsSmall, index: index, day: day)
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: offer.selectedID)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: offer.completedAt != nil)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: offer.alsoDoneIDs)
            .sensoryFeedback(.success, trigger: celebration)
            .onChange(of: day) { _, _ in extraPick = nil }
            .alert("Why these challenges?", isPresented: $showReason) { Button("Done", role: .cancel) {} } message: { Text(offer.reason) }
            .sheet(isPresented: $showMessages) { EverydaySocialView(sidequest: offer.selected, smallerQuest: offer.useSmaller) }
            .sheet(isPresented: $showReminder) { BesideSidequestReminderView(day: day) }
        }
    }

    private static func praise(extras: Int) -> String {
        switch extras {
        case 0: "Well done! You did today's one thing."
        case 1: "One more done. That's a lot to be proud of."
        default: "All done. What a day. Remember to rest too."
        }
    }

    private func choice(_ quest: Sidequest, smaller: Bool, index: Int, day: Day) -> some View {
        Button {
            if presentation.selectSidequest(quest.id, smaller: smaller, on: day) { celebration.toggle() }
        } label: { MindChallengeTile(quest: quest, smaller: smaller, index: index) }
            .buttonStyle(.plain)
            .accessibilityLabel(BesideQuestStyle.brief(quest, smaller: smaller))
            .accessibilityHint("Double-tap to choose this challenge")
            .accessibilityIdentifier("challenge-choice-\(quest.id)")
    }
}

private struct MindChallengeTile: View {
    let quest: Sidequest
    let smaller: Bool
    let index: Int
    @ScaledMetric(relativeTo: .headline) private var symbolSize = 34

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: BesideQuestStyle.visual(quest))
                .font(.system(size: symbolSize, weight: .regular)).symbolRenderingMode(.hierarchical)
                .foregroundStyle(EverydayStyle.accent).frame(minHeight: 40).accessibilityHidden(true)
            Text(BesideQuestStyle.brief(quest, smaller: smaller))
                .font(.headline).foregroundStyle(.primary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(BesideQuestStyle.cardColor(index), in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
    }
}

nonisolated enum BesideQuestStyle {
    static func brief(_ quest: Sidequest, smaller: Bool) -> String {
        let words: (String, String)
        switch quest.id {
        case "colour-walk": words = ("Spend a little time in nature.", "Find one colourful thing nearby.")
        case "one-song": words = ("Move gently to a favourite song.", "Take a short walk around your home.")
        case "new-view": words = ("Take a short walk somewhere nearby.", "Move to a different spot in your room.")
        case "park-explorer": words = ("Spend a little time in a nearby park.", "Step outside for a breath of fresh air.")
        case "favourite-route": words = ("Walk or roll a familiar route.", "Step outside for a moment.")
        case "stretch-break": words = ("Gently stretch your shoulders, hands or feet.", "Relax your shoulders once.")
        case "tomorrow-you": words = ("Put one thing ready for tomorrow morning.", "Have a snack at least once today.")
        case "soft-landing": words = ("Dim the lights and unwind before bed.", "Turn off the bedroom lights before bed.")
        case "morning-light": words = ("Take a little daylight break outside.", "Open the curtains in the morning, close them in the evening.")
        case "cosy-corner": words = ("Tidy your bedroom.", "Tidy your bedside table.")
        case "quiet-song": words = ("Listen to a calm song before bed.", "Listen to a little calm music.")
        case "morning-plan": words = ("Leave a note with one easy morning action.", "Choose one easy thing to do tomorrow.")
        case "easy-snack": words = ("Have two easy foods you enjoy together.", "Put a familiar snack within reach.")
        case "simple-meal": words = ("Make an easy meal, like soup and bread.", "Choose a ready meal or leftovers.")
        case "food-favour": words = ("Ask someone to share an easy meal.", "Invite someone to share a snack.")
        case "easy-breakfast": words = ("Put an easy breakfast ready for tomorrow.", "Choose a familiar breakfast food.")
        case "food-check": words = ("Find one easy meal you have at home.", "Look in one cupboard for a snack.")
        case "shared-meal": words = ("Invite a friend to share a simple meal.", "Ask someone about eating together.")
        case "send-song": words = ("Send a friend a song that made you think of them.", "Send a friend a quick hello.")
        case "tea-invite": words = ("Invite a friend over for a cup of tea.", "Tell a friend you would like to see them.")
        case "walk-talk": words = ("Ask a friend to join you for a short walk.", "Ask a friend for a quick call.")
        case "send-photo": words = ("Send a friend a photo of something you noticed.", "Send a friend one emoji.")
        case "thank-person": words = ("Thank someone for one small thing.", "Send a quick thank-you.")
        case "voice-hello": words = ("Send a friend a short voice hello.", "Tell someone you are thinking of them.")
        case "medicine-reminder": words = ("Check your existing medication reminder.", "Check the time of your next reminder.")
        case "medicine-stock": words = ("Check whether your medication needs a refill.", "Find your regular medication supply.")
        case "pharmacy-company": words = ("Ask someone to join a needed pharmacy visit.", "Ask someone about pharmacy help.")
        case "pharmacy-note": words = ("Write one medication question for your pharmacist.", "Think of one question for your pharmacist.")
        case "medicine-place": words = ("Check the storage instructions on your medication.", "Read the storage line on the packaging.")
        case "medicine-routine": words = ("Check your reminder against your prescribed schedule.", "Look at your next medication reminder.")
        case "steady-wake": words = ("Get up at your usual time tomorrow.", "Check your usual alarm is set.")
        case "regular-meal": words = ("Have a meal at your usual time today.", "Have a snack around your usual mealtime.")
        case "daylight-drink": words = ("Have a drink outside or by an open window.", "Sit by a window for a minute.")
        case "small-errand": words = ("Do one small errand outside your home.", "Take out the rubbish.")
        case "favourite-spot": words = ("Visit a café, library or shop you like.", "Step out to your balcony, yard or stairwell.")
        case "slow-breaths": words = ("Take ten minutes of slow, calm breathing.", "Take a short moment of calm breathing.")
        case "water-rest": words = ("Remember to drink water throughout the day.", "Get a glass of water when you're thirsty.")
        case "new-street": words = ("Walk down a street you rarely take.", "Look out at the street for a minute.")
        case "rest-break": words = ("Take a couple of breaks today.", "Sit or lie down for five minutes.")
        default: words = (quest.regular.title, quest.smaller.title)
        }
        return smaller ? words.1 : words.0
    }

    static func cardColor(_ index: Int) -> Color {
        Color(red: 0.22, green: 0.17, blue: 0.31)
    }

    static func visual(_ quest: Sidequest) -> String {
        switch quest.id {
        case "new-view", "park-explorer", "favourite-route", "walk-talk": "figure.walk"
        case "colour-walk": "leaf.fill"
        case "one-song": "figure.dance"
        case "stretch-break": "figure.cooldown"
        case "tomorrow-you": "tshirt"
        case "soft-landing", "quiet-song": "moon.zzz.fill"
        case "morning-light", "morning-plan": "sun.max.fill"
        case "cosy-corner": "sparkles"
        case "food-favour", "shared-meal", "simple-meal", "food-check": "fork.knife"
        case "easy-snack", "easy-breakfast": "carrot.fill"
        case "tea-invite": "cup.and.saucer.fill"
        case "send-photo": "photo.fill"
        case "send-song": "music.note"
        case "thank-person": "heart.fill"
        case "voice-hello": "person.2.fill"
        case "pharmacy-company", "pharmacy-note": "cross.case.fill"
        case "steady-wake": "alarm.fill"
        case "regular-meal": "clock.fill"
        case "daylight-drink": "mug.fill"
        case "small-errand": "trash.fill"
        case "favourite-spot": "mappin.and.ellipse"
        case "slow-breaths": "wind"
        case "water-rest": "drop.fill"
        case "new-street": "signpost.right.fill"
        case "rest-break": "sofa.fill"
        default: "pills.fill"
        }
    }

    static func tone(_ optionIndex: Int) -> Double { [1.0, 0.72, 0.45][abs(optionIndex % 3)] }

    static func kind(_ quest: Sidequest) -> (title: String, symbol: String) {
        switch quest.id {
        case "tomorrow-you", "morning-plan": ("Morning prep", "sunrise")
        case "soft-landing", "quiet-song", "cosy-corner": ("Wind-down", "moon.stars")
        case "morning-light": ("Daylight", "sun.max")
        case "one-song", "stretch-break": ("Gentle movement", "figure.cooldown")
        case "colour-walk", "new-view", "park-explorer", "favourite-route": ("Explore outside", "leaf")
        case "easy-snack", "food-check": ("Easy bite", "carrot")
        case "simple-meal", "easy-breakfast": ("Meal prep", "fork.knife")
        case "food-favour", "shared-meal": ("Eat together", "person.2")
        case "tea-invite", "walk-talk": ("Time together", "cup.and.saucer")
        case "send-song": ("Share a song", "music.note")
        case "send-photo": ("Share a moment", "photo")
        case "thank-person": ("A little kindness", "heart")
        case "voice-hello": ("Say hello", "bubble.left")
        case "medicine-stock": ("Supply check", "pills")
        case "pharmacy-company", "pharmacy-note": ("Pharmacy help", "cross.case")
        case "medicine-place": ("Medication care", "cabinet")
        default: ("Your reminder", "bell")
        }
    }

    static func color(_ category: SidequestCategory) -> Color {
        switch category {
        case .sleep: EverydayStyle.yellow
        case .movement: EverydayStyle.mint
        case .nutrition: EverydayStyle.peach
        case .social: EverydayStyle.lavender
        case .medicine: EverydayStyle.blue
        }
    }
}

import SwiftUI

/// Asks one question, only when the person's own signals have drifted (support step 1 or 2)
/// and nothing has been answered today. A change prompts a question, not a conclusion.
/// The answer goes to the planner and, when allowed, to Apple Health as a State of Mind.
struct BesideSignalCheckInCard: View {
    @Environment(BesidePresentation.self) private var presentation
    @State private var answered: Int?
    private let words = ["Very low", "Low", "Okay", "Good", "Very good"]
    private let symbols = ["cloud.rain", "cloud", "cloud.sun", "sun.min", "sun.max"]

    private var shouldAsk: Bool {
        guard !presentation.isDemoMode, let step = presentation.healthSignal?.step, step != .steady else { return false }
        return presentation.checkIn == nil || answered != nil
    }

    /// The area that is furthest from the person's usual, phrased plainly.
    private var reason: String {
        let scores = presentation.healthSignal?.result.scores ?? [:]
        guard let weakest = scores.min(by: { $0.value < $1.value })?.key else { return "Your days have looked different from your usual this week." }
        switch weakest {
        case .sleep: return "Your sleep has looked different from your usual this week."
        case .rhythm: return "Your daily rhythm has looked different from your usual this week."
        case .movement: return "Your movement has looked different from your usual this week."
        case .daylight: return "You've had less daylight than usual this week."
        case .places: return "You've been out less than usual this week."
        case .body: return "Your body signals have looked different from your usual this week."
        }
    }

    var body: some View {
        if shouldAsk {
            VStack(alignment: .leading, spacing: 14) {
                if let answered {
                    Label("Thanks, saved.", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(EverydayStyle.accent)
                    Text(answered <= 2 ? "On a heavy day, the smallest choice below is enough. You can change your answer in For you."
                                       : "You answered \(words[answered - 1].lowercased()). You can change it in For you.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(reason).font(.subheadline).foregroundStyle(.secondary)
                    Text("How are you feeling today?").font(.headline)
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { value in
                            Button { answer(value) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: symbols[value - 1]).font(.title3).frame(height: 28)
                                    Text(words[value - 1]).font(.caption2.weight(.semibold)).multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(EverydayStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }.buttonStyle(.plain).accessibilityLabel(words[value - 1])
                        }
                    }
                    Text("Only you see this. It is saved to Apple Health as a mood entry when allowed.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
            .accessibilityElement(children: .contain)
        }
    }

    private func answer(_ mood: Int) {
        // One question only: keep an earlier energy answer from today, otherwise record a neutral one.
        let planner = presentation.liveBackend.planner
        let earlier = planner.state.checkIn(on: presentation.day)
        planner.checkIn(mood: mood, energy: earlier?.energy ?? .some, feelings: earlier?.feelings ?? [], foodAtHome: earlier?.foodAtHome)
        withAnimation { answered = mood }
    }
}

import SwiftUI

struct BesideCheckInView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var mood = 0
    @State private var energy = 0
    @State private var failed = false
    private let moodWords = ["Very low", "Low", "Okay", "Good", "Very good"]
    private let energyWords = ["Low", "Moderate", "High"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How is everyday life going?").font(.title2.bold())
                    choices(title: "How are you feeling today?", labels: moodWords, selected: $mood, color: EverydayStyle.peach)
                    choices(title: "How is your energy today?", labels: energyWords, selected: $energy, color: EverydayStyle.mint)
                }.padding(20)
            }.background(EverydayStyle.paper)
                .navigationTitle("Check in").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Save check-in") {
                        // Updating the two visible answers preserves earlier optional answers.
                        var answers = presentation.checkIn.map { QuestionCatalog.answers(for: $0) } ?? [:]
                        answers[QuestionCatalog.mood.id] = .number(mood)
                        answers[QuestionCatalog.energy.id] = .option(energy - 1)
                        if presentation.backend.planner.submitCheckIn(answers) { dismiss() } else { failed = true }
                    }.buttonStyle(EverydayPrimaryButton()).disabled(mood == 0 || energy == 0).padding(20).background(EverydayStyle.paper)
                }
                .onAppear {
                    if let checkIn = presentation.checkIn {
                        mood = checkIn.mood; energy = checkIn.energy.rawValue
                    }
                }
                .alert("Choose an answer for both questions", isPresented: $failed) { Button("OK", role: .cancel) {} }
        }
    }
    private func choices(title: String, labels: [String], selected: Binding<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.headline)
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Button { selected.wrappedValue = index + 1 } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(selected.wrappedValue == index + 1 ? EverydayStyle.accent : EverydayStyle.surfaceRaised).frame(width: 36, height: 36)
                                Image(systemName: selected.wrappedValue == index + 1 ? "checkmark" : "circle").font(.subheadline.weight(.semibold)).foregroundStyle(selected.wrappedValue == index + 1 ? .black : EverydayStyle.ink)
                            }
                            Text(label).font(.caption.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 70, alignment: .top).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(label).accessibilityAddTraits(selected.wrappedValue == index + 1 ? .isSelected : [])
                }
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
    }
}

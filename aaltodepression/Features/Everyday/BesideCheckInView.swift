import SwiftUI

struct BesideCheckInView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var mood = 0
    @State private var energy = 0
    @State private var feelings: Set<Feeling> = []
    @State private var food = -1
    @State private var details = false
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
                    DisclosureGroup("Anything else? (optional)", isExpanded: $details) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Any of these feel familiar?").font(.subheadline.weight(.semibold))
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                                ForEach(Feeling.allCases) { feeling in
                                    Button {
                                        if feelings.contains(feeling) { feelings.remove(feeling) } else { feelings.insert(feeling) }
                                    } label: {
                                        HStack { Image(systemName: feelings.contains(feeling) ? "checkmark.circle.fill" : "circle"); Text(feeling.title).font(.subheadline); Spacer(minLength: 0) }
                                            .padding(10).frame(maxWidth: .infinity, minHeight: 44).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                                    }.buttonStyle(.plain).accessibilityAddTraits(feelings.contains(feeling) ? .isSelected : [])
                                }
                            }
                            Picker("Food at home", selection: $food) {
                                Text("Skip").tag(-1)
                                ForEach(Array(FoodAtHome.allCases.enumerated()), id: \.element.id) { index, answer in Text(answer.title).tag(index) }
                            }.pickerStyle(.menu)
                        }.padding(.top, 16)
                    }.font(.headline).padding(18).background(EverydayStyle.lavender, in: RoundedRectangle(cornerRadius: 20))
                }.padding(20)
            }.background(EverydayStyle.paper)
                .navigationTitle("Check in").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Save check-in") {
                        var answers: [String: Answer] = [QuestionCatalog.mood.id: .number(mood), QuestionCatalog.energy.id: .option(energy - 1)]
                        if !feelings.isEmpty { answers[QuestionCatalog.feelings.id] = .options(Set(feelings.compactMap { Feeling.allCases.firstIndex(of: $0) })) }
                        if food >= 0 { answers[QuestionCatalog.food.id] = .option(food) }
                        if presentation.backend.planner.submitCheckIn(answers) { dismiss() } else { failed = true }
                    }.buttonStyle(EverydayPrimaryButton()).disabled(mood == 0 || energy == 0).padding(20).background(EverydayStyle.paper)
                }
                .onAppear {
                    if let checkIn = presentation.checkIn {
                        mood = checkIn.mood; energy = checkIn.energy.rawValue; feelings = checkIn.feelings
                        food = checkIn.foodAtHome.flatMap { FoodAtHome.allCases.firstIndex(of: $0) } ?? -1
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
                                Circle().fill(selected.wrappedValue == index + 1 ? EverydayStyle.ink : .white.opacity(0.75)).frame(width: 36, height: 36)
                                Image(systemName: selected.wrappedValue == index + 1 ? "checkmark" : "circle").font(.subheadline.weight(.semibold)).foregroundStyle(selected.wrappedValue == index + 1 ? .white : EverydayStyle.ink)
                            }
                            Text(label).font(.caption.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 70, alignment: .top).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(label).accessibilityAddTraits(selected.wrappedValue == index + 1 ? .isSelected : [])
                }
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: 20))
    }
}

import SwiftUI

struct BesideCheckInView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var mood = 0
    @State private var energy = 0
    @State private var failed = false
    private let moodWords = ["Very low", "Low", "Okay", "Good", "Very good"]
    var body: some View {
        NavigationStack {
            Form {
                Section(QuestionCatalog.mood.prompt) {
                    Picker("How today feels", selection: $mood) {
                        Text("Choose how you feel").tag(0)
                        ForEach(1...5, id: \.self) { value in Text(moodWords[value - 1]).tag(value) }
                    }.pickerStyle(.wheel).labelsHidden().frame(height: 170)
                }
                Section(QuestionCatalog.energy.prompt) {
                    Picker("Energy", selection: $energy) {
                        Text("Choose").tag(0)
                        ForEach(Array(Energy.allCases.enumerated()), id: \.element.id) { index, item in Text(item.title).tag(index + 1) }
                    }.pickerStyle(.segmented)
                }
                Section {
                    Button("Save check-in") {
                        let answers: [String: Answer] = [QuestionCatalog.mood.id: .number(mood), QuestionCatalog.energy.id: .option(energy - 1)]
                        if presentation.backend.planner.submitCheckIn(answers) { dismiss() } else { failed = true }
                    }.disabled(mood == 0 || energy == 0)
                } footer: { Text("A couple of taps is enough. You can update your answers later.") }
            }.navigationTitle("How is everyday life going?").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
                .onAppear {
                    if let checkIn = presentation.checkIn { mood = checkIn.mood; energy = checkIn.energy.rawValue }
                }
                .alert("Choose an answer for both questions", isPresented: $failed) { Button("OK", role: .cancel) {} }
        }
    }
}

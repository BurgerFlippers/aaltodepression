import SwiftUI

/// Home layout preferences; these never change the person's treatment or medication schedule.
struct BesideHomeBox: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var title: String
    var colorIndex: Int
    static let eat = Self(id: "eat", title: "Eat", colorIndex: 0)
    static let move = Self(id: "move", title: "Move", colorIndex: 1)
    static let sleep = Self(id: "sleep", title: "Sleep", colorIndex: 2)
    // Keep the existing stored task identifier when renaming Connect.
    static let social = Self(id: "connect", title: "Social", colorIndex: 3)
    static let medicine = Self(id: "medicine", title: "Medicine", colorIndex: 4)
    static let cleaning = Self(id: "cleaning", title: "Cleaning", colorIndex: 5)
    static let allCases: [Self] = [.eat, .move, .sleep, .social, .medicine, .cleaning]
    static var colors: [Color] { [EverydayStyle.peach, EverydayStyle.mint, EverydayStyle.yellow, EverydayStyle.lavender, EverydayStyle.blue, EverydayStyle.surfaceRaised] }
    var subtitle: String {
        switch id {
        case "eat": "At least 3 meals"
        case "move": "A short walk"
        case "sleep": "Last night"
        case "connect": "Stay in touch"
        case "medicine": "As prescribed"
        case "cleaning": "One small task"
        default: "At your own pace"
        }
    }
    var color: Color { Self.colors[abs(colorIndex % Self.colors.count)] }
    var pillar: Pillar {
        switch id { case "eat": .food; case "move": .movement; case "sleep": .sleep; case "connect": .social; case "medicine": .meds; default: .chores }
    }
    var legacyTask: EverydayTaskKind? {
        switch id { case "eat": .food; case "move": .movement; case "sleep": .sleep; default: nil }
    }
}

struct BesideEditBoxesView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [BesideHomeBox] = []
    @State private var title = ""
    @State private var colorIndex = 0
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(draft) { box in
                        Label {
                            Text(box.title)
                        } icon: { Circle().fill(box.color).frame(width: 18, height: 18) }
                    }.onDelete { draft.remove(atOffsets: $0) }
                        .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                } header: { Text("Your boxes") } footer: { Text("Drag to reorder. Remove anything you don't need. Removing a box keeps earlier records.") }
                let available = BesideHomeBox.allCases.filter { preset in !draft.contains(where: { $0.id == preset.id }) }
                if !available.isEmpty {
                    Section("Add a box") {
                        ForEach(available) { box in Button { draft.append(box) } label: { Label(box.title, systemImage: "plus.circle") } }
                    }
                }
                Section("Create your own") {
                    TextField("For example, Water plants", text: $title).submitLabel(.done)
                    Picker("Colour", selection: $colorIndex) {
                        ForEach(Array(["Peach", "Mint", "Yellow", "Lavender", "Blue", "Pink"].enumerated()), id: \.offset) { index, label in Text(label).tag(index) }
                    }
                    Button("Add custom box") {
                        draft.append(BesideHomeBox(id: "custom-\(UUID().uuidString)", title: title.trimmingCharacters(in: .whitespacesAndNewlines), colorIndex: colorIndex))
                        title = ""
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.environment(\.editMode, .constant(.active))
                .navigationTitle("Edit your boxes").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { presentation.saveBoxes(draft); dismiss() } }
                }
                .onAppear { draft = presentation.boxes }
        }
    }
}

struct BesideBoxDetailsView: View {
    let box: BesideHomeBox
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if box == .medicine { Text("Only mark this after taking your own medicine as instructed. This box doesn't create a medication schedule.") }
                    else if box == .cleaning { Text("One small thing at home is enough. Choose what matters to you today.") }
                    Text(presentation.day.start().formatted(date: .abbreviated, time: .omitted))
                    Button(presentation.isDone(box) ? "Undo mark" : "Mark as done") { presentation.toggle(box); dismiss() }
                }
            }.navigationTitle(box.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

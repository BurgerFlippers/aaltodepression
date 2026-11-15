import Foundation

/// Only the chosen task is shared with the widget. No Health readings or contact details.
nonisolated struct BesideWidgetTask: Codable, Equatable, Sendable {
    var date: Date
    var day: Int
    var taskID: String
    var title: String
    var category: String
    var minutes: Int
    var smaller: Bool
    var completed: Bool
}

nonisolated enum BesideWidgetStore {
    private static var directory: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "BesideAppGroup") as? String, !group.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    static func task() -> BesideWidgetTask? {
        guard let directory, let data = try? Data(contentsOf: directory.appendingPathComponent("sidequest-widget.json")),
              let task = try? JSONDecoder().decode(BesideWidgetTask.self, from: data),
              Calendar.current.isDateInToday(task.date) else { return nil }
        return task
    }

    @discardableResult static func publish(_ task: BesideWidgetTask?) -> Bool {
        guard let directory else { return false }
        let file = directory.appendingPathComponent("sidequest-widget.json")
        if let task {
            guard let data = try? JSONEncoder().encode(task) else { return false }
            do { try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); return true }
            catch { return false }
        }
        try? FileManager.default.removeItem(at: file)
        return true
    }

    static func clearCompletion() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("sidequest-completion.json"))
    }

}

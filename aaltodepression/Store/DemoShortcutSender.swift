import Foundation
import Observation

/// Persists attempts before leaving Mind, so a missing callback cannot cause repeated sends.
@MainActor @Observable final class DemoShortcutSender {
    private(set) var run: DemoShortcutRun?
    private let defaults: UserDefaults
    private let key = "mind.demo.shortcutRun.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) { run = try? JSONDecoder().decode(DemoShortcutRun.self, from: data) }
    }
    var coolingDown: Bool { run.map { Date().timeIntervalSince($0.startedAt) < 300 } ?? false }
    func begin(requestID: String, day: Day) -> URL? {
        guard !coolingDown else { return nil }
        let pending = DemoShortcutRun(id: UUID(), requestID: requestID, day: day.jdn, startedAt: Date(), status: .requested)
        guard let url = DemoShortcutLink.url(for: pending) else { return nil }
        run = pending
        save()
        return url
    }
    func didOpen(id: UUID, opened: Bool) {
        guard var current = run, current.id == id, current.status == .requested else { return }
        current.status = opened ? .opened : .failed
        run = current
        save()
    }
    @discardableResult func handle(_ url: URL) -> Bool {
        guard var current = run, let status = DemoShortcutLink.result(url, matching: current) else { return false }
        current.status = status
        run = current
        save()
        return true
    }
    var statusText: String? {
        guard let run else { return nil }
        switch run.status {
        case .requested: return "Starting Shortcuts…"
        case .opened: return "Handed to Shortcuts. Waiting for its result; delivery is not verified."
        case .completed: return "Shortcut finished. Message delivery is not verified."
        case .cancelled: return "Shortcut cancelled. No send is confirmed."
        case .failed: return "Shortcut did not finish. Check Mind Demo SMS in Shortcuts. No send is confirmed."
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(run) { defaults.set(data, forKey: key) }
    }
}

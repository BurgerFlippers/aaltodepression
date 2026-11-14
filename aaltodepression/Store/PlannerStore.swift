import Foundation

/// Saves the planner's state as one JSON file on this phone. It never leaves the device.
/// JSON rather than SwiftData so the app's model container (in UsualApp) does not change.
nonisolated struct PlannerStore: Sendable {
    let url: URL?

    /// Application Support/planner.json, readable after the first unlock so background work can save.
    static let live: PlannerStore = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return PlannerStore(url: dir?.appendingPathComponent("planner.json"))
    }()

    /// Keeps nothing; used by the demo and previews.
    static let memory = PlannerStore(url: nil)

    func load() -> PlannerState? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(PlannerState.self, from: data)
    }

    func save(_ state: PlannerState) {
        guard let url, let data = try? Self.encoder.encode(state) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// "Delete everything" for the planner.
    func erase() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

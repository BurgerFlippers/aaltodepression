import Foundation

nonisolated struct DemoShortcutRun: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case requested, opened, completed, cancelled, failed }
    var id: UUID
    var requestID: String
    var day: Int
    var startedAt: Date
    var status: Status
}

/// Runs the person's own "Mind Demo SMS" shortcut. Its text input is the recipient's number on the first line
/// and the demo message on the second. No Health values are ever included.
nonisolated enum DemoShortcutLink {
    static let name = "Mind Demo SMS"
    static func url(for run: DemoShortcutRun, text: String? = nil) -> URL? {
        func callback(_ outcome: String) -> String { "beside://demo-sms-\(outcome)?run=\(run.id.uuidString)" }
        var url = URLComponents()
        url.scheme = "shortcuts"
        url.host = "x-callback-url"
        url.path = "/run-shortcut"
        url.queryItems = [URLQueryItem(name: "name", value: name),
                          URLQueryItem(name: "x-success", value: callback("complete")),
                          URLQueryItem(name: "x-cancel", value: callback("cancel")),
                          URLQueryItem(name: "x-error", value: callback("error"))]
        if let text { url.queryItems! += [URLQueryItem(name: "input", value: "text"), URLQueryItem(name: "text", value: text)] }
        return url.url
    }
    static func result(_ url: URL, matching run: DemoShortcutRun) -> DemoShortcutRun.Status? {
        guard url.scheme == "beside", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.queryItems?.first(where: { $0.name == "run" })?.value == run.id.uuidString,
              run.status == .requested || run.status == .opened else { return nil }
        switch url.host {
        case "demo-sms-complete": return .completed
        case "demo-sms-cancel": return .cancelled
        case "demo-sms-error": return .failed
        default: return nil
        }
    }
}

/// Demo examples only. These are never inserted into Health or clinical scoring.
nonisolated struct DemoRoutineData: Sendable {
    var meals: Int
    var energy: Int
    var water: Int
    var doses: Int
    static func example(on day: Day, load: Double?) -> DemoRoutineData {
        let load = load.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil } ?? 0
        let meals = load >= 0.8 ? 1 : load >= 0.4 ? 2 : 3
        return DemoRoutineData(meals: meals, energy: meals * 650, water: meals * 600, doses: load >= 0.7 ? 0 : 1)
    }
    var eatScore: Double { Double(meals) / 3 * 100 }
    var medicineScore: Double { Double(doses) * 100 }
}

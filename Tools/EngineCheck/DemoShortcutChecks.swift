import Foundation

func demoShortcutChecks() -> [String] {
    var failures: [String] = []
    var count = 0
    func check(_ value: Bool, _ label: String) { count += 1; if !value { failures.append("Shortcut: " + label) } }
    let day = Day(year: 2026, month: 11, day: 15)
    let run = DemoShortcutRun(id: UUID(), requestID: "test-request", day: day.jdn, startedAt: day.start(), status: .requested)
    let link = DemoShortcutLink.url(for: run)!
    let parts = URLComponents(url: link, resolvingAgainstBaseURL: false)!
    check(parts.scheme == "shortcuts" && parts.host == "x-callback-url", "uses Apple's callback URL scheme")
    check(parts.queryItems?.first(where: { $0.name == "name" })?.value == "Mind Demo SMS", "runs only the named shortcut")
    check(parts.queryItems?.count == 4 && !link.absoluteString.contains("phone") && !link.absoluteString.contains("Health"), "passes no contact details, body or Health readings")
    for (name, status) in [("x-success", DemoShortcutRun.Status.completed), ("x-cancel", .cancelled), ("x-error", .failed)] {
        let url = URL(string: parts.queryItems!.first { $0.name == name }!.value!)!
        check(DemoShortcutLink.result(url, matching: run) == status, "recognizes " + name)
        var finished = run; finished.status = .completed
        check(DemoShortcutLink.result(url, matching: finished) == nil, "duplicate callbacks cannot change a completed run")
    }
    check(DemoShortcutLink.result(URL(string: "beside://demo-sms-complete?run=wrong")!, matching: run) == nil, "wrong run cannot claim success")
    check(DemoShortcutLink.result(URL(string: "other://demo-sms-complete?run=\(run.id.uuidString)")!, matching: run) == nil, "wrong scheme is rejected")
    let examples = DemoRoutineData.example(on: day, load: nil)
    check(examples.meals == 3 && examples.doses == 1, "demo fills Eat and Medicine")
    let harder = DemoRoutineData.example(on: day, load: 1)
    check(harder.eatScore < examples.eatScore && harder.medicineScore < examples.medicineScore, "demo controls adjust sample categories")
    check(examples.energy > 0 && examples.water > 0, "nutrition examples are populated")
    print("Demo shortcuts: \(count) checks, \(failures.count) failures")
    return failures
}

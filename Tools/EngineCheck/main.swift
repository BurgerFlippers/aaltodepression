import Foundation

// Prints the 60-day demo table and checks the brief's expectations.
// Run: Tools/engine-check.sh

let table = DemoSource.table()
let days = StepEngine.run(table: table, through: DemoSource.day(DemoSource.dayCount - 1),
                          homeTimeZone: DemoSource.homeTimeZone, locationEnabled: true)

func f(_ x: Double?) -> String { x.map { String(format: "%5.0f", $0) } ?? "    –" }

print(" day  date        sleep rhyth  move dayl  plac  body |  day  base drift 7d step flags")
var firstNudge: Int?, firstReach: Int?
for sd in days {
    let n = DemoSource.number(of: sd.day)
    let r = sd.result
    var flags = [String]()
    if r.likelyIll { flags.append("ill") }
    if r.travelling { flags.append("travel") }
    print(String(format: "%4d", n), sd.day, f(r.scores[.sleep]), f(r.scores[.rhythm]), f(r.scores[.movement]),
          f(r.scores[.daylight]), f(r.scores[.places]), f(r.scores[.body]), "|",
          f(r.steadiness), f(sd.baselineDay), sd.isDrift ? "  yes" : "    .", String(format: "%2d", sd.driftDaysInLastWeek),
          String(format: "%4d", sd.step.rawValue), flags.joined(separator: ","))
    if sd.step == .nudge, firstNudge == nil { firstNudge = n }
    if sd.step == .reachOut, firstReach == nil { firstReach = n }
}

var failures = [String]()
let escalatedEarly = days.filter { DemoSource.number(of: $0.day) < 45 && $0.step != .steady }
if !escalatedEarly.isEmpty { failures.append("escalated before day 45 on days \(escalatedEarly.map { DemoSource.number(of: $0.day) })") }
if let a = firstNudge { if !(48...50).contains(a) { failures.append("step 1 on day \(a), expected about 49") } } else { failures.append("step 1 never reached") }
if let b = firstReach { if !(58...59).contains(b) { failures.append("step 2 on day \(b), expected about 59") } } else { failures.append("step 2 never reached") }
for n in 30...32 { if days.first(where: { DemoSource.number(of: $0.day) == n })?.result.likelyIll != true { failures.append("cold day \(n) not flagged") } }
for n in 38...40 { if days.first(where: { DemoSource.number(of: $0.day) == n })?.result.travelling != true { failures.append("trip day \(n) not flagged") } }

// Every feature key in the catalog that the demo can provide must be present.
let notInDemo: Set<String> = [F.dietaryEnergy, F.dietaryWater, F.dietaryProtein, F.dietaryCarbs, F.dietaryFat]
let missing = FeatureCatalog.all.map(\.key).filter { !notInDemo.contains($0) && table.dayCount($0) == 0 }
if !missing.isEmpty { failures.append("demo lacks features: \(missing)") }

let plan = try CarePlan.load(from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
for n in [49, 50, 55] {
    let d = DemoSource.day(n)
    let recs = ActionHistory.records(plan: plan, history: days, table: table, before: d)
    if let s = ActionPicker.pick(plan: plan, table: table.truncated(through: d), day: d, records: recs) {
        print("day \(n) action:", s.action.title, recs.values.map { "\($0.action.key) \($0.helped)/\($0.tried)" }.sorted())
        if s.action.key != "breath" { failures.append("day \(n) suggests \(s.action.key), expected breath") }
    }
}

failures += reachOutChecks()
failures += sidequestChecks()
failures += demoScenarioChecks()
failures += plannerChecks(table: table, history: days)
failures += backendChecks(table: table)
failures += screenTimeChecks(table: table)
failures += demoStoryChecks(table: table, history: days)

print("\nstep 1 first on day \(firstNudge.map(String.init) ?? "–"), step 2 first on day \(firstReach.map(String.init) ?? "–")")
print(failures.isEmpty ? "ALL CHECKS PASSED" : "FAILED:\n  " + failures.joined(separator: "\n  "))
exit(failures.isEmpty ? 0 : 1)

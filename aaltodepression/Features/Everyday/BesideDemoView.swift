import SwiftUI

/// Balance first; readings and judging controls remain one deliberate tap away.
struct BesideDemoView: View {
    @Environment(BesidePresentation.self) private var presentation
    @State private var showDemo = false
    @State private var showReadings = false
    private var recorded: SidequestDay? { presentation.liveBackend.planner.state.sidequests[presentation.day.jdn] }
    private let categories: [SidequestCategory] = [.nutrition, .movement, .sleep, .social, .medicine]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DatePicker("Day", selection: Binding(get: { presentation.day.start() }, set: { presentation.selectDay(Day($0)) }),
                               in: (Day(Date()) - 120).start()...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("demo-day-picker")
                    BesideTrendBalanceView()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your routines").font(.title3.bold())
                        VStack(spacing: 0) {
                            ForEach(categories, id: \.rawValue) { category in
                                DisclosureGroup {
                                    ForEach(metrics(category)) { metric in
                                        LabeledContent(metric.title, value: metric.text(presentation.reading(metric)))
                                            .font(.subheadline).padding(.vertical, 5)
                                    }
                                    if category == .social { Text("Your conversations stay private. Use For you to reach out.").font(.subheadline).foregroundStyle(.secondary) }
                                    if category == .medicine { Text("Keep following your prescribed schedule. Medication tracking is not connected here.").font(.subheadline).foregroundStyle(.secondary) }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: symbol(category)).font(.title3).foregroundStyle(EverydayStyle.accent).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(category.title).font(.headline).foregroundStyle(.primary)
                                            Text(summary(category)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 4)
                                        if let score = presentation.categoryScore(category) {
                                            Text("\(Int(score.rounded()))").font(.title3.monospacedDigit().bold()).foregroundStyle(.primary)
                                        }
                                    }.padding(.vertical, 10)
                                }.padding(.horizontal, 16).padding(.vertical, 4)
                                if category != categories.last { Divider().padding(.leading, 58) }
                            }
                        }.background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    DisclosureGroup("Your chosen challenge") {
                        if let recorded, let quest = recorded.selected {
                            Text(BesideQuestStyle.brief(quest, smaller: recorded.useSmaller)).font(.headline).padding(.top, 10)
                            Text("Selected · no completion tap needed").font(.caption).foregroundStyle(.secondary)
                            Text(presentation.sidequestEvidence(on: presentation.day)).font(.caption).foregroundStyle(.secondary)
                        } else { Text("No challenge selected for this day.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
                    }.padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    Button { showReadings = true } label: {
                        HStack { Label("Health readings", systemImage: "heart.text.square"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                            .padding(18).background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).accessibilityIdentifier("trends-health-readings")
                    Text(presentation.selectedDayAvailability).font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.background(EverydayStyle.paper).navigationTitle("Trends")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Demo", systemImage: "slider.horizontal.3") { showDemo = true }.accessibilityIdentifier("trends-demo") } }
                .sheet(isPresented: $showDemo) { BesideDemoScenarioView() }
                .sheet(isPresented: $showReadings) { BesideDemoControlsView(embeddedInDemo: true) }
        }
    }

    private func metrics(_ category: SidequestCategory) -> [BesideHealthMetric] {
        switch category {
        case .nutrition: [.foodEnergy, .water, .protein, .carbs, .fat]
        case .movement: [.steps, .exercise, .daylight]
        case .sleep: [.sleep, .bedtime, .wake]
        default: []
        }
    }
    private func summary(_ category: SidequestCategory) -> String {
        if let score = presentation.categoryScore(category) { return score >= 70 ? "Close to your usual" : "Different from your usual" }
        switch category {
        case .nutrition: return presentation.reading(.foodEnergy).map { BesideHealthMetric.foodEnergy.text($0) + " logged" } ?? "No food log for this day"
        case .movement: return presentation.reading(.steps).map { BesideHealthMetric.steps.text($0) } ?? "No movement reading"
        case .sleep: return presentation.reading(.sleep).map { BesideHealthMetric.sleep.text($0) } ?? "No sleep reading"
        case .social: return "A little company can help"
        case .medicine: return "Your prescribed routine"
        }
    }
    private func symbol(_ category: SidequestCategory) -> String {
        switch category { case .nutrition: "fork.knife"; case .movement: "figure.walk"; case .sleep: "moon.zzz"; case .social: "person.2"; case .medicine: "pills" }
    }
}

struct BesideTrendBalanceView: View {
    @Environment(BesidePresentation.self) private var presentation
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily balance").font(.headline)
                Spacer()
                if let value = presentation.healthSignal?.result.steadiness {
                    Text("\(Int(value.rounded()))").font(.largeTitle.monospacedDigit().bold())
                    Text("/100").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(presentation.balanceTitle).font(.title3.weight(.semibold))
            GeometryReader { geometry in
                Capsule().fill(LinearGradient(colors: [.init(red: 0.77, green: 0.91, blue: 0.68), .init(red: 0.95, green: 0.83, blue: 0.36), .init(red: 0.91, green: 0.41, blue: 0.23), .init(red: 0.49, green: 0.06, blue: 0.13)], startPoint: .leading, endPoint: .trailing)).frame(height: 8).frame(height: 18)
                if let score = presentation.healthSignal?.result.steadiness {
                    Circle().fill(.white).overlay { Circle().strokeBorder(.black, lineWidth: 3) }.frame(width: 18, height: 18)
                        .offset(x: (geometry.size.width - 18) * min(1, max(0, 1 - score / 100)))
                }
            }.frame(height: 18).accessibilityHidden(true)
            HStack { Text("Your usual"); Spacer(); Text("More support") }.font(.caption).foregroundStyle(.secondary)
            if presentation.hasDemoEdits {
                Label("Demo values · Health is unchanged", systemImage: "testtube.2").font(.caption).foregroundStyle(EverydayStyle.accent)
            } else { Text("Compared with your own daily rhythm").font(.caption).foregroundStyle(.secondary) }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(EverydayStyle.surface, in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }
}

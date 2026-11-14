import SwiftUI
import Charts

// TEMPORARY backend testing area (see BackendTestingView.swift).
// Sleep, activity and places as the frontend gets them from `backend.tracking`.

struct SleepPage: View {
    let lab: BackendLab

    var body: some View {
        List {
            if let s = lab.tracking.sleep {
                Section {
                    Text(s.headline).font(.headline)
                    LabeledContent("Night ending", value: s.night.description)
                    LabeledContent("Data from", value: coverageText(s.coverage))
                } footer: {
                    Text("backend.tracking.sleep: SleepSummary. Nights belong to the morning they end.")
                }
                Section("Last night") {
                    ForEach([s.duration, s.fellAsleep, s.wokeUp, s.awake, s.efficiency, s.regularity]) { LabTrackedRow(value: $0) }
                    LabeledContent("Short nights in a row", value: "\(s.shortNights) of 3")
                }
                Section("Hours slept, 28 nights") {
                    LabTrendChart(points: s.trend, usual: s.usualHours, unit: "h")
                }
            } else { Text("No data") }
        }
        .navigationTitle("Sleep")
    }
}

struct ActivityPage: View {
    let lab: BackendLab

    var body: some View {
        List {
            if let a = lab.tracking.activity {
                Section {
                    Text(a.headline).font(.headline)
                    LabeledContent("As of", value: PlanFormat.clock(a.asOf))
                    LabeledContent("Data from", value: coverageText(a.coverage))
                    if let e = a.movementEvidence { LabeledContent("Movement the planner saw") { Text(e).font(.caption).multilineTextAlignment(.trailing) } }
                } footer: {
                    Text("backend.tracking.activity: ActivitySummary. Steps so far are compared with your usual by the same time of day.")
                }
                Section("Today") {
                    ForEach([a.stepsSoFar, a.activeHours, a.onFoot, a.exercise, a.daylight, a.walkingSpeed]) { LabTrackedRow(value: $0) }
                }
                Section("Steps by hour") {
                    Chart {
                        ForEach(Array(a.hourlySteps.enumerated()), id: \.offset) { h, v in
                            if let v { BarMark(x: .value("Hour", h), y: .value("Steps", v)) }
                        }
                    }
                    .chartXScale(domain: 0...23)
                    .frame(height: 140)
                }
                Section("Steps, 28 days") {
                    LabTrendChart(points: a.trend, usual: nil, unit: "steps")
                }
            } else { Text("No data") }
        }
        .navigationTitle("Activity")
    }
}

struct PlacesPage: View {
    let lab: BackendLab

    var body: some View {
        List {
            if let p = lab.tracking.places {
                Section {
                    Text(p.headline).font(.headline)
                    LabeledContent("Day", value: p.day.description)
                    LabeledContent("Location", value: p.locationEnabled ? "On" : "Off")
                } footer: {
                    Text("backend.tracking.places: PlacesSummary for the last complete day. Only daily numbers; coordinates never leave the phone.")
                }
                Section("Yesterday") {
                    ForEach([p.timeAtHome, p.timeAway, p.places, p.furthest, p.variety]) { LabTrackedRow(value: $0) }
                }
                Section("Hours away from home, 28 days") {
                    LabTrendChart(points: p.trend, usual: nil, unit: "h")
                }
            } else { Text("No data") }
        }
        .navigationTitle("Places")
    }
}

// MARK: - Shared pieces

/// One TrackedValue as a screen would show it: value, usual and a neutral comparison word.
struct LabTrackedRow: View {
    let value: TrackedValue

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value.title)
                if let u = value.usualText { Text(u).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value.text).monospacedDigit()
                Text(word).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var word: String {
        switch value.comparison {
        case .below: "below usual"
        case .usual: "at usual"
        case .above: "above usual"
        case .unknown: value.value == nil ? "no data" : "no usual yet"
        }
    }
}

struct LabTrendChart: View {
    let points: [TrendPoint]
    let usual: Double?
    let unit: String

    var body: some View {
        let first = points.first?.day ?? Day(jdn: 0)
        Chart {
            ForEach(points) { p in
                // Days back from today (0 = oldest), so the bars spread across the chart.
                if let v = p.value { BarMark(x: .value("Day", p.day - first), y: .value(unit, v)) }
            }
            if let u = usual { RuleMark(y: .value("Usual", u)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])) }
        }
        .chartXScale(domain: -0.5...Double(max(points.count, 1)) - 0.5)
        .chartXAxis(.hidden)
        .frame(height: 140)
    }
}

func coverageText(_ c: DataCoverage) -> String {
    switch c {
    case .none: "No data"
    case .phoneOnly: "iPhone"
    case .phoneAndWatch: "iPhone and Apple Watch"
    }
}

// MARK: - Questions and answers

struct QuestionsPage: View {
    let lab: BackendLab
    @State private var answers: [String: Answer] = [:]
    @State private var result = ""
    @State private var screenAnswers: [String: Answer] = [:]
    @State private var screenResult = ""

    var body: some View {
        List {
            Section {
                ForEach(QuestionCatalog.checkIn) { q in LabQuestionView(question: q, answer: $answers[q.id]) }
                Button("Submit as today's check-in") {
                    result = lab.planner.submitCheckIn(answers) ? "Saved. Daily flow shows the new list." : "Mood and energy are needed."
                }
                .buttonStyle(.borderedProminent)
                if !result.isEmpty { Text(result).font(.caption).foregroundStyle(.secondary) }
            } header: {
                Text("QuestionCatalog.checkIn, rendered generically")
            } footer: {
                Text("One component per AnswerKind (likert, scale, multiSelect, singleChoice, yesNo, numeric) renders every question. planner.submitCheckIn([questionID: Answer]).")
            }
            Section {
                ForEach(QuestionCatalog.screenTimeQuestions) { q in LabQuestionView(question: q, answer: $screenAnswers[q.id]) }
                Button("Save as yesterday's screen time") {
                    screenResult = lab.planner.answerScreenTime(screenAnswers) ? "Saved. See Tracking → Screen time." : "Answer at least one."
                }
                .buttonStyle(.borderedProminent)
                if !screenResult.isEmpty { Text(screenResult).font(.caption).foregroundStyle(.secondary) }
            } header: {
                Text("Bonus: screen time (singleChoice, numeric, yesNo)")
            } footer: {
                Text("planner.answerScreenTime([questionID: Answer]). Apple lets apps read Screen Time only with a special entitlement, so the person tells us: a rough range, or the exact minutes from Settings → Screen Time.")
            }
            Section("Other questions") {
                LabQuestionPreview(question: QuestionCatalog.groceries)
                LabQuestionPreview(question: QuestionCatalog.metSomeone)
                LabQuestionPreview(question: QuestionCatalog.safety(.wishDead))
            }
            Section {
                let log = lab.planner.answerLog.suffix(30).reversed()
                if log.isEmpty { Text("No answers yet").foregroundStyle(.secondary) }
                ForEach(Array(log)) { r in
                    LabeledContent(r.questionID, value: "\(text(r.answer)) · \(r.day.description)")
                        .font(.caption.monospaced())
                }
            } header: {
                Text("planner.answerLog (newest first)")
            } footer: {
                Text("Kept on the phone for learning what helps. Safety answers are never stored.")
            }
        }
        .navigationTitle("Questions and answers")
    }

    private func text(_ a: Answer) -> String {
        switch a {
        case .number(let n): "\(n)"
        case .option(let i): "option \(i)"
        case .options(let s): "options \(s.sorted())"
        case .yes(let b): b ? "yes" : "no"
        }
    }
}

/// Renders any Question by its AnswerKind.
struct LabQuestionView: View {
    let question: Question
    @Binding var answer: Answer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.prompt).font(.headline)
            if let h = question.hint { Text(h).font(.caption).foregroundStyle(.secondary) }
            switch question.kind {
            case .likert(let range, let labels):
                Picker(question.prompt, selection: Binding(get: { if case .number(let n)? = answer { n } else { -1 } },
                                                           set: { answer = .number($0) })) {
                    ForEach(Array(range), id: \.self) { n in Text(labels.indices.contains(n - range.lowerBound) ? labels[n - range.lowerBound] : "\(n)").tag(n) }
                }
                .pickerStyle(.segmented)
            case .scale(let options), .singleChoice(let options):
                Picker(question.prompt, selection: Binding(get: { if case .option(let i)? = answer { i } else { -1 } },
                                                           set: { answer = .option($0) })) {
                    ForEach(options.indices, id: \.self) { Text(options[$0]).tag($0) }
                }
                .pickerStyle(.segmented)
            case .multiSelect(let options):
                ForEach(options.indices, id: \.self) { i in
                    Toggle(options[i], isOn: Binding(
                        get: { if case .options(let s)? = answer { s.contains(i) } else { false } },
                        set: { on in
                            var s: Set<Int> = { if case .options(let x)? = answer { x } else { [] } }()
                            if on { s.insert(i) } else { s.remove(i) }
                            answer = .options(s)
                        }))
                }
            case .yesNo:
                Picker(question.prompt, selection: Binding(get: { if case .yes(let b)? = answer { b ? 1 : 0 } else { -1 } },
                                                           set: { answer = .yes($0 == 1) })) {
                    Text("Yes").tag(1); Text("No").tag(0)
                }
                .pickerStyle(.segmented)
            case .numeric(let range, let step, let unit):
                let value = { if case .number(let n)? = answer { n } else { -1 } }()
                HStack {
                    Stepper(value < 0 ? "Not answered" : "\(value) \(unit)",
                            onIncrement: { answer = .number(min(range.upperBound, max(range.lowerBound, value < 0 ? range.lowerBound + step * 8 : value + step))) },
                            onDecrement: { answer = .number(max(range.lowerBound, (value < 0 ? range.lowerBound + step * 8 : value) - step)) })
                    if value >= 0 { Button("Clear") { answer = nil }.buttonStyle(.borderless) }
                }
            }
            Text("\(question.id) · \(kindName)\(question.optional ? " · optional" : "")").font(.caption2.monospaced()).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var kindName: String {
        switch question.kind {
        case .likert: "likert"
        case .scale: "scale"
        case .multiSelect: "multiSelect"
        case .singleChoice: "singleChoice"
        case .yesNo: "yesNo"
        case .numeric: "numeric"
        }
    }
}

private struct LabQuestionPreview: View {
    let question: Question
    @State private var a: Answer?
    var body: some View { LabQuestionView(question: question, answer: $a) }
}

// MARK: - Messages

struct MessagesPage: View {
    let lab: BackendLab

    var body: some View {
        @Bindable var planner = lab.planner
        List {
            Section {
                Toggle("Show a notification when one is sent", isOn: $planner.notifySimulatedSends)
            } footer: {
                Text("Nothing leaves the phone in the prototype. When a rule fires (shop skipped, heavier days), the message is stored as if sent, so the demo can show exactly what the contact would get.")
            }
            Section {
                if lab.planner.outbox.isEmpty { Text("No messages yet. Try demo day 50: Daily flow → Done on the prefilled check-in.").foregroundStyle(.secondary) }
                ForEach(lab.planner.outbox) { m in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("To \(m.contactName)").font(.headline)
                            Spacer()
                            Text("\(m.status.rawValue) · \(m.day.description)").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(m.kind.title).font(.caption).foregroundStyle(.secondary)
                        LabMessageRow(message: m, planner: lab.planner)
                    }
                }
            } header: {
                Text("planner.outbox (newest first)")
            } footer: {
                Text("Rules: only contacts who agreed, at most two a week, only 08–20 (later ones wait), never health words, never again after Cancel.")
            }
        }
        .navigationTitle("Messages to contacts")
    }
}

// MARK: - Screen time (bonus)

struct ScreenTimePage: View {
    let lab: BackendLab

    var body: some View {
        List {
            if let s = lab.tracking.snapshot?.screenTime {
                Section {
                    Text(s.headline).font(.headline)
                    LabeledContent("Day", value: s.day.description)
                    LabeledContent("Phone in bed, last 7 nights", value: "\(s.phoneInBedNights) of \(s.answeredNights) answered")
                } footer: {
                    Text("backend.tracking.snapshot?.screenTime: ScreenTimeSummary. Apple lets apps read Screen Time only with a special entitlement (Family Controls, not on a free team), so these numbers are the person's own answers.")
                }
                Section("Yesterday") { LabTrackedRow(value: s.hours) }
                Section("Hours a day, 28 days") { LabTrendChart(points: s.trend, usual: nil, unit: "h") }
                Section("Where it is used") {
                    Text("Wind-down: phone in bed on 3 of 7 nights makes \"leave the phone outside the bedroom\" the evening step.").font(.caption)
                    Text("Insights: after 5+ evenings with the phone in bed, shows how often the next night was shorter than usual.").font(.caption)
                    Text("Answer it under Questions and answers; Daily flow asks it in the morning when yesterday is missing.").font(.caption)
                }
            } else { Text("No data") }
        }
        .navigationTitle("Screen time")
    }
}

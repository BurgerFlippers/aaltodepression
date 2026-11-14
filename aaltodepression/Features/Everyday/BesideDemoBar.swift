import SwiftUI

/// A judging overlay of the actual backend. Visibility never changes data or planner state.
struct BesideDemoBar: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var details = false
    private var hasSignals: Bool {
        presentation.checkIn != nil || presentation.backend.tracking.activity?.stepsSoFar.value != nil || presentation.backend.tracking.sleep?.duration.value != nil
    }
    private var dayLabel: String {
        guard presentation.backend.planner.today != nil else { return "Loading your current plan" }
        guard hasSignals else { return "Current plan · provisional, limited data" }
        switch presentation.backend.planner.today?.capacity {
        case .low: return "Plan: a lighter day"
        case .good: return "Plan: room for a little more"
        default: return "Plan: an everyday pace"
        }
    }
    // Display positions summarize existing backend categories; no new health score is calculated.
    private var indicatorPosition: CGFloat? {
        if presentation.callCue != nil { return 0.95 }
        guard let capacity = presentation.backend.planner.today?.capacity else { return nil }
        switch capacity {
        case .good: return 0.08
        case .ok: return 0.40
        case .low: return 0.72
        }
    }
    var body: some View {
        let cue = presentation.callCue
        Button { details = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DEMOBAR · LIVE DATA").font(.caption2.bold()).tracking(0.6)
                        Text(cue.map { "A call from \($0) is suggested" } ?? dayLabel)
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: cue == nil ? "info.circle" : "phone.fill").font(.body)
                }
                GeometryReader { geometry in
                    Capsule()
                        .fill(LinearGradient(colors: [
                            Color(red: 0.77, green: 0.91, blue: 0.68),
                            Color(red: 0.95, green: 0.83, blue: 0.36),
                            Color(red: 0.91, green: 0.41, blue: 0.23),
                            Color(red: 0.49, green: 0.06, blue: 0.13)
                        ], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 10)
                        .frame(height: 20)
                    if let position = indicatorPosition {
                        Circle().fill(.white)
                            .overlay { Circle().strokeBorder(EverydayStyle.ink, style: StrokeStyle(lineWidth: 3, dash: hasSignals || cue != nil ? [] : [3, 2])) }
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                            .offset(x: (geometry.size.width - 20) * position)
                    }
                }.frame(height: 20)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: indicatorPosition)
                    .accessibilityHidden(true)
                HStack {
                    Text("More capacity")
                    Spacer()
                    Text("More support")
                }.font(.caption2).foregroundStyle(.secondary)
            }.foregroundStyle(EverydayStyle.ink).padding(.horizontal, 20).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EverydayStyle.paper)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).overlay(alignment: .bottom) { Divider() }
            .sheet(isPresented: $details) { BesideLiveSignalsView() }
    }

}

struct BesideLiveSignalsView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("1 · Actual inputs") {
                    LabeledContent("Check-in", value: presentation.checkIn == nil ? "Not answered today" : "Answered today")
                    if let checkIn = presentation.checkIn {
                        LabeledContent("Energy", value: checkIn.energy.title)
                    }
                    LabeledContent("iPhone steps", value: presentation.backend.tracking.activity?.stepsSoFar.text ?? "Not available")
                    LabeledContent("Recorded sleep", value: presentation.backend.tracking.sleep?.duration.text ?? "Not available")
                }
                Section("2 · Backend day plan") {
                    Text(presentation.backend.planner.today?.headline ?? "Waiting for the planner")
                    Text("The gradient marker shows the current backend plan capacity and call suggestions. Without a check-in or sensor readings, the dashed marker shows the provisional plan based on limited data.").font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Things marked done", value: "\(presentation.winCount)")
                }
                Section {
                    if let person = presentation.callCue {
                        Label("A call from \(person) is suggested", systemImage: "phone.fill")
                    } else { Text("No call suggestion from the backend right now.") }
                    let agreed = presentation.backend.planner.setup.contacts.filter { $0.agreed && $0.canHelpWith.contains(.call) }
                    LabeledContent("Agreed contacts for calls", value: "\(agreed.count)")
                    if agreed.isEmpty { Text("No contact has been agreed for call suggestions. This does not mean support is unnecessary.").font(.footnote).foregroundStyle(.secondary) }
                } header: { Text("3 · Contact suggestion") } footer: { Text("This overlay explains the real data flow to judges. It does not generate sample data. The current backend records support requests locally; it does not place calls or send automatic messages.") }
            }.navigationTitle("Live data flow").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct BesideWinsView: View {
    @Environment(BesidePresentation.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedback = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(EverydayStyle.mint).frame(width: 52, height: 52)
                Image(systemName: "heart.fill").font(.title2).foregroundStyle(EverydayStyle.ink)
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : presentation.winCount)
            }.scaleEffect(presentation.winCount > 0 ? 1 : 0.8)
            VStack(alignment: .leading, spacing: 6) {
                Text("Small steps count.").font(.headline)
                HStack(spacing: 5) {
                    ForEach(0..<min(presentation.winCount, 8), id: \.self) { index in
                        Capsule().fill(EverydayStyle.color(EverydayTaskKind.allCases[index % 4]))
                            .frame(width: 22, height: 8).transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                }.accessibilityLabel("\(presentation.winCount) things done today")
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: presentation.winCount)
            .sensoryFeedback(.success, trigger: feedback)
            .onChange(of: presentation.winCount) { old, new in if new > old { feedback.toggle() } }
    }
}

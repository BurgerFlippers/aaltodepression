import SwiftUI

/// One short, calm flow: the plan arrives, then access to Health. The nurse has already explained.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            if page == 0 { planArrived } else { access }
            Spacer()
            buttons
        }
        .padding(24)
        .animation(.default, value: page)
    }

    private var planArrived: some View {
        VStack(alignment: .leading, spacing: 20) {
            MiniStripes()
            Text("Hi \(model.plan.patientName). Your plan from \(model.plan.nurseName) is here.")
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Usual shows how your days compare with your own usual. On a normal day there's nothing to do.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Let Usual read your days")
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                row("Sleep, movement, heart and daylight from Apple Health", "heart.text.square")
                row("Whether you were still, walking or travelling", "figure.walk")
                row("Time at home and places visited, as numbers only", "house")
                row("How many calendar events and photos a day, never their content", "calendar")
            }
            .font(.body)
            Text("Everything is worked out on this phone.")
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ text: String, _ symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Palette.tint).frame(width: 28)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var buttons: some View {
        VStack(spacing: 12) {
            if page == 0 {
                Button { page = 1 } label: { Text("Continue").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Button {
                    working = true
                    Task {
                        await model.requestPermissions()
                        model.mode = .real
                        model.onboarded = true
                        await model.readEverything()
                    }
                } label: {
                    HStack { if working { ProgressView() }; Text("Allow access") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(working)
                Button {
                    model.mode = .demo
                    model.onboarded = true
                } label: { Text("Use demo data instead").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).controlSize(.large)
            }
        }
    }
}

/// The six stripe colours as a small mark.
struct MiniStripes: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(ScoreKind.allCases.enumerated()), id: \.offset) { i, kind in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Palette.stripe(kind))
                    .frame(width: [72, 58, 80, 66, 50, 76][i], height: 9)
            }
        }
        .accessibilityHidden(true)
    }
}

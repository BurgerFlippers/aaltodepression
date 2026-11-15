import SwiftUI

nonisolated enum EverydayStyle {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let paper = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceRaised = Color(uiColor: .tertiarySystemGroupedBackground)
    static let accent = Color(red: 0.76, green: 0.65, blue: 0.97)
    static let action = Color(red: 0.44, green: 0.28, blue: 0.70)
    static let orange = accent
    static let yellow = Color(red: 0.17, green: 0.14, blue: 0.23)
    static let blue = Color(red: 0.15, green: 0.15, blue: 0.23)
    static let lavender = Color(red: 0.22, green: 0.16, blue: 0.30)
    static let mint = Color(red: 0.19, green: 0.15, blue: 0.27)
    static let peach = Color(red: 0.18, green: 0.14, blue: 0.24)
    static func color(_ kind: EverydayTaskKind) -> Color {
        switch kind { case .food: peach; case .movement: mint; case .medication: lavender; case .sleep: yellow }
    }
}

struct EverydayPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(EverydayStyle.action, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

struct EverydayHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).font(.caption).foregroundStyle(EverydayStyle.muted)
            Text(title).font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true).foregroundStyle(EverydayStyle.ink)
        }
    }
}

/// The same Beside mark used on the Home Screen, without a separate mascot.
struct BesideLogoView: View {
    var body: some View {
        Image("BesideMark").resizable().scaledToFit().saturation(0).colorMultiply(EverydayStyle.accent)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct EverydayNotice: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(EverydayStyle.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(EverydayStyle.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Flat four-step scale from "your usual" to "more support". No gradients: each step is one solid colour.
struct BalanceScale: View {
    static let colors: [Color] = [
        Color(red: 0.55, green: 0.80, blue: 0.50), Color(red: 0.93, green: 0.78, blue: 0.30),
        Color(red: 0.90, green: 0.45, blue: 0.25), Color(red: 0.70, green: 0.16, blue: 0.22)
    ]
    /// Colour for a 0...100 balance value, matching the scale.
    static func color(for value: Double) -> Color {
        value >= 80 ? colors[0] : value >= 60 ? colors[1] : value >= 40 ? colors[2] : colors[3]
    }
    var body: some View {
        HStack(spacing: 3) { ForEach(0..<4, id: \.self) { Capsule().fill(Self.colors[$0]) } }.frame(height: 8)
    }
}

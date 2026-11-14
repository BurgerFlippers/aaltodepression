import SwiftUI

nonisolated enum EverydayStyle {
    static let ink = Color(red: 0.16, green: 0.17, blue: 0.27)
    static let muted = Color(red: 0.40, green: 0.40, blue: 0.45)
    static let paper = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let orange = Color(red: 0.96, green: 0.52, blue: 0.26)
    static let yellow = Color(red: 0.99, green: 0.81, blue: 0.35)
    static let lavender = Color(red: 0.81, green: 0.77, blue: 0.94)
    static let mint = Color(red: 0.72, green: 0.87, blue: 0.80)
    static let peach = Color(red: 1.0, green: 0.84, blue: 0.69)
    static func color(_ kind: EverydayTaskKind) -> Color {
        switch kind { case .food: peach; case .movement: mint; case .medication: lavender; case .sleep: yellow }
    }
}

struct EverydayPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(EverydayStyle.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct EverydayHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(EverydayStyle.muted)
            Text(title).font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true).foregroundStyle(EverydayStyle.ink)
        }
    }
}

/// The same Beside mark used on the Home Screen, without a separate mascot.
struct BesideLogoView: View {
    var body: some View {
        Image("BesideMark").resizable().scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct EverydayNotice: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(EverydayStyle.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }
}

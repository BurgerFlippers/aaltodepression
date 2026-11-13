import SwiftUI

/// Usual's colours. Each score owns one stripe colour; the colours also differ in lightness,
/// so they stay apart without colour vision. No red anywhere.
nonisolated enum Palette {
    static let tint = Color(light: 0x1F5E6B, dark: 0x7CC6D2)

    static func stripe(_ kind: ScoreKind) -> Color {
        switch kind {
        case .sleep: Color(light: 0x2F3C8F, dark: 0x8C9BF2)     // dark indigo
        case .rhythm: Color(light: 0x6E55B5, dark: 0xB7A3F0)    // violet
        case .movement: Color(light: 0x2D7D4F, dark: 0x6FCB93)  // green
        case .daylight: Color(light: 0xE9B21C, dark: 0xF4CF57)  // light amber
        case .places: Color(light: 0x14879A, dark: 0x5FCBDA)    // teal
        case .body: Color(light: 0x9A7247, dark: 0xD9B88E)      // sand
        }
    }

    /// Text colour that reads on the stripe colour.
    static func onStripe(_ kind: ScoreKind) -> Color {
        switch kind {
        case .daylight: Color(light: 0x2B2205, dark: 0x2B2205)
        default: Color(light: 0xFFFFFF, dark: 0x101418)
        }
    }

    static let ground = Color(uiColor: .systemBackground)
}

extension Color {
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable in $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

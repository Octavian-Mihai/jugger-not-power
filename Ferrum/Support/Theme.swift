import SwiftUI

enum ThemeKind: String, CaseIterable, Identifiable {
    case forge, chalk, volt
    var id: String { rawValue }
    var title: String {
        switch self { case .forge: return "Forge"; case .chalk: return "Chalk"; case .volt: return "Volt" }
    }
    var blurb: String {
        switch self {
        case .forge: return "Dark and bold, orange accent"
        case .chalk: return "Light and minimal"
        case .volt: return "High contrast, neon accent"
        }
    }
    var theme: Theme {
        switch self {
        case .forge: return Theme(kind: self, bg: Color(hex: 0x121214), card: Color(hex: 0x1D1D21), text: .white,
                                  secondary: Color(hex: 0x9A9AA3), accent: Color(hex: 0xFF6B1A), onAccent: .black,
                                  good: Color(hex: 0x3DDC84), warn: Color(hex: 0xFFC247), bad: Color(hex: 0xFF5A5F), dark: true)
        case .chalk: return Theme(kind: self, bg: Color(hex: 0xF5F4F0), card: .white, text: Color(hex: 0x1A1A1C),
                                  secondary: Color(hex: 0x6E6E75), accent: Color(hex: 0x1F3A5F), onAccent: .white,
                                  good: Color(hex: 0x1E9E5A), warn: Color(hex: 0xC98A00), bad: Color(hex: 0xD6403F), dark: false)
        case .volt: return Theme(kind: self, bg: .black, card: Color(hex: 0x16161A), text: .white,
                                 secondary: Color(hex: 0xB5B5BD), accent: Color(hex: 0xC6FF00), onAccent: .black,
                                 good: Color(hex: 0x00E5A0), warn: Color(hex: 0xFFD400), bad: Color(hex: 0xFF3B6B), dark: true)
        }
    }
}

struct Theme {
    let kind: ThemeKind
    let bg, card, text, secondary, accent, onAccent, good, warn, bad: Color
    let dark: Bool
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct ThemeKey: EnvironmentKey { static let defaultValue = ThemeKind.forge.theme }
extension EnvironmentValues {
    var theme: Theme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
}

struct CardStyle: ViewModifier {
    @Environment(\.theme) var t
    func body(content: Content) -> some View {
        content.padding(16).background(t.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// Shared press feedback: a small spring shrink and dim while held. The shrink is skipped under Reduce Motion.
struct PressFeedback: ViewModifier {
    let isPressed: Bool
    var scale: CGFloat = 0.97
    var dim: Double = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? scale : 1)
            .opacity(isPressed ? dim : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
    }
}

/// Digits roll to their new value instead of snapping. Skipped under Reduce Motion.
struct NumericChange<V: Equatable>: ViewModifier {
    let value: V
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(reduceMotion || !animated ? nil : .snappy(duration: 0.3), value: value)
    }
}

extension View {
    func numericChange<V: Equatable>(_ value: V, animated: Bool = true) -> some View {
        modifier(NumericChange(value: value, animated: animated))
    }

    func pressFeedback(_ isPressed: Bool, scale: CGFloat = 0.97, dim: Double = 0.8) -> some View {
        modifier(PressFeedback(isPressed: isPressed, scale: scale, dim: dim))
    }
}

/// For buttons whose label is already styled (chips, cards): press feedback only, no extra chrome.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.pressFeedback(configuration.isPressed, scale: scale, dim: 0.75)
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.theme) var t
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(prominent ? t.onAccent : t.accent)
            .background(prominent ? t.accent : t.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .pressFeedback(configuration.isPressed)
    }
}

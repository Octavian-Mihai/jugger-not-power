import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FerrumTheme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.075)
    static let surface = Color(red: 0.13, green: 0.13, blue: 0.135)
    static let elevated = Color(red: 0.18, green: 0.16, blue: 0.145)
    static let copper = Color(red: 0.76, green: 0.48, blue: 0.31)
    static let copperMuted = Color(red: 0.55, green: 0.36, blue: 0.24)
    static let iron = Color(red: 0.48, green: 0.49, blue: 0.51)
    static let textPrimary = Color(red: 0.94, green: 0.91, blue: 0.87)
    static let textSecondary = Color(red: 0.66, green: 0.63, blue: 0.58)
    static let danger = Color(red: 0.78, green: 0.32, blue: 0.28)
    static let success = Color(red: 0.48, green: 0.64, blue: 0.42)
    static let warning = Color(red: 0.82, green: 0.58, blue: 0.28)
}

struct FerrumScreen: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(FerrumTheme.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .tint(FerrumTheme.copper)
    }
}

extension View {
    func ferrumScreen() -> some View {
        modifier(FerrumScreen())
    }

    func keyboardDoneButton() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}

private struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
                .foregroundStyle(FerrumTheme.copper)
            }
        }
    }
}

struct FerrumCard<Content: View>: View {
    var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FerrumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FerrumTheme.elevated, lineWidth: 1)
        )
    }
}

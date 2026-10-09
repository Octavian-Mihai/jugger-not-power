import SwiftUI
import UIKit

extension View {
    /// Lets the keyboard be dismissed: a Done button above it, a toolbar Done, and drag-to-dismiss on scrolling.
    func keyboardDoneBar() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { Keyboard.hide() }.fontWeight(.semibold)
                }
            }
            .modifier(KeyboardDoneOverlay())
    }
}

extension View {
    /// Return key reads "Done" and closes the keyboard. For single-line text fields that aren't part of a chain.
    func doneOnSubmit() -> some View {
        self.submitLabel(.done).onSubmit { Keyboard.hide() }
    }
}

enum Keyboard {
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Floating "Done" pill that sits just above the keyboard whenever it is visible.
/// Decimal/number pads have no return key, so this guarantees a way to close them.
private struct KeyboardDoneOverlay: ViewModifier {
    @Environment(\.theme) private var t
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if visible {
                    Button { Keyboard.hide() } label: {
                        Label("Done", systemImage: "keyboard.chevron.compact.down")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .foregroundStyle(t.onAccent)
                            .background(t.accent, in: Capsule())
                            .shadow(radius: 6, y: 2)
                    }
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.15)) { visible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.15)) { visible = false }
            }
    }
}

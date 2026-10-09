import UIKit

/// Light feedback for the workout keypad. Honours the Settings toggle via `enabled`.
enum Haptics {
    nonisolated(unsafe) static var enabled = true

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    /// Reserved for real milestones: a finished workout.
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

import SwiftUI

/// One empty-state look for the whole app: an icon, a short title, one line of guidance, and an optional action.
/// `compact` is for spots inside a card (charts); the full version fills a screen section.
struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var compact = false
    var action: (() -> Void)? = nil
    @Environment(\.theme) private var t

    var body: some View {
        if compact {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(t.secondary.opacity(0.8))
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                if let message {
                    Text(message).font(.footnote).foregroundStyle(t.secondary).multilineTextAlignment(.center)
                }
                actionButton
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        } else {
            ContentUnavailableView {
                Label(title, systemImage: icon).foregroundStyle(t.text)
            } description: {
                if let message { Text(message).foregroundStyle(t.secondary) }
            } actions: {
                actionButton
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var actionButton: some View {
        if let actionTitle, let action {
            Button(actionTitle, action: action).font(.subheadline.weight(.semibold)).padding(.top, 2)
        }
    }
}

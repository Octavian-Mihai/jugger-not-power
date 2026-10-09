import Foundation

/// The typing rules of the workout keypad, kept free of UI so they can be tested.
public struct NumericEntry: Equatable, Sendable {
    public enum Kind: Sendable { case weight, reps }

    public let kind: Kind
    public private(set) var text: String
    /// While true the next key replaces the value instead of editing it.
    public private(set) var fresh: Bool

    public init(kind: Kind, initial: String) {
        self.kind = kind; self.text = initial; self.fresh = true
    }

    private var maxLength: Int { kind == .weight ? 7 : 3 }

    public mutating func digit(_ d: Character) {
        guard d.isNumber else { return }
        if fresh { text = String(d); fresh = false }
        else if text == "0" { text = String(d) }              // a lone zero gives way to the next digit
        else if text.count < maxLength { text.append(d) }
    }

    public mutating func point() {
        guard kind == .weight else { return }                  // reps are whole numbers
        if fresh { text = "0."; fresh = false }
        else if !text.contains(".") && text.count < maxLength { text = text.isEmpty ? "0." : text + "." }
    }

    /// Backspace edits what's there, so it also ends the replace-on-first-key behaviour.
    public mutating func backspace() {
        fresh = false
        if !text.isEmpty { text.removeLast() }
    }

    public var weightValue: Double { Double(text) ?? 0 }
    public var repsValue: Int { Int(text) ?? 0 }
}

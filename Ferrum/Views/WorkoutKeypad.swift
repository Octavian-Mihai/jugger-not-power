import SwiftUI
import FerrumCore

/// Which cell of a set the lifter is typing into, and the text typed so far.
@Observable
final class KeypadController {
    enum Field { case weight, reps }

    private(set) var current: LoggedSet?
    private(set) var field: Field = .weight
    private var entry = NumericEntry(kind: .weight, initial: "")

    /// Raw text for the active field (so "0." can exist while typing a decimal).
    var text: String { entry.text }
    var isActive: Bool { current != nil }

    func isEditing(_ set: LoggedSet, _ field: Field) -> Bool {
        current === set && self.field == field
    }

    func activate(_ set: LoggedSet, field: Field, store: Store) {
        current = set
        self.field = field
        switch field {
        case .weight:
            let v = store.display(set.weightKg)
            entry = NumericEntry(kind: .weight, initial: v == 0 ? "" : (v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)))
        case .reps:
            entry = NumericEntry(kind: .reps, initial: set.reps == 0 ? "" : String(set.reps))
        }
    }

    func deactivate() { current = nil }

    // MARK: typing

    func digit(_ d: Character, store: Store) { guard current != nil else { return }; entry.digit(d); commit(store: store) }
    func point(store: Store) { guard current != nil else { return }; entry.point(); commit(store: store) }
    func backspace(store: Store) { guard current != nil else { return }; entry.backspace(); commit(store: store) }

    private func commit(store: Store) {
        guard let set = current else { return }
        switch field {
        case .weight:
            set.weightKg = store.toKg(entry.weightValue)
            set.edited = true
        case .reps:
            set.reps = entry.repsValue
        }
    }

    /// What a row should show for this cell while it is being edited.
    func liveText(_ set: LoggedSet, _ field: Field) -> String? {
        isEditing(set, field) ? (entry.text.isEmpty ? "0" : entry.text) : nil
    }
}

private let rirColors: [Color] = [
    Color(hex: 0xE5484D), Color(hex: 0xF76B15), Color(hex: 0xD9A400),
    Color(hex: 0x30A46C), Color(hex: 0x12A594), Color(hex: 0x3E63DD),
]

struct WorkoutKeypad: View {
    let keypad: KeypadController
    let profile: Profile
    let onComplete: (LoggedSet) -> Void
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var showRIRInfo = false

    private var set: LoggedSet? { keypad.current }
    private var isWeight: Bool { keypad.field == .weight }
    private var keyFill: Color { t.secondary.opacity(0.22) }
    private var onAccent: Color { t.kind == .volt ? .black : .white }

    private var equipment: String? {
        guard let id = set?.exerciseID else { return nil }
        return store.library.exercise(id)?.equipment
    }
    private var showPlates: Bool {
        guard isWeight, let e = equipment else { return false }
        return ["barbell", "trap bar", "safety bar", "smith machine", "landmine"].contains(e)
    }
    private var hasBarStepper: Bool { ["barbell", "trap bar", "safety bar"].contains(equipment ?? "") }

    var body: some View {
        VStack(spacing: 8) {
            if showPlates { plateStrip }
            if !isWeight { rirRow }
            padGrid
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            t.card.ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) { Rectangle().fill(t.secondary.opacity(0.3)).frame(height: 0.5) }
        .sheet(isPresented: $showRIRInfo) { RIRInfoSheet() }
    }

    // MARK: plate strip

    /// 20 kg shows as 20; the same bar in pounds shows as 45 (rounded to a loadable number).
    private var barDisplay: Double {
        let v = store.display(profile.barKg)
        return store.unit == .kg ? (v * 2).rounded() / 2 : (v / 5).rounded() * 5
    }

    private var plateStrip: some View {
        let total = Double(keypad.text) ?? 0
        let b = PlateMath.breakdown(total: total, bar: barDisplay, unit: store.unit)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(b.headline).font(.subheadline.weight(.semibold)).foregroundStyle(t.text).lineLimit(1).minimumScaleFactor(0.7)
                if let rem = b.remainderText {
                    Text("\(rem) \(store.unit.label)").font(.caption2).foregroundStyle(t.secondary)
                }
            }
            Spacer(minLength: 4)
            if hasBarStepper {
                HStack(spacing: 8) {
                    roundButton("minus") { adjustBar(-1) }
                    Text("Bar \(PlateMath.format(barDisplay))").font(.footnote.weight(.semibold)).foregroundStyle(t.text)
                        .monospacedDigit().lineLimit(1).fixedSize()
                    roundButton("plus") { adjustBar(1) }
                }
            }
        }
        .frame(minHeight: 34)
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.light(); action() } label: {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(t.text)
                .frame(width: 28, height: 28).background(keyFill, in: Circle())
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(icon == "plus" ? "Increase bar weight" : "Decrease bar weight")
    }

    private func adjustBar(_ dir: Double) {
        let step = store.unit == .kg ? 5.0 : 10.0
        let next = max(step, barDisplay + dir * step)
        profile.barKg = store.toKg(next)
    }

    // MARK: RIR row

    private var rirRow: some View {
        HStack(spacing: 6) {
            Button { Haptics.light(); showRIRInfo = true } label: {
                HStack(spacing: 3) {
                    Text("RIR").font(.footnote.weight(.bold)).lineLimit(1).fixedSize()
                    Image(systemName: "info.circle").font(.caption2)
                }
                .foregroundStyle(t.text).padding(.horizontal, 8).frame(height: 36).fixedSize(horizontal: true, vertical: false)
                .background(keyFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(KeyPressStyle())
            .accessibilityLabel("What is RIR?")
            ForEach(0..<6, id: \.self) { n in
                let selected = Int(min(set?.rir ?? 0, 5)) == n
                Button {
                    Haptics.selection()
                    set?.rir = Double(n)
                } label: {
                    Text("\(n)").font(.headline).frame(maxWidth: .infinity).frame(height: 36)
                        .foregroundStyle(selected ? Color.white : t.text)
                        .background(selected ? rirColors[n] : keyFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(KeyPressStyle())
                .accessibilityLabel("RIR \(n)\(n == 5 ? " or more" : "")")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: pad grid

    private var padGrid: some View {
        GeometryReader { geo in
            let gap: CGFloat = 6
            let usable = geo.size.width - gap
            let leftW = usable * 0.75
            let rightW = usable * 0.25
            HStack(alignment: .top, spacing: gap) {
                numberPad.frame(width: leftW)
                VStack(spacing: gap) { dismissKey; primaryKey }.frame(width: rightW)
            }
        }
        .frame(height: 4 * 50 + 3 * 6)
    }

    private var numberPad: some View {
        VStack(spacing: 6) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                HStack(spacing: 6) { ForEach(row, id: \.self) { digitKey($0) } }
            }
            HStack(spacing: 6) {
                if isWeight {
                    keyButton(fill: keyFill, action: { keypad.point(store: store) }) {
                        Text(".").font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(t.text)
                    }
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                }
                digitKey("0")
                backspaceKey
            }
        }
    }

    private func digitKey(_ d: String) -> some View {
        keyButton(fill: keyFill, action: { keypad.digit(Character(d), store: store) }) {
            Text(d).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(t.text)
        }
    }

    private var backspaceKey: some View {
        Button {
            Haptics.light()
            keypad.backspace(store: store)
        } label: {
            Image(systemName: "delete.left").font(.system(size: 14, weight: .semibold)).foregroundStyle(t.text)
                .frame(width: 34, height: 26)
                .background(keyFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("Delete")
    }

    private var dismissKey: some View {
        keyButton(fill: keyFill, height: 106, action: { keypad.deactivate() }) {
            Text("Dismiss Keyboard").font(.footnote.weight(.semibold)).foregroundStyle(t.text)
                .multilineTextAlignment(.center).minimumScaleFactor(0.7).lineLimit(2)
        }
    }

    private var primaryKey: some View {
        let editing = set?.isDone == true
        let title = isWeight ? "Next" : (editing ? "Save" : "Complete Set")
        return keyButton(fill: t.accent, height: 106, silent: !isWeight, action: {
            guard let current = set else { return }
            if isWeight {
                keypad.activate(current, field: .reps, store: store)
            } else if editing {
                keypad.deactivate()
            } else {
                onComplete(current)
            }
        }) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(onAccent)
                .multilineTextAlignment(.center).minimumScaleFactor(0.7).lineLimit(2)
        }
    }

    private func keyButton<Label: View>(fill: Color, height: CGFloat = 50, silent: Bool = false,
                                        action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button {
            if !silent { Haptics.light() }
            action()
        } label: {
            label()
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background(fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(KeyPressStyle())
    }
}

/// Keys shrink slightly and dim while held (the shrink is skipped under Reduce Motion).
struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.pressFeedback(configuration.isPressed, scale: 0.94, dim: 0.7)
    }
}

struct RIRInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.library.rirGuide, id: \.title) { level in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(level.title).font(.headline).foregroundStyle(t.accent)
                            Text(level.body).foregroundStyle(t.text)
                        }.frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                }.padding(16)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Reps in reserve").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

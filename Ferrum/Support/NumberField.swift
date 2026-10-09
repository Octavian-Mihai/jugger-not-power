import SwiftUI

/// Numeric text field that keeps its own text while editing, so typing never gets reformatted mid-entry.
/// A value of 0 shows as empty (placeholder).
struct NumberField: View {
    @Binding var value: Double
    var placeholder = "0"
    var decimals = true
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .focused($focused)
            .onAppear { text = format(value) }
            .onChange(of: text) { _, new in
                let cleaned = new.replacingOccurrences(of: ",", with: ".")
                value = Double(cleaned) ?? 0
            }
            .onChange(of: value) { _, new in
                if !focused { text = format(new) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = format(value) }
            }
    }

    private func format(_ v: Double) -> String {
        guard v != 0 else { return "" }
        return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

extension Binding where Value == Int {
    var asDouble: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0.rounded()) })
    }
}

import SwiftUI
import SwiftData
import FerrumCore

struct ReadinessSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    @State private var input = ReadinessInput()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    slider("Sleep", $input.sleep, low: "Poor", high: "Great", icon: "bed.double.fill")
                    slider("Energy", $input.energy, low: "Drained", high: "Charged", icon: "bolt.fill")
                    slider("Mood", $input.mood, low: "Low", high: "Great", icon: "face.smiling")
                    slider("Soreness", $input.soreness, low: "None", high: "Very sore", icon: "figure.walk")
                    let adj = Readiness.adjustment(for: input)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(adj.score)").font(.system(size: 40, weight: .black)).foregroundStyle(t.accent)
                            Text(adj.band.title).font(.title3.bold()).foregroundStyle(t.text)
                        }
                        Text(adj.summary).foregroundStyle(t.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).card()
                    Button("Save check-in") {
                        context.insert(ReadinessEntry(input: input)); dismiss()
                    }.buttonStyle(PrimaryButton())
                }.padding(16)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Readiness")
            .keyboardDoneBar()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func slider(_ title: String, _ value: Binding<Int>, low: String, high: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(t.text)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    Button { value.wrappedValue = n } label: {
                        Text("\(n)").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(value.wrappedValue == n ? t.onAccent : t.text)
                            .background(value.wrappedValue == n ? t.accent : t.card, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            HStack { Text(low); Spacer(); Text(high) }.font(.caption).foregroundStyle(t.secondary)
        }
    }
}

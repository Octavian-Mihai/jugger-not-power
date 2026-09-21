import SwiftUI
import SwiftData
import TrainingLogic

struct ReadinessView: View {
    @Bindable var user: User
    @Bindable var day: WorkoutDay
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ReadinessViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreHeader
                stepper("Sleep", value: $model.sleep, inverted: false)
                stepper("Energy", value: $model.energy, inverted: false)
                stepper("Motivation", value: $model.motivation, inverted: false)
                stepper("Soreness", value: $model.soreness, inverted: true)
                stepper("Stress", value: $model.stress, inverted: true)

                FerrumCard {
                    Text("Why this score")
                        .font(.headline)
                        .foregroundStyle(FerrumTheme.textPrimary)
                    Text(model.preview.reasoning)
                        .foregroundStyle(FerrumTheme.textSecondary)
                    ForEach(model.preview.changes, id: \.self) { change in
                        Text("• \(change)")
                            .foregroundStyle(FerrumTheme.copper)
                    }
                }

                Button("Apply to today's session") {
                    do {
                        try ProgramService(context: context).applyReadiness(
                            model.preview,
                            input: model.input,
                            to: day,
                            user: user
                        )
                        dismiss()
                    } catch {
                        model.errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(CopperButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Readiness")
        .ferrumScreen()
        .onAppear {
            model.load(from: ProgramService(context: context).checkIn(for: user, on: day.scheduledDate))
        }
        .alert("Could not apply readiness", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var scoreHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Int(model.preview.score.rounded()))")
                .font(.system(size: 64, weight: .semibold, design: .serif))
                .foregroundStyle(FerrumTheme.copper)
            Text(model.preview.band.displayName.uppercased())
                .tracking(2)
                .foregroundStyle(FerrumTheme.textSecondary)
        }
    }

    private func stepper(_ title: String, value: Binding<Int>, inverted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).foregroundStyle(FerrumTheme.textPrimary)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(inverted && value.wrappedValue >= 4 ? FerrumTheme.warning : FerrumTheme.copper)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    Button {
                        value.wrappedValue = score
                    } label: {
                        Circle()
                            .fill(score <= value.wrappedValue ? FerrumTheme.copper : FerrumTheme.surface)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text("\(score)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(score <= value.wrappedValue ? FerrumTheme.background : FerrumTheme.textSecondary)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(FerrumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

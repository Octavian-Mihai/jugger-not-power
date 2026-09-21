import SwiftUI
import SwiftData
import TrainingLogic

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var model = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FERRUM")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(FerrumTheme.copper)
                    .tracking(4)
                Spacer()
                Text("\(model.page + 1)/5")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(FerrumTheme.textSecondary)
            }
            .padding()

            TabView(selection: $model.page) {
                modePage.tag(0)
                experiencePage.tag(1)
                bodyweightPage.tag(2)
                prPage.tag(3)
                generatePage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                if model.page > 0 {
                    Button("Back") { model.page -= 1 }
                        .foregroundStyle(FerrumTheme.textSecondary)
                }
                Spacer()
                Button(model.page == 4 ? "Forge Program" : "Continue") {
                    if model.page < 4 {
                        model.page += 1
                    } else {
                        do {
                            try model.finish(context: context)
                        } catch {
                            model.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(CopperButtonStyle())
                .disabled(!model.canAdvance || model.isGenerating)
            }
            .padding()
        }
        .ferrumScreen()
        .keyboardDoneButton()
        .alert("Could not generate", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var modePage: some View {
        onboardingCard(title: "Choose your mode", subtitle: "The split and emphasis follow this choice.") {
            ForEach(TrainingMode.allCases, id: \.self) { mode in
                selectableRow(
                    title: mode.displayName,
                    detail: mode.summary,
                    selected: model.trainingMode == mode
                ) { model.trainingMode = mode }
            }
        }
    }

    private var experiencePage: some View {
        onboardingCard(title: "Experience", subtitle: "Volume landmarks scale from MEV toward MRV.") {
            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                selectableRow(
                    title: level.rawValue.capitalized,
                    detail: level.detail,
                    selected: model.experienceLevel == level
                ) { model.experienceLevel = level }
            }
        }
    }

    private var bodyweightPage: some View {
        onboardingCard(title: "Bodyweight", subtitle: "Stored in kilograms. Display units can change later.") {
            Picker("Unit", selection: $model.unit) {
                Text("kg").tag(WeightUnit.kilogram)
                Text("lb").tag(WeightUnit.pound)
            }
            .pickerStyle(.segmented)

            HStack {
                TextField("Bodyweight", value: $model.bodyweight, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.largeTitle.monospacedDigit().weight(.medium))
                    .foregroundStyle(FerrumTheme.textPrimary)
                Text(model.unit == .kilogram ? "kg" : "lb")
                    .foregroundStyle(FerrumTheme.copper)
            }
        }
    }

    private var prPage: some View {
        onboardingCard(title: "Competition PRs", subtitle: "Optional. Missing lifts use conservative bodyweight estimates.") {
            prField("Squat", text: $model.squatPR)
            prField("Bench", text: $model.benchPR)
            prField("Deadlift", text: $model.deadliftPR)
            prField("Overhead press", text: $model.ohpPR)
        }
    }

    private var generatePage: some View {
        onboardingCard(title: "12-week mesocycle", subtitle: "Hypertrophy, strength, then peaking — balanced offline.") {
            summaryRow("Mode", model.trainingMode.displayName)
            summaryRow("Experience", model.experienceLevel.rawValue.capitalized)
            summaryRow("Bodyweight", String(format: "%.1f %@", model.bodyweight, model.unit == .kilogram ? "kg" : "lb"))
            Text("A local ProgramEngine will write your weeks, then VolumeBalancer will enforce pull ≥ push and posterior-chain floors.")
                .font(.footnote)
                .foregroundStyle(FerrumTheme.textSecondary)
        }
    }

    private func onboardingCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(FerrumTheme.textPrimary)
                Text(subtitle)
                    .foregroundStyle(FerrumTheme.textSecondary)
                content()
            }
            .padding(24)
        }
    }

    private func selectableRow(title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(FerrumTheme.textPrimary)
                Text(detail).font(.footnote).foregroundStyle(FerrumTheme.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? FerrumTheme.elevated : FerrumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? FerrumTheme.copper : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func prField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).foregroundStyle(FerrumTheme.textPrimary)
            Spacer()
            TextField("skip", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(FerrumTheme.copper)
            Text(model.unit == .kilogram ? "kg" : "lb")
                .foregroundStyle(FerrumTheme.textSecondary)
        }
        .padding()
        .background(FerrumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(FerrumTheme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(FerrumTheme.textPrimary)
        }
    }
}

struct CopperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundStyle(FerrumTheme.background)
            .background(FerrumTheme.copper.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(Capsule())
    }
}

private extension ExperienceLevel {
    var detail: String {
        switch self {
        case .novice: return "Volume stays near MEV"
        case .intermediate: return "Volume targets MAV"
        case .advanced: return "Volume leans toward MRV"
        }
    }
}

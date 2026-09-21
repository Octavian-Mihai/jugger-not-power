import SwiftUI
import SwiftData
import TrainingLogic
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var user: User
    @Environment(\.modelContext) private var context
    @State private var confirmRegenerate = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @State private var squatPR: String = ""
    @State private var benchPR: String = ""
    @State private var deadliftPR: String = ""
    @State private var ohpPR: String = ""
    @State private var bodyweightDisplay: Double = 80

    var body: some View {
        NavigationStack {
            List {
                Section("Units") {
                    Picker("Display unit", selection: $user.preferredUnit) {
                        Text("Kilograms").tag(WeightUnit.kilogram)
                        Text("Pounds").tag(WeightUnit.pound)
                    }
                    .tint(FerrumTheme.copper)
                    .onChange(of: user.preferredUnit) { _, _ in
                        syncProfileFields()
                    }
                }

                Section("Athlete") {
                    Picker("Mode", selection: $user.trainingMode) {
                        ForEach(TrainingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Picker("Experience", selection: $user.experienceLevel) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    HStack {
                        Text("Bodyweight")
                        Spacer()
                        TextField("Bodyweight", value: $bodyweightDisplay, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(FerrumTheme.copper)
                            .onChange(of: bodyweightDisplay) { _, value in
                                user.bodyweightKg = UnitConverter.kilograms(fromDisplay: value, unit: user.preferredUnit)
                            }
                        Text(user.preferredUnit == .kilogram ? "kg" : "lb")
                            .foregroundStyle(FerrumTheme.textSecondary)
                    }
                }

                Section("Competition PRs") {
                    prRow("Squat", text: $squatPR) { user.squatPR = parsedPR($0) }
                    prRow("Bench", text: $benchPR) { user.benchPR = parsedPR($0) }
                    prRow("Deadlift", text: $deadliftPR) { user.deadliftPR = parsedPR($0) }
                    prRow("Overhead press", text: $ohpPR) { user.ohpPR = parsedPR($0) }
                }

                Section("Data") {
                    ShareLink(
                        item: CSVFile(text: CSVExportService.export(user: user)),
                        preview: SharePreview("Ferrum export", image: Image(systemName: "square.and.arrow.up"))
                    ) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    Button("Regenerate program") { confirmRegenerate = true }
                    Button("Delete local data", role: .destructive) { confirmDelete = true }
                }

                Section {
                    Text("Regenerate after changing mode, experience, bodyweight, or PRs so the 12-week plan is rebuilt from the updated profile. Ferrum is fully offline.")
                        .font(.footnote)
                        .foregroundStyle(FerrumTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .ferrumScreen()
            .keyboardDoneButton()
            .onAppear { syncProfileFields() }
            .confirmationDialog("Replace the current 12-week program?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
                Button("Regenerate", role: .destructive) {
                    do {
                        persistProfileFields()
                        try ProgramService(context: context).generateAndPersist(for: user)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .confirmationDialog("Delete all local Ferrum data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    do {
                        try ProgramService(context: context).deleteAllData()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func prRow(_ title: String, text: Binding<String>, onChange: @escaping (String) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("skip", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(FerrumTheme.copper)
                .onChange(of: text.wrappedValue) { _, value in
                    onChange(value)
                }
            Text(user.preferredUnit == .kilogram ? "kg" : "lb")
                .foregroundStyle(FerrumTheme.textSecondary)
        }
    }

    private func parsedPR(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return UnitConverter.kilograms(fromDisplay: value, unit: user.preferredUnit)
    }

    private func syncProfileFields() {
        bodyweightDisplay = UnitConverter.display(fromKilograms: user.bodyweightKg, unit: user.preferredUnit)
        squatPR = compactPR(user.squatPR)
        benchPR = compactPR(user.benchPR)
        deadliftPR = compactPR(user.deadliftPR)
        ohpPR = compactPR(user.ohpPR)
    }

    private func persistProfileFields() {
        user.bodyweightKg = UnitConverter.kilograms(fromDisplay: bodyweightDisplay, unit: user.preferredUnit)
        user.squatPR = parsedPR(squatPR)
        user.benchPR = parsedPR(benchPR)
        user.deadliftPR = parsedPR(deadliftPR)
        user.ohpPR = parsedPR(ohpPR)
    }

    private func compactPR(_ kg: Double?) -> String {
        guard let kg else { return "" }
        return UnitConverter.compact(kg, unit: user.preferredUnit)
    }
}

struct CSVFile: Identifiable, Hashable {
    var id = UUID()
    var text: String
}

extension CSVFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(file.text.utf8)
        }
        .suggestedFileName("ferrum-export.csv")
    }
}

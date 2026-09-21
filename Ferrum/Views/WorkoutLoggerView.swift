import SwiftUI
import SwiftData
import TrainingLogic

struct WorkoutLoggerView: View {
    @Bindable var user: User
    @Binding var focusedDayID: PersistentIdentifier?
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var timer: RestTimer
    @StateObject private var model = WorkoutLoggerViewModel()
    @State private var selectedDayID: PersistentIdentifier?
    @State private var substituting: Exercise?

    private var service: ProgramService { ProgramService(context: context) }

    private var days: [WorkoutDay] {
        user.activeProgram?.orderedWeeks.flatMap(\.orderedDays) ?? []
    }

    private var selectedDay: WorkoutDay? {
        if let selectedDayID, let match = days.first(where: { $0.persistentModelID == selectedDayID }) {
            return match
        }
        return service.todaysWorkout(for: user) ?? days.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if days.isEmpty {
                    ContentUnavailableView("No program", systemImage: "list.clipboard", description: Text("Generate a program from onboarding or Settings."))
                        .foregroundStyle(FerrumTheme.textSecondary)
                } else {
                    dayPicker
                    if let day = selectedDay {
                        if day.isRestDay {
                            restState(day)
                        } else {
                            sessionList(day)
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .ferrumScreen()
            .toolbar {
                if let day = selectedDay, !day.isRestDay, !day.isCompleted {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Session") {
                            Button("Skip session") {
                                do { try service.skip(day) } catch { model.errorMessage = error.localizedDescription }
                            }
                            Button("Postpone session") {
                                do { try service.postpone(day) } catch { model.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }
            }
            .onAppear { resolveSelection() }
            .onChange(of: focusedDayID) { _, _ in resolveSelection() }
            .onChange(of: selectedDay?.nextIncompleteSet?.1.persistentModelID) { _, _ in
                model.syncCurrentSet(selectedDay?.nextIncompleteSet?.1, unit: user.preferredUnit)
            }
            .alert("Could not save", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .sheet(item: $substituting) { exercise in
                ExerciseSubstituteSheet(exercise: exercise, user: user)
            }
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(days, id: \.persistentModelID) { day in
                    Button {
                        selectedDayID = day.persistentModelID
                        focusedDayID = day.persistentModelID
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("W\(day.week?.weekNumber ?? 0)")
                                .font(.caption2)
                            Text(day.isRestDay ? "Rest" : day.title)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedDay?.persistentModelID == day.persistentModelID ? FerrumTheme.copper : FerrumTheme.surface)
                        .foregroundStyle(selectedDay?.persistentModelID == day.persistentModelID ? FerrumTheme.background : (day.isRestDay ? FerrumTheme.textSecondary : FerrumTheme.textPrimary))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func restState(_ day: WorkoutDay) -> some View {
        ContentUnavailableView(
            "Rest day",
            systemImage: "moon.zzz",
            description: Text("Scheduled \(day.scheduledDate.formatted(date: .abbreviated, time: .omitted)). Use Postpone on a training day to move it here.")
        )
        .foregroundStyle(FerrumTheme.textSecondary)
    }

    private func sessionList(_ day: WorkoutDay) -> some View {
        let currentID = day.nextIncompleteSet?.1.persistentModelID
        return List {
            ForEach(day.orderedExercises, id: \.persistentModelID) { exercise in
                Section {
                    ForEach(exercise.orderedSets, id: \.persistentModelID) { set in
                        setRow(exercise: exercise, set: set, isCurrent: set.persistentModelID == currentID)
                    }
                } header: {
                    HStack {
                        Text(exercise.name)
                            .foregroundStyle(FerrumTheme.copper)
                        Spacer()
                        if !ExerciseLibrary.substitutes(for: exercise.catalogID).isEmpty {
                            Button("Swap") { substituting = exercise }
                                .font(.caption)
                                .foregroundStyle(FerrumTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .keyboardDoneButton()
    }

    private func setRow(exercise: Exercise, set: SetLog, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.isWarmup ? "Warm-up \(set.setIndex + 1)" : "Set \(workingIndex(of: set, in: exercise))")
                    .foregroundStyle(set.isWarmup ? FerrumTheme.textSecondary : FerrumTheme.textPrimary)
                Spacer()
                Text("Target \(set.targetReps) × \(UnitConverter.formatted(set.targetWeightKg, unit: user.preferredUnit)) @ \(String(format: "%g", set.targetRPE))")
                    .font(.caption)
                    .foregroundStyle(FerrumTheme.textSecondary)
            }
            if set.isCompleted {
                HStack {
                    Text("Logged \(set.actualReps ?? 0) × \(UnitConverter.formatted(set.actualWeightKg ?? 0, unit: user.preferredUnit)) @ RPE \(String(format: "%g", set.actualRPE ?? 0))")
                        .foregroundStyle(FerrumTheme.success)
                    Spacer()
                    Button("Undo") { model.undo(set: set, context: context) }
                        .font(.caption)
                        .foregroundStyle(FerrumTheme.copper)
                }
            } else if isCurrent {
                HStack {
                    field("Reps", text: $model.editingReps)
                    field(user.preferredUnit == .kilogram ? "kg" : "lb", text: $model.editingWeight)
                    field("RPE", text: $model.editingRPE)
                }
                Button("Complete set") {
                    model.complete(set: set, unit: user.preferredUnit, context: context, timer: timer)
                }
                .buttonStyle(CopperButtonStyle())
            } else {
                Text("Up next")
                    .font(.caption)
                    .foregroundStyle(FerrumTheme.textSecondary)
            }
        }
        .listRowBackground(FerrumTheme.surface)
    }

    private func workingIndex(of set: SetLog, in exercise: Exercise) -> Int {
        exercise.orderedSets.filter { !$0.isWarmup && $0.setIndex <= set.setIndex }.count
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption2).foregroundStyle(FerrumTheme.textSecondary)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .padding(8)
                .background(FerrumTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(FerrumTheme.textPrimary)
        }
    }

    private func resolveSelection() {
        if let focusedDayID, days.contains(where: { $0.persistentModelID == focusedDayID }) {
            selectedDayID = focusedDayID
        } else {
            selectedDayID = service.todaysWorkout(for: user)?.persistentModelID
        }
        model.syncCurrentSet(selectedDay?.nextIncompleteSet?.1, unit: user.preferredUnit)
    }
}

private struct ExerciseSubstituteSheet: View {
    var exercise: Exercise
    @Bindable var user: User
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    private var options: [ExerciseDefinition] {
        ExerciseLibrary.substitutes(for: exercise.catalogID)
    }

    var body: some View {
        NavigationStack {
            List(options, id: \.id) { definition in
                Button {
                    do {
                        try ProgramService(context: context).substitute(exercise, with: definition, user: user)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(definition.name)
                            .foregroundStyle(FerrumTheme.textPrimary)
                        Text(definition.primaryMuscles.map(\.rawValue).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(FerrumTheme.textSecondary)
                    }
                }
                .listRowBackground(FerrumTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Substitute")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .ferrumScreen()
            .alert("Could not substitute", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

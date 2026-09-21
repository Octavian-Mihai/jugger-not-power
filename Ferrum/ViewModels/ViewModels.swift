import Combine
import Foundation
import SwiftData
import SwiftUI
import TrainingLogic

enum FerrumTab: Hashable {
    case today
    case log
    case analytics
    case settings
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var page = 0
    @Published var trainingMode: TrainingMode = .powerbuilding
    @Published var experienceLevel: ExperienceLevel = .intermediate
    @Published var bodyweight: Double = 80
    @Published var unit: WeightUnit = .kilogram
    @Published var squatPR: String = ""
    @Published var benchPR: String = ""
    @Published var deadliftPR: String = ""
    @Published var ohpPR: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?

    var canAdvance: Bool {
        if page == 2 { return bodyweight > 0 }
        return true
    }

    func parsedPR(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return UnitConverter.kilograms(fromDisplay: value, unit: unit)
    }

    func finish(context: ModelContext) throws {
        isGenerating = true
        defer { isGenerating = false }
        let user = User(
            trainingMode: trainingMode,
            experienceLevel: experienceLevel,
            bodyweightKg: UnitConverter.kilograms(fromDisplay: bodyweight, unit: unit),
            preferredUnit: unit,
            squatPR: parsedPR(squatPR),
            benchPR: parsedPR(benchPR),
            deadliftPR: parsedPR(deadliftPR),
            ohpPR: parsedPR(ohpPR),
            hasCompletedOnboarding: true
        )
        context.insert(user)
        try ProgramService(context: context).generateAndPersist(for: user)
    }
}

@MainActor
final class ReadinessViewModel: ObservableObject {
    @Published var sleep = 3
    @Published var energy = 3
    @Published var motivation = 3
    @Published var soreness = 3
    @Published var stress = 3
    @Published var errorMessage: String?

    var input: ReadinessCheckInInput {
        ReadinessCheckInInput(sleep: sleep, energy: energy, motivation: motivation, soreness: soreness, stress: stress)
    }

    var preview: ReadinessResult {
        ReadinessEngine.evaluate(input)
    }

    func load(from checkIn: ReadinessCheckIn?) {
        guard let checkIn else { return }
        sleep = checkIn.sleep
        energy = checkIn.energy
        motivation = checkIn.motivation
        soreness = checkIn.soreness
        stress = checkIn.stress
    }
}

@MainActor
final class WorkoutLoggerViewModel: ObservableObject {
    @Published var editingReps: String = ""
    @Published var editingWeight: String = ""
    @Published var editingRPE: String = ""
    @Published var errorMessage: String?
    @Published private(set) var currentSetID: PersistentIdentifier?

    func seed(from set: SetLog, unit: WeightUnit) {
        currentSetID = set.persistentModelID
        editingReps = String(set.actualReps ?? set.targetReps)
        editingWeight = UnitConverter.compact(set.actualWeightKg ?? set.targetWeightKg, unit: unit)
        editingRPE = String(format: "%g", set.actualRPE ?? set.targetRPE)
    }

    func syncCurrentSet(_ set: SetLog?, unit: WeightUnit) {
        guard let set else {
            currentSetID = nil
            return
        }
        if currentSetID != set.persistentModelID {
            seed(from: set, unit: unit)
        }
    }

    func complete(set: SetLog, unit: WeightUnit, context: ModelContext, timer: RestTimer) {
        do {
            let reps = Int(editingReps) ?? set.targetReps
            let displayWeight = Double(editingWeight.replacingOccurrences(of: ",", with: "."))
                ?? UnitConverter.display(fromKilograms: set.targetWeightKg, unit: unit)
            let weightKg = UnitConverter.kilograms(fromDisplay: displayWeight, unit: unit)
            let rpe = Double(editingRPE.replacingOccurrences(of: ",", with: ".")) ?? set.targetRPE
            try ProgramService(context: context).completeSet(set, reps: reps, weightKg: weightKg, rpe: rpe)
            if let pattern = set.exercise?.movementPattern {
                timer.start(for: pattern)
            }
            currentSetID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undo(set: SetLog, context: ModelContext) {
        do {
            try ProgramService(context: context).undoSet(set)
            currentSetID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

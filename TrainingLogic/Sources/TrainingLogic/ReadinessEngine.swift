import Foundation

public struct ReadinessCheckInInput: Equatable, Sendable {
    public var sleep: Int
    public var energy: Int
    public var motivation: Int
    public var soreness: Int
    public var stress: Int

    public init(sleep: Int, energy: Int, motivation: Int, soreness: Int, stress: Int) {
        self.sleep = clamp(sleep)
        self.energy = clamp(energy)
        self.motivation = clamp(motivation)
        self.soreness = clamp(soreness)
        self.stress = clamp(stress)
    }
}

public struct ReadinessResult: Equatable, Sendable {
    public var score: Double
    public var band: ReadinessBand
    public var loadMultiplier: Double
    public var volumeMultiplier: Double
    public var replaceWithRecovery: Bool
    public var reasoning: String
    public var changes: [String]
}

public enum ReadinessEngine {
    public static func evaluate(
        sleep: Int,
        energy: Int,
        motivation: Int,
        soreness: Int,
        stress: Int
    ) -> ReadinessResult {
        evaluate(ReadinessCheckInInput(sleep: sleep, energy: energy, motivation: motivation, soreness: soreness, stress: stress))
    }

    public static func evaluate(_ input: ReadinessCheckInInput) -> ReadinessResult {
        let score = (Double(input.sleep) * 0.3
            + Double(input.energy) * 0.25
            + Double(input.motivation) * 0.2
            + Double(6 - input.soreness) * 0.15
            + Double(6 - input.stress) * 0.1) * 20.0
        let band = band(for: score)
        switch band {
        case .proceed:
            return ReadinessResult(
                score: score,
                band: band,
                loadMultiplier: 1.025,
                volumeMultiplier: 1.0,
                replaceWithRecovery: false,
                reasoning: "Readiness is high. Proceed with the planned session and optionally add a small load bump.",
                changes: ["Keep planned volume", "Optional +2.5% load on working sets"]
            )
        case .hold:
            return ReadinessResult(
                score: score,
                band: band,
                loadMultiplier: 1.0,
                volumeMultiplier: 1.0,
                replaceWithRecovery: false,
                reasoning: "Readiness is adequate. Hold today's loads and volume as written.",
                changes: ["No load change", "No volume change"]
            )
        case .cut:
            return ReadinessResult(
                score: score,
                band: band,
                loadMultiplier: 1.0,
                volumeMultiplier: 0.75,
                replaceWithRecovery: false,
                reasoning: "Readiness is reduced. Keep intensity, but drop the last accessory sets so volume falls 20–30%.",
                changes: ["Hold intensity", "Cut volume ~25% by dropping last accessory sets"]
            )
        case .deload:
            return ReadinessResult(
                score: score,
                band: band,
                loadMultiplier: 0.50,
                volumeMultiplier: 0.50,
                replaceWithRecovery: true,
                reasoning: "Readiness is too low for the planned session. Replace it with deload / active recovery: easy hinge, carry, and core.",
                changes: ["Replace session with active recovery", "Easy hinge, carry, and core only"]
            )
        }
    }

    public static func band(for score: Double) -> ReadinessBand {
        switch score {
        case 80...: return .proceed
        case 60..<80: return .hold
        case 40..<60: return .cut
        default: return .deload
        }
    }

    public static func recoveryWorkout(dayIndex: Int, profile: AthleteProfile) -> PlannedWorkout {
        let hinge = ExerciseLibrary.require("romanian_deadlift")
        let carry = ExerciseLibrary.require("farmers_carry")
        let core = ExerciseLibrary.require("plank")
        let extra = ExerciseLibrary.require("hanging_leg_raise")
        let hingeLoad = OneRepMax.workingLoadKg(for: hinge, profile: profile, percent1RM: 0.40)
        let carryLoad = OneRepMax.workingLoadKg(for: carry, profile: profile, percent1RM: 0.35)
        return PlannedWorkout(
            dayIndex: dayIndex,
            title: "Active Recovery",
            exercises: [
                makeRecoveryExercise(hinge, reps: 10, weight: hingeLoad, rpe: 5, sets: 3, role: .main, percent1RM: 0.40),
                makeRecoveryExercise(carry, reps: 12, weight: carryLoad, rpe: 5, sets: 3, role: .secondary, percent1RM: 0.35),
                makeRecoveryExercise(core, reps: 30, weight: 0, rpe: 5, sets: 3, role: .accessory, percent1RM: 0),
                makeRecoveryExercise(extra, reps: 8, weight: 0, rpe: 5, sets: 2, role: .accessory, percent1RM: 0)
            ]
        )
    }

    public static func apply(_ result: ReadinessResult, to workout: PlannedWorkout, profile: AthleteProfile) -> PlannedWorkout {
        if result.replaceWithRecovery {
            var recovery = recoveryWorkout(dayIndex: workout.dayIndex, profile: profile)
            recovery.id = workout.id
            return recovery
        }
        var adjusted = workout
        if result.volumeMultiplier < 1.0 {
            adjusted = cutAccessoryVolume(adjusted, multiplier: result.volumeMultiplier)
        }
        if result.loadMultiplier != 1.0 {
            for exerciseIndex in adjusted.exercises.indices {
                for setIndex in adjusted.exercises[exerciseIndex].sets.indices {
                    let current = adjusted.exercises[exerciseIndex].sets[setIndex].targetWeightKg
                    adjusted.exercises[exerciseIndex].sets[setIndex].targetWeightKg = OneRepMax.roundToPlate(
                        current * result.loadMultiplier,
                        unit: profile.preferredUnit
                    )
                }
            }
        }
        return adjusted
    }

    private static func cutAccessoryVolume(_ workout: PlannedWorkout, multiplier: Double) -> PlannedWorkout {
        var copy = workout
        let originalSets = copy.exercises.reduce(0) { $0 + $1.sets.count }
        let targetSets = max(1, Int((Double(originalSets) * multiplier).rounded()))
        var remainingToDrop = max(0, originalSets - targetSets)
        for index in copy.exercises.indices.reversed() {
            guard remainingToDrop > 0 else { break }
            let isMain = copy.exercises[index].role == .main
            let floor = isMain ? min(2, copy.exercises[index].sets.count) : 0
            while copy.exercises[index].sets.count > floor && remainingToDrop > 0 {
                copy.exercises[index].sets.removeLast()
                remainingToDrop -= 1
            }
            if copy.exercises[index].sets.isEmpty && copy.exercises[index].role == .accessory {
                copy.exercises.remove(at: index)
            }
        }
        return copy
    }

    private static func makeRecoveryExercise(
        _ definition: ExerciseDefinition,
        reps: Int,
        weight: Double,
        rpe: Double,
        sets: Int,
        role: ExerciseRole,
        percent1RM: Double?
    ) -> PlannedExercise {
        PlannedExercise(
            catalogID: definition.id,
            name: definition.name,
            movementPattern: definition.movementPattern,
            primaryMuscles: definition.primaryMuscles,
            role: role,
            sets: (0..<sets).map { _ in
                PlannedSet(targetReps: reps, targetWeightKg: weight, targetRPE: rpe, percent1RM: percent1RM)
            }
        )
    }
}

private func clamp(_ value: Int) -> Int {
    min(5, max(1, value))
}

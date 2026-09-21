import Foundation

public struct ProgressionAdjustment: Equatable, Sendable {
    public var catalogID: String
    public var loadMultiplier: Double
    public var nextSetCount: Int

    public init(catalogID: String, loadMultiplier: Double, nextSetCount: Int) {
        self.catalogID = catalogID
        self.loadMultiplier = loadMultiplier
        self.nextSetCount = nextSetCount
    }
}

public enum ProgressionEngine {
    public static let missedRPELoadCut = 0.95
    public static let easyRPELoadBump = 1.025
    public static let completedSmallBump = 1.01

    public static func estimated1RM(weight: Double, reps: Int) -> Double {
        OneRepMax.epley(weight: weight, reps: reps)
    }

    /// actual RPE ≥ target+1 → −5%; actual RPE ≤ target−1 → +2.5%; else small bump if all sets completed.
    public static func loadMultiplier(for sets: [CompletedSet]) -> Double {
        let working = sets.filter { !$0.isWarmup }
        let scored = working.filter { $0.isCompleted && $0.actualRPE != nil }
        guard !scored.isEmpty else { return 1.0 }
        let averageActual = scored.map { $0.actualRPE ?? 0 }.reduce(0, +) / Double(scored.count)
        let averageTarget = scored.map(\.targetRPE).reduce(0, +) / Double(scored.count)
        if averageActual >= averageTarget + 1 { return missedRPELoadCut }
        if averageActual <= averageTarget - 1 { return easyRPELoadBump }
        if working.allSatisfy(\.isCompleted) { return completedSmallBump }
        return 1.0
    }

    /// Set count drifts toward MRV when completion is high and 7-day soreness is low; drops toward MEV otherwise.
    /// Incomplete weeks never increase volume.
    public static func nextSetCount(
        current: Int,
        mev: Int,
        mrv: Int,
        completionRate: Double,
        averageSoreness: Double
    ) -> Int {
        if completionRate < 1.0 {
            return max(mev, current - 1)
        }
        if averageSoreness <= 2.5 {
            return min(mrv, current + 1)
        }
        if averageSoreness >= 3.5 {
            return max(mev, current - 1)
        }
        return current
    }

    public static func adjustments(
        exercises: [CompletedExercise],
        currentSetCounts: [String: Int],
        profile: AthleteProfile,
        averageSoreness: Double
    ) -> [ProgressionAdjustment] {
        let workingSets = exercises.flatMap { $0.sets.filter { !$0.isWarmup } }
        let completionRate: Double
        if workingSets.isEmpty {
            completionRate = 0
        } else {
            completionRate = Double(workingSets.filter(\.isCompleted).count) / Double(workingSets.count)
        }

        var weeklyByMuscle: [MuscleGroup: Int] = [:]
        var owners: [String: MuscleGroup] = [:]
        for exercise in exercises {
            let workingCount = currentSetCounts[exercise.catalogID]
                ?? exercise.sets.filter { !$0.isWarmup }.count
            let muscle = ExerciseLibrary.exercise(id: exercise.catalogID)?.primaryMuscles.first ?? .upperBack
            owners[exercise.catalogID] = muscle
            weeklyByMuscle[muscle, default: 0] += workingCount
        }

        var muscleTargets: [MuscleGroup: Int] = [:]
        for (muscle, current) in weeklyByMuscle {
            let landmark = VolumeLandmarks.scaled(for: muscle, profile: profile)
            muscleTargets[muscle] = nextSetCount(
                current: current,
                mev: landmark.mev,
                mrv: landmark.mrv,
                completionRate: completionRate,
                averageSoreness: averageSoreness
            )
        }

        var allocated: [String: Int] = [:]
        for (muscle, target) in muscleTargets {
            let group = exercises.filter { owners[$0.catalogID] == muscle }
            let currentTotal = max(1, weeklyByMuscle[muscle] ?? 1)
            var remaining = target
            for (index, exercise) in group.enumerated() {
                let current = currentSetCounts[exercise.catalogID]
                    ?? exercise.sets.filter { !$0.isWarmup }.count
                let share: Int
                if index == group.count - 1 {
                    share = max(1, remaining)
                } else {
                    share = max(1, Int((Double(current) * Double(target) / Double(currentTotal)).rounded()))
                    remaining -= share
                }
                allocated[exercise.catalogID] = share
            }
        }

        return exercises.map { exercise in
            let current = currentSetCounts[exercise.catalogID]
                ?? exercise.sets.filter { !$0.isWarmup }.count
            return ProgressionAdjustment(
                catalogID: exercise.catalogID,
                loadMultiplier: loadMultiplier(for: exercise.sets),
                nextSetCount: allocated[exercise.catalogID] ?? current
            )
        }
    }

    public static func apply(
        adjustments: [ProgressionAdjustment],
        to week: TrainingWeek,
        profile: AthleteProfile
    ) -> TrainingWeek {
        var updated = week
        let byID = Dictionary(uniqueKeysWithValues: adjustments.map { ($0.catalogID, $0) })
        for dayIndex in updated.days.indices where !updated.days[dayIndex].isRestDay {
            for exerciseIndex in updated.days[dayIndex].exercises.indices {
                let catalogID = updated.days[dayIndex].exercises[exerciseIndex].catalogID
                guard let adjustment = byID[catalogID] else { continue }
                var exercise = updated.days[dayIndex].exercises[exerciseIndex]
                for setIndex in exercise.sets.indices {
                    exercise.sets[setIndex].targetWeightKg = OneRepMax.roundToPlate(
                        exercise.sets[setIndex].targetWeightKg * adjustment.loadMultiplier,
                        unit: profile.preferredUnit
                    )
                }
                reconcileSetCount(&exercise, target: adjustment.nextSetCount)
                updated.days[dayIndex].exercises[exerciseIndex] = exercise
            }
        }
        return VolumeBalancer.rebalance(updated, profile: profile)
    }

    private static func reconcileSetCount(_ exercise: inout PlannedExercise, target: Int) {
        guard target > 0 else { return }
        let warmups = exercise.sets.filter(\.isWarmup)
        var working = exercise.sets.filter { !$0.isWarmup }
        if working.count < target, let last = working.last {
            while working.count < target {
                var copy = last
                copy.id = UUID()
                working.append(copy)
            }
        } else if working.count > target {
            working = Array(working.prefix(max(1, target)))
        }
        exercise.sets = warmups + working
    }
}

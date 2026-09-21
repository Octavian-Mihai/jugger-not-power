import Foundation

public enum VolumeClassifier {
    public static let pullMuscles: Set<MuscleGroup> = [.upperBack, .lats, .rearDelts, .hamstrings]
    public static let pushMuscles: Set<MuscleGroup> = [.chest, .frontDelts, .triceps]

    public static func isPull(primaryMuscles: [MuscleGroup], pattern: MovementPattern) -> Bool {
        if primaryMuscles.contains(where: { pullMuscles.contains($0) }) { return true }
        return pattern == .horizontalPull || pattern == .verticalPull
    }

    public static func isPush(primaryMuscles: [MuscleGroup], pattern: MovementPattern) -> Bool {
        if isPull(primaryMuscles: primaryMuscles, pattern: pattern) { return false }
        if primaryMuscles.contains(where: { pushMuscles.contains($0) }) { return true }
        return pattern == .horizontalPush || pattern == .verticalPush
    }
}

public enum VolumeMetrics {
    public static func weeklySetsByMuscle(_ week: TrainingWeek) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for day in week.days {
            for exercise in day.exercises {
                let setCount = exercise.sets.filter { !$0.isWarmup }.count
                for muscle in exercise.primaryMuscles {
                    counts[muscle, default: 0] += setCount
                }
            }
        }
        return counts
    }

    public static func pushSets(_ week: TrainingWeek) -> Int {
        week.days.reduce(0) { partial, day in
            partial + day.exercises.reduce(0) { inner, exercise in
                inner + (VolumeClassifier.isPush(primaryMuscles: exercise.primaryMuscles, pattern: exercise.movementPattern) ? exercise.sets.filter { !$0.isWarmup }.count : 0)
            }
        }
    }

    public static func pullSets(_ week: TrainingWeek) -> Int {
        week.days.reduce(0) { partial, day in
            partial + day.exercises.reduce(0) { inner, exercise in
                inner + (VolumeClassifier.isPull(primaryMuscles: exercise.primaryMuscles, pattern: exercise.movementPattern) ? exercise.sets.filter { !$0.isWarmup }.count : 0)
            }
        }
    }

    public static func pullPushRatio(_ week: TrainingWeek) -> Double {
        let push = Double(pushSets(week))
        let pull = Double(pullSets(week))
        guard push > 0 else { return pull > 0 ? .infinity : 1.0 }
        return pull / push
    }
}

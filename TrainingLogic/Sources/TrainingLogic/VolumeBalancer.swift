import Foundation

public enum VolumeBalancer {
    public static let minimumPullPushRatio = 1.0
    public static let targetPullPushRatio = 1.2

    private static let fillPriority: [(id: String, muscle: MuscleGroup)] = [
        ("barbell_row", .upperBack),
        ("seated_cable_row", .upperBack),
        ("lat_pulldown", .lats),
        ("pull_up", .lats),
        ("face_pull", .rearDelts),
        ("rear_delt_fly", .rearDelts),
        ("lying_leg_curl", .hamstrings),
        ("romanian_deadlift", .hamstrings),
        ("hanging_leg_raise", .core),
        ("plank", .core),
        ("cable_crunch", .core)
    ]

    public static func rebalance(_ week: TrainingWeek, profile: AthleteProfile) -> TrainingWeek {
        var balanced = week
        enforceFloors(on: &balanced, profile: profile)
        enforcePullRatio(on: &balanced, profile: profile)
        enforceFloors(on: &balanced, profile: profile)
        return balanced
    }

    private static func enforceFloors(on week: inout TrainingWeek, profile: AthleteProfile) {
        for muscle in VolumeLandmarks.floorMuscles {
            let mev = VolumeLandmarks.scaled(for: muscle, profile: profile).mev
            var guardCount = 0
            while (VolumeMetrics.weeklySetsByMuscle(week)[muscle] ?? 0) < mev && guardCount < 40 {
                addPullWork(to: &week, profile: profile, preferredMuscle: muscle)
                guardCount += 1
            }
        }
    }

    private static func enforcePullRatio(on week: inout TrainingWeek, profile: AthleteProfile) {
        var guardCount = 0
        while VolumeMetrics.pullPushRatio(week) < targetPullPushRatio && VolumeMetrics.pushSets(week) > 0 && guardCount < 80 {
            addPullWork(to: &week, profile: profile, preferredMuscle: nil)
            guardCount += 1
        }
    }

    private static func addPullWork(to week: inout TrainingWeek, profile: AthleteProfile, preferredMuscle: MuscleGroup?) {
        if addSetToExisting(in: &week, preferredMuscle: preferredMuscle) {
            return
        }
        insertNewExercise(into: &week, profile: profile, preferredMuscle: preferredMuscle)
    }

    private static func addSetToExisting(in week: inout TrainingWeek, preferredMuscle: MuscleGroup?) -> Bool {
        for dayIndex in week.days.indices where !week.days[dayIndex].isRestDay {
            for exerciseIndex in week.days[dayIndex].exercises.indices {
                let exercise = week.days[dayIndex].exercises[exerciseIndex]
                let matchesMuscle = preferredMuscle.map { exercise.primaryMuscles.contains($0) } ?? true
                let isUseful = VolumeClassifier.isPull(primaryMuscles: exercise.primaryMuscles, pattern: exercise.movementPattern)
                    || exercise.primaryMuscles.contains(.core)
                guard matchesMuscle, isUseful, let last = exercise.sets.last(where: { !$0.isWarmup }) ?? exercise.sets.last else { continue }
                var copy = last
                copy.id = UUID()
                week.days[dayIndex].exercises[exerciseIndex].sets.append(copy)
                return true
            }
        }
        return false
    }

    private static func insertNewExercise(into week: inout TrainingWeek, profile: AthleteProfile, preferredMuscle: MuscleGroup?) {
        let catalogID = preferredFillID(for: preferredMuscle, week: week)
        let definition = ExerciseLibrary.require(catalogID)
        let prescription = LoadPrescription.accessory(block: week.block, mode: profile.trainingMode)
        let load = OneRepMax.workingLoadKg(for: definition, profile: profile, percent1RM: prescription.percent1RM)
        let sets = (0..<3).map { _ in
            PlannedSet(
                targetReps: prescription.reps,
                targetWeightKg: load,
                targetRPE: prescription.rpe,
                percent1RM: prescription.percent1RM
            )
        }
        let planned = PlannedExercise(
            catalogID: definition.id,
            name: definition.name,
            movementPattern: definition.movementPattern,
            primaryMuscles: definition.primaryMuscles,
            role: .accessory,
            sets: sets
        )
        let dayIndex = week.days.enumerated()
            .filter { !$0.element.isRestDay }
            .min { lhs, rhs in
                lhs.element.exercises.count < rhs.element.exercises.count
            }?.offset ?? week.days.firstIndex(where: { !$0.isRestDay }) ?? 0
        guard week.days.indices.contains(dayIndex) else { return }
        if let existing = week.days[dayIndex].exercises.firstIndex(where: { $0.catalogID == catalogID }) {
            var copy = week.days[dayIndex].exercises[existing].sets.last ?? sets[0]
            copy.id = UUID()
            week.days[dayIndex].exercises[existing].sets.append(copy)
        } else {
            week.days[dayIndex].exercises.append(planned)
        }
    }

    private static func preferredFillID(for muscle: MuscleGroup?, week: TrainingWeek) -> String {
        let existing = Set(week.days.flatMap { $0.exercises.map(\.catalogID) })
        let candidates = fillPriority.filter { entry in
            muscle == nil || entry.muscle == muscle
        }
        if let unused = candidates.first(where: { !existing.contains($0.id) }) {
            return unused.id
        }
        return candidates.first?.id ?? "barbell_row"
    }
}

enum LoadPrescription {
    struct Scheme {
        var reps: Int
        var rpe: Double
        var percent1RM: Double
    }

    static func scheme(role: ExerciseRole, block: TrainingBlock, mode: TrainingMode) -> Scheme {
        if mode == .bodybuilding && block == .peaking {
            switch role {
            case .main: return Scheme(reps: 8, rpe: 7.5, percent1RM: 0.70)
            case .secondary: return Scheme(reps: 10, rpe: 7.5, percent1RM: 0.65)
            case .accessory: return Scheme(reps: 12, rpe: 7.0, percent1RM: 0.55)
            }
        }
        switch (block, role) {
        case (.hypertrophy, .main): return Scheme(reps: 8, rpe: 7.5, percent1RM: 0.70)
        case (.hypertrophy, .secondary): return Scheme(reps: 10, rpe: 7.5, percent1RM: 0.65)
        case (.hypertrophy, .accessory): return Scheme(reps: 12, rpe: 7.0, percent1RM: 0.55)
        case (.strength, .main): return Scheme(reps: 5, rpe: 8.0, percent1RM: 0.80)
        case (.strength, .secondary): return Scheme(reps: 6, rpe: 7.5, percent1RM: 0.70)
        case (.strength, .accessory): return Scheme(reps: 8, rpe: 7.5, percent1RM: 0.60)
        case (.peaking, .main): return Scheme(reps: 2, rpe: 8.5, percent1RM: 0.90)
        case (.peaking, .secondary): return Scheme(reps: 4, rpe: 8.0, percent1RM: 0.75)
        case (.peaking, .accessory): return Scheme(reps: 6, rpe: 7.5, percent1RM: 0.60)
        }
    }

    static func accessory(block: TrainingBlock, mode: TrainingMode) -> Scheme {
        scheme(role: .accessory, block: block, mode: mode)
    }

    static func setCount(role: ExerciseRole, weekNumber: Int, block: TrainingBlock, mode: TrainingMode) -> Int {
        let progress = VolumeLandmarks.weeklyVolumeProgress(weekNumber: weekNumber, mode: mode)
        let base: Double
        switch role {
        case .main: base = 4
        case .secondary: base = 3
        case .accessory: base = 2.5
        }
        if mode == .bodybuilding && block == .peaking {
            return max(2, Int((base * (0.85 + 0.25 * progress)).rounded()))
        }
        switch block {
        case .hypertrophy:
            return max(2, Int((base * (0.85 + 0.40 * progress)).rounded()))
        case .strength:
            return role == .main ? 5 : max(2, Int((base * 0.85).rounded()))
        case .peaking:
            return role == .main ? 4 : 2
        }
    }
}

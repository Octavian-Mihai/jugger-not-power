import Foundation

public struct ExerciseDefinition: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var movementPattern: MovementPattern
    public var primaryMuscles: [MuscleGroup]
    public var relatedLift: CompetitionLift
    public var loadFraction: Double
    public var isBodyweight: Bool

    public init(
        id: String,
        name: String,
        movementPattern: MovementPattern,
        primaryMuscles: [MuscleGroup],
        relatedLift: CompetitionLift,
        loadFraction: Double,
        isBodyweight: Bool = false
    ) {
        self.id = id
        self.name = name
        self.movementPattern = movementPattern
        self.primaryMuscles = primaryMuscles
        self.relatedLift = relatedLift
        self.loadFraction = loadFraction
        self.isBodyweight = isBodyweight
    }

    public var isCompound: Bool {
        movementPattern != .isolation && movementPattern != .carry
    }

    public var isPullVolume: Bool {
        VolumeClassifier.isPull(primaryMuscles: primaryMuscles, pattern: movementPattern)
    }

    public var isPushVolume: Bool {
        VolumeClassifier.isPush(primaryMuscles: primaryMuscles, pattern: movementPattern)
    }
}

public enum ExerciseLibrary {
    public static let all: [ExerciseDefinition] = [
        ExerciseDefinition(id: "barbell_bench_press", name: "Barbell Bench Press", movementPattern: .horizontalPush, primaryMuscles: [.chest, .triceps, .frontDelts], relatedLift: .bench, loadFraction: 1.0),
        ExerciseDefinition(id: "incline_barbell_press", name: "Incline Barbell Press", movementPattern: .horizontalPush, primaryMuscles: [.chest, .frontDelts, .triceps], relatedLift: .bench, loadFraction: 0.85),
        ExerciseDefinition(id: "decline_bench_press", name: "Decline Bench Press", movementPattern: .horizontalPush, primaryMuscles: [.chest, .triceps], relatedLift: .bench, loadFraction: 0.95),
        ExerciseDefinition(id: "dumbbell_bench_press", name: "Dumbbell Bench Press", movementPattern: .horizontalPush, primaryMuscles: [.chest, .triceps, .frontDelts], relatedLift: .bench, loadFraction: 0.80),
        ExerciseDefinition(id: "incline_dumbbell_press", name: "Incline Dumbbell Press", movementPattern: .horizontalPush, primaryMuscles: [.chest, .frontDelts, .triceps], relatedLift: .bench, loadFraction: 0.70),
        ExerciseDefinition(id: "dumbbell_fly", name: "Dumbbell Fly", movementPattern: .isolation, primaryMuscles: [.chest], relatedLift: .bench, loadFraction: 0.30),
        ExerciseDefinition(id: "cable_fly", name: "Cable Fly", movementPattern: .isolation, primaryMuscles: [.chest], relatedLift: .bench, loadFraction: 0.25),
        ExerciseDefinition(id: "pec_deck", name: "Pec Deck", movementPattern: .isolation, primaryMuscles: [.chest], relatedLift: .bench, loadFraction: 0.40),
        ExerciseDefinition(id: "push_up", name: "Push-Up", movementPattern: .horizontalPush, primaryMuscles: [.chest, .triceps, .frontDelts], relatedLift: .bench, loadFraction: 0.55, isBodyweight: true),
        ExerciseDefinition(id: "dips", name: "Dips", movementPattern: .horizontalPush, primaryMuscles: [.chest, .triceps, .frontDelts], relatedLift: .bench, loadFraction: 0.70, isBodyweight: true),
        ExerciseDefinition(id: "close_grip_bench", name: "Close-Grip Bench Press", movementPattern: .horizontalPush, primaryMuscles: [.triceps, .chest], relatedLift: .bench, loadFraction: 0.85),
        ExerciseDefinition(id: "overhead_press", name: "Overhead Press", movementPattern: .verticalPush, primaryMuscles: [.frontDelts, .triceps], relatedLift: .ohp, loadFraction: 1.0),
        ExerciseDefinition(id: "seated_dumbbell_press", name: "Seated Dumbbell Press", movementPattern: .verticalPush, primaryMuscles: [.frontDelts, .triceps], relatedLift: .ohp, loadFraction: 0.80),
        ExerciseDefinition(id: "arnold_press", name: "Arnold Press", movementPattern: .verticalPush, primaryMuscles: [.frontDelts, .sideDelts], relatedLift: .ohp, loadFraction: 0.70),
        ExerciseDefinition(id: "lateral_raise", name: "Lateral Raise", movementPattern: .isolation, primaryMuscles: [.sideDelts], relatedLift: .ohp, loadFraction: 0.20),
        ExerciseDefinition(id: "cable_lateral_raise", name: "Cable Lateral Raise", movementPattern: .isolation, primaryMuscles: [.sideDelts], relatedLift: .ohp, loadFraction: 0.18),
        ExerciseDefinition(id: "front_raise", name: "Front Raise", movementPattern: .isolation, primaryMuscles: [.frontDelts], relatedLift: .ohp, loadFraction: 0.22),
        ExerciseDefinition(id: "tricep_pushdown", name: "Triceps Pushdown", movementPattern: .isolation, primaryMuscles: [.triceps], relatedLift: .bench, loadFraction: 0.35),
        ExerciseDefinition(id: "overhead_tricep_extension", name: "Overhead Triceps Extension", movementPattern: .isolation, primaryMuscles: [.triceps], relatedLift: .bench, loadFraction: 0.30),
        ExerciseDefinition(id: "skull_crusher", name: "Skull Crusher", movementPattern: .isolation, primaryMuscles: [.triceps], relatedLift: .bench, loadFraction: 0.40),

        ExerciseDefinition(id: "conventional_deadlift", name: "Conventional Deadlift", movementPattern: .hinge, primaryMuscles: [.hamstrings, .glutes, .upperBack], relatedLift: .deadlift, loadFraction: 1.0),
        ExerciseDefinition(id: "romanian_deadlift", name: "Romanian Deadlift", movementPattern: .hinge, primaryMuscles: [.hamstrings, .glutes], relatedLift: .deadlift, loadFraction: 0.70),
        ExerciseDefinition(id: "deficit_deadlift", name: "Deficit Deadlift", movementPattern: .hinge, primaryMuscles: [.hamstrings, .glutes, .upperBack], relatedLift: .deadlift, loadFraction: 0.85),
        ExerciseDefinition(id: "good_morning", name: "Good Morning", movementPattern: .hinge, primaryMuscles: [.hamstrings, .glutes], relatedLift: .deadlift, loadFraction: 0.45),
        ExerciseDefinition(id: "hip_thrust", name: "Hip Thrust", movementPattern: .hinge, primaryMuscles: [.glutes, .hamstrings], relatedLift: .squat, loadFraction: 0.90),
        ExerciseDefinition(id: "kettlebell_swing", name: "Kettlebell Swing", movementPattern: .hinge, primaryMuscles: [.hamstrings, .glutes, .core], relatedLift: .deadlift, loadFraction: 0.30),
        ExerciseDefinition(id: "barbell_row", name: "Barbell Row", movementPattern: .horizontalPull, primaryMuscles: [.upperBack, .lats], relatedLift: .deadlift, loadFraction: 0.55),
        ExerciseDefinition(id: "pendlay_row", name: "Pendlay Row", movementPattern: .horizontalPull, primaryMuscles: [.upperBack, .lats], relatedLift: .deadlift, loadFraction: 0.50),
        ExerciseDefinition(id: "chest_supported_row", name: "Chest-Supported Row", movementPattern: .horizontalPull, primaryMuscles: [.upperBack, .lats], relatedLift: .deadlift, loadFraction: 0.45),
        ExerciseDefinition(id: "seated_cable_row", name: "Seated Cable Row", movementPattern: .horizontalPull, primaryMuscles: [.upperBack, .lats], relatedLift: .deadlift, loadFraction: 0.45),
        ExerciseDefinition(id: "lat_pulldown", name: "Lat Pulldown", movementPattern: .verticalPull, primaryMuscles: [.lats, .upperBack], relatedLift: .deadlift, loadFraction: 0.45),
        ExerciseDefinition(id: "pull_up", name: "Pull-Up", movementPattern: .verticalPull, primaryMuscles: [.lats, .upperBack, .biceps], relatedLift: .deadlift, loadFraction: 0.40, isBodyweight: true),
        ExerciseDefinition(id: "chin_up", name: "Chin-Up", movementPattern: .verticalPull, primaryMuscles: [.lats, .biceps], relatedLift: .deadlift, loadFraction: 0.40, isBodyweight: true),
        ExerciseDefinition(id: "face_pull", name: "Face Pull", movementPattern: .isolation, primaryMuscles: [.rearDelts, .upperBack], relatedLift: .ohp, loadFraction: 0.25),
        ExerciseDefinition(id: "reverse_pec_deck", name: "Reverse Pec Deck", movementPattern: .isolation, primaryMuscles: [.rearDelts], relatedLift: .ohp, loadFraction: 0.25),
        ExerciseDefinition(id: "rear_delt_fly", name: "Rear Delt Fly", movementPattern: .isolation, primaryMuscles: [.rearDelts], relatedLift: .ohp, loadFraction: 0.18),
        ExerciseDefinition(id: "barbell_curl", name: "Barbell Curl", movementPattern: .isolation, primaryMuscles: [.biceps], relatedLift: .deadlift, loadFraction: 0.25),
        ExerciseDefinition(id: "dumbbell_curl", name: "Dumbbell Curl", movementPattern: .isolation, primaryMuscles: [.biceps], relatedLift: .deadlift, loadFraction: 0.20),
        ExerciseDefinition(id: "hammer_curl", name: "Hammer Curl", movementPattern: .isolation, primaryMuscles: [.biceps], relatedLift: .deadlift, loadFraction: 0.22),
        ExerciseDefinition(id: "preacher_curl", name: "Preacher Curl", movementPattern: .isolation, primaryMuscles: [.biceps], relatedLift: .deadlift, loadFraction: 0.20),

        ExerciseDefinition(id: "back_squat", name: "Back Squat", movementPattern: .squat, primaryMuscles: [.quads, .glutes], relatedLift: .squat, loadFraction: 1.0),
        ExerciseDefinition(id: "front_squat", name: "Front Squat", movementPattern: .squat, primaryMuscles: [.quads, .core], relatedLift: .squat, loadFraction: 0.85),
        ExerciseDefinition(id: "pause_squat", name: "Pause Squat", movementPattern: .squat, primaryMuscles: [.quads, .glutes], relatedLift: .squat, loadFraction: 0.85),
        ExerciseDefinition(id: "goblet_squat", name: "Goblet Squat", movementPattern: .squat, primaryMuscles: [.quads, .glutes], relatedLift: .squat, loadFraction: 0.40),
        ExerciseDefinition(id: "leg_press", name: "Leg Press", movementPattern: .squat, primaryMuscles: [.quads, .glutes], relatedLift: .squat, loadFraction: 1.40),
        ExerciseDefinition(id: "walking_lunge", name: "Walking Lunge", movementPattern: .squat, primaryMuscles: [.quads, .glutes], relatedLift: .squat, loadFraction: 0.40),
        ExerciseDefinition(id: "bulgarian_split_squat", name: "Bulgarian Split Squat", movementPattern: .squat, primaryMuscles: [.quads, .glutes], relatedLift: .squat, loadFraction: 0.45),
        ExerciseDefinition(id: "leg_extension", name: "Leg Extension", movementPattern: .isolation, primaryMuscles: [.quads], relatedLift: .squat, loadFraction: 0.35),
        ExerciseDefinition(id: "lying_leg_curl", name: "Lying Leg Curl", movementPattern: .isolation, primaryMuscles: [.hamstrings], relatedLift: .deadlift, loadFraction: 0.30),
        ExerciseDefinition(id: "seated_leg_curl", name: "Seated Leg Curl", movementPattern: .isolation, primaryMuscles: [.hamstrings], relatedLift: .deadlift, loadFraction: 0.28),
        ExerciseDefinition(id: "standing_calf_raise", name: "Standing Calf Raise", movementPattern: .isolation, primaryMuscles: [.calves], relatedLift: .squat, loadFraction: 0.60),
        ExerciseDefinition(id: "seated_calf_raise", name: "Seated Calf Raise", movementPattern: .isolation, primaryMuscles: [.calves], relatedLift: .squat, loadFraction: 0.40),

        ExerciseDefinition(id: "hanging_leg_raise", name: "Hanging Leg Raise", movementPattern: .isolation, primaryMuscles: [.core], relatedLift: .deadlift, loadFraction: 0.0, isBodyweight: true),
        ExerciseDefinition(id: "ab_wheel", name: "Ab Wheel", movementPattern: .isolation, primaryMuscles: [.core], relatedLift: .deadlift, loadFraction: 0.0, isBodyweight: true),
        ExerciseDefinition(id: "plank", name: "Plank", movementPattern: .isolation, primaryMuscles: [.core], relatedLift: .deadlift, loadFraction: 0.0, isBodyweight: true),
        ExerciseDefinition(id: "cable_crunch", name: "Cable Crunch", movementPattern: .isolation, primaryMuscles: [.core], relatedLift: .deadlift, loadFraction: 0.25),
        ExerciseDefinition(id: "farmers_carry", name: "Farmer's Carry", movementPattern: .carry, primaryMuscles: [.core, .upperBack], relatedLift: .deadlift, loadFraction: 0.40),
        ExerciseDefinition(id: "suitcase_carry", name: "Suitcase Carry", movementPattern: .carry, primaryMuscles: [.core], relatedLift: .deadlift, loadFraction: 0.30)
    ]

    public static func exercise(id: String) -> ExerciseDefinition? {
        all.first { $0.id == id }
    }

    public static func require(_ id: String) -> ExerciseDefinition {
        guard let match = exercise(id: id) else {
            preconditionFailure("Unknown exercise catalog ID: \(id)")
        }
        return match
    }

    public static func matching(muscle: MuscleGroup) -> [ExerciseDefinition] {
        all.filter { $0.primaryMuscles.contains(muscle) }
    }

    /// Alternatives that share the same movement pattern and at least one primary muscle.
    public static func substitutes(for id: String) -> [ExerciseDefinition] {
        guard let source = exercise(id: id) else { return [] }
        let sourceMuscles = Set(source.primaryMuscles)
        return all.filter { candidate in
            candidate.id != source.id
                && candidate.movementPattern == source.movementPattern
                && !sourceMuscles.isDisjoint(with: candidate.primaryMuscles)
        }
    }

    public static func restSeconds(for pattern: MovementPattern) -> Int {
        switch pattern {
        case .isolation, .carry:
            return 90
        case .horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .hinge, .squat:
            return 180
        }
    }
}

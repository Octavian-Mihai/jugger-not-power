import Foundation

public struct PlannedSet: Equatable, Sendable, Identifiable, Codable {
    public var id: UUID
    public var targetReps: Int
    public var targetWeightKg: Double
    public var targetRPE: Double
    public var percent1RM: Double?
    public var isWarmup: Bool

    public init(
        id: UUID = UUID(),
        targetReps: Int,
        targetWeightKg: Double,
        targetRPE: Double,
        percent1RM: Double? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetRPE = targetRPE
        self.percent1RM = percent1RM
        self.isWarmup = isWarmup
    }
}

public struct PlannedExercise: Equatable, Sendable, Identifiable, Codable {
    public var id: UUID
    public var catalogID: String
    public var name: String
    public var movementPattern: MovementPattern
    public var primaryMuscles: [MuscleGroup]
    public var role: ExerciseRole
    public var sets: [PlannedSet]

    public init(
        id: UUID = UUID(),
        catalogID: String,
        name: String,
        movementPattern: MovementPattern,
        primaryMuscles: [MuscleGroup],
        role: ExerciseRole = .accessory,
        sets: [PlannedSet]
    ) {
        self.id = id
        self.catalogID = catalogID
        self.name = name
        self.movementPattern = movementPattern
        self.primaryMuscles = primaryMuscles
        self.role = role
        self.sets = sets
    }
}

public struct PlannedWorkout: Equatable, Sendable, Identifiable, Codable {
    public var id: UUID
    public var dayIndex: Int
    public var title: String
    public var exercises: [PlannedExercise]
    public var isRestDay: Bool

    public init(
        id: UUID = UUID(),
        dayIndex: Int,
        title: String,
        exercises: [PlannedExercise],
        isRestDay: Bool = false
    ) {
        self.id = id
        self.dayIndex = dayIndex
        self.title = title
        self.exercises = exercises
        self.isRestDay = isRestDay
    }

    public static func rest(dayIndex: Int) -> PlannedWorkout {
        PlannedWorkout(dayIndex: dayIndex, title: "Rest", exercises: [], isRestDay: true)
    }
}

public struct TrainingWeek: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var weekNumber: Int
    public var block: TrainingBlock
    public var days: [PlannedWorkout]

    public init(
        id: UUID = UUID(),
        weekNumber: Int,
        block: TrainingBlock,
        days: [PlannedWorkout]
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.block = block
        self.days = days
    }
}

public struct GeneratedProgram: Equatable, Sendable {
    public var mode: TrainingMode
    public var durationWeeks: Int
    public var weeks: [TrainingWeek]

    public init(mode: TrainingMode, durationWeeks: Int = Periodization.defaultDurationWeeks, weeks: [TrainingWeek]) {
        self.mode = mode
        self.durationWeeks = durationWeeks
        self.weeks = weeks
    }
}

public struct CompletedSet: Equatable, Sendable {
    public var targetReps: Int
    public var targetWeightKg: Double
    public var targetRPE: Double
    public var actualReps: Int?
    public var actualWeightKg: Double?
    public var actualRPE: Double?
    public var isCompleted: Bool
    public var isWarmup: Bool

    public init(
        targetReps: Int,
        targetWeightKg: Double,
        targetRPE: Double,
        actualReps: Int? = nil,
        actualWeightKg: Double? = nil,
        actualRPE: Double? = nil,
        isCompleted: Bool,
        isWarmup: Bool = false
    ) {
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetRPE = targetRPE
        self.actualReps = actualReps
        self.actualWeightKg = actualWeightKg
        self.actualRPE = actualRPE
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
    }
}

public struct CompletedExercise: Equatable, Sendable {
    public var catalogID: String
    public var sets: [CompletedSet]

    public init(catalogID: String, sets: [CompletedSet]) {
        self.catalogID = catalogID
        self.sets = sets
    }
}

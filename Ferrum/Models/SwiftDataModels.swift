import Foundation
import SwiftData
import TrainingLogic

@Model
final class User {
    var trainingMode: TrainingMode
    var experienceLevel: ExperienceLevel
    var bodyweightKg: Double
    var preferredUnit: WeightUnit
    var squatPR: Double?
    var benchPR: Double?
    var deadliftPR: Double?
    var ohpPR: Double?
    var hasCompletedOnboarding: Bool
    @Relationship(deleteRule: .cascade, inverse: \TrainingProgram.user)
    var programs: [TrainingProgram]
    @Relationship(deleteRule: .cascade, inverse: \ReadinessCheckIn.user)
    var checkIns: [ReadinessCheckIn]

    init(
        trainingMode: TrainingMode,
        experienceLevel: ExperienceLevel,
        bodyweightKg: Double,
        preferredUnit: WeightUnit,
        squatPR: Double? = nil,
        benchPR: Double? = nil,
        deadliftPR: Double? = nil,
        ohpPR: Double? = nil,
        hasCompletedOnboarding: Bool = false
    ) {
        self.trainingMode = trainingMode
        self.experienceLevel = experienceLevel
        self.bodyweightKg = bodyweightKg
        self.preferredUnit = preferredUnit
        self.squatPR = squatPR
        self.benchPR = benchPR
        self.deadliftPR = deadliftPR
        self.ohpPR = ohpPR
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.programs = []
        self.checkIns = []
    }

    var athleteProfile: AthleteProfile {
        AthleteProfile(
            trainingMode: trainingMode,
            experienceLevel: experienceLevel,
            bodyweightKg: bodyweightKg,
            preferredUnit: preferredUnit,
            squatPR: squatPR,
            benchPR: benchPR,
            deadliftPR: deadliftPR,
            ohpPR: ohpPR
        )
    }

    var activeProgram: TrainingProgram? {
        programs.sorted { $0.createdAt > $1.createdAt }.first
    }
}

@Model
final class TrainingProgram {
    var createdAt: Date
    var mode: TrainingMode
    var durationWeeks: Int
    var user: User?
    @Relationship(deleteRule: .cascade, inverse: \TrainingWeek.program)
    var weeks: [TrainingWeek]

    init(createdAt: Date = .now, mode: TrainingMode, durationWeeks: Int = 12, user: User? = nil) {
        self.createdAt = createdAt
        self.mode = mode
        self.durationWeeks = durationWeeks
        self.user = user
        self.weeks = []
    }

    var orderedWeeks: [TrainingWeek] {
        weeks.sorted { $0.weekNumber < $1.weekNumber }
    }
}

@Model
final class TrainingWeek {
    var weekNumber: Int
    var block: TrainingBlock
    var didProgressNextWeek: Bool
    var program: TrainingProgram?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.week)
    var days: [WorkoutDay]

    init(weekNumber: Int, block: TrainingBlock, program: TrainingProgram? = nil) {
        self.weekNumber = weekNumber
        self.block = block
        self.didProgressNextWeek = false
        self.program = program
        self.days = []
    }

    var orderedDays: [WorkoutDay] {
        days.sorted { $0.dayIndex < $1.dayIndex }
    }

    var trainingDays: [WorkoutDay] {
        orderedDays.filter { !$0.isRestDay }
    }

    var isCompleted: Bool {
        let training = trainingDays
        return !training.isEmpty && training.allSatisfy(\.isCompleted)
    }
}

@Model
final class WorkoutDay {
    var dayIndex: Int
    var scheduledDate: Date
    var title: String
    var isCompleted: Bool
    var isRestDay: Bool
    var isSkipped: Bool
    var appliedLoadMultiplier: Double
    var appliedVolumeMultiplier: Double
    var appliedReadinessScore: Double?
    var appliedReadinessBand: String?
    var originalPlanJSON: Data?
    var week: TrainingWeek?
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workoutDay)
    var exercises: [Exercise]

    init(
        dayIndex: Int,
        scheduledDate: Date,
        title: String,
        isCompleted: Bool = false,
        isRestDay: Bool = false,
        isSkipped: Bool = false,
        appliedLoadMultiplier: Double = 1.0,
        appliedVolumeMultiplier: Double = 1.0,
        week: TrainingWeek? = nil
    ) {
        self.dayIndex = dayIndex
        self.scheduledDate = scheduledDate
        self.title = title
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.isSkipped = isSkipped
        self.appliedLoadMultiplier = appliedLoadMultiplier
        self.appliedVolumeMultiplier = appliedVolumeMultiplier
        self.week = week
        self.exercises = []
    }

    var orderedExercises: [Exercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    var nextIncompleteSet: (Exercise, SetLog)? {
        for exercise in orderedExercises {
            if let set = exercise.orderedSets.first(where: { !$0.isCompleted }) {
                return (exercise, set)
            }
        }
        return nil
    }
}

@Model
final class Exercise {
    var catalogID: String
    var name: String
    var movementPatternRaw: String
    var primaryMuscleRaw: [String]
    var roleRaw: String
    var sortIndex: Int
    var plannedSetCount: Int
    var workoutDay: WorkoutDay?
    @Relationship(deleteRule: .cascade, inverse: \SetLog.exercise)
    var setLogs: [SetLog]

    var movementPattern: MovementPattern {
        get { MovementPattern(rawValue: movementPatternRaw) ?? .isolation }
        set { movementPatternRaw = newValue.rawValue }
    }

    var primaryMuscles: [MuscleGroup] {
        get { primaryMuscleRaw.compactMap(MuscleGroup.init(rawValue:)) }
        set { primaryMuscleRaw = newValue.map(\.rawValue) }
    }

    var role: ExerciseRole {
        get { ExerciseRole(rawValue: roleRaw) ?? .accessory }
        set { roleRaw = newValue.rawValue }
    }

    init(
        catalogID: String,
        name: String,
        movementPattern: MovementPattern,
        primaryMuscles: [MuscleGroup],
        role: ExerciseRole,
        sortIndex: Int,
        plannedSetCount: Int,
        workoutDay: WorkoutDay? = nil
    ) {
        self.catalogID = catalogID
        self.name = name
        self.movementPatternRaw = movementPattern.rawValue
        self.primaryMuscleRaw = primaryMuscles.map(\.rawValue)
        self.roleRaw = role.rawValue
        self.sortIndex = sortIndex
        self.plannedSetCount = plannedSetCount
        self.workoutDay = workoutDay
        self.setLogs = []
    }

    var orderedSets: [SetLog] {
        setLogs.sorted { $0.setIndex < $1.setIndex }
    }
}

@Model
final class SetLog {
    var setIndex: Int
    var targetReps: Int
    var targetWeightKg: Double
    var targetRPE: Double
    var actualReps: Int?
    var actualWeightKg: Double?
    var actualRPE: Double?
    var isCompleted: Bool
    var isWarmup: Bool
    var percent1RM: Double?
    var completedAt: Date?
    var exercise: Exercise?

    init(
        setIndex: Int,
        targetReps: Int,
        targetWeightKg: Double,
        targetRPE: Double,
        actualReps: Int? = nil,
        actualWeightKg: Double? = nil,
        actualRPE: Double? = nil,
        isCompleted: Bool = false,
        isWarmup: Bool = false,
        percent1RM: Double? = nil,
        exercise: Exercise? = nil
    ) {
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetRPE = targetRPE
        self.actualReps = actualReps
        self.actualWeightKg = actualWeightKg
        self.actualRPE = actualRPE
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
        self.percent1RM = percent1RM
        self.exercise = exercise
    }
}

@Model
final class ReadinessCheckIn {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var sleep: Int
    var energy: Int
    var motivation: Int
    var soreness: Int
    var stress: Int
    var score: Double
    var bandRaw: String
    var user: User?

    init(
        date: Date,
        sleep: Int,
        energy: Int,
        motivation: Int,
        soreness: Int,
        stress: Int,
        score: Double,
        band: ReadinessBand,
        user: User? = nil
    ) {
        self.date = date
        self.dayKey = Self.dayKey(for: date)
        self.sleep = sleep
        self.energy = energy
        self.motivation = motivation
        self.soreness = soreness
        self.stress = stress
        self.score = score
        self.bandRaw = band.rawValue
        self.user = user
    }

    var band: ReadinessBand {
        ReadinessBand(rawValue: bandRaw) ?? .hold
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

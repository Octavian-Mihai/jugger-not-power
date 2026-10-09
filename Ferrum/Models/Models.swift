import Foundation
import SwiftData
import FerrumCore

/// Weights are always stored in kilograms.
@Model
final class Profile {
    var unitRaw: String = WeightUnit.kg.rawValue
    var experienceRaw: String = Experience.intermediate.rawValue
    var squatKg: Double = 0
    var benchKg: Double = 0
    var deadliftKg: Double = 0
    var daysPerWeek: Int = 4
    var onboarded: Bool = false
    var themeRaw: String = ThemeKind.forge.rawValue
    // Generator questionnaire answers, remembered for next time (comma-separated ids).
    var prefMinutes: Int = 60
    var prefEquipment: String = ""
    var prefLikes: String = ""
    var prefDislikes: String = ""
    var prefAvoid: String = ""
    /// Workout screen: false = one scrolling list, true = swipe between exercises.
    var swipeWorkout: Bool = false
    var hapticsEnabled: Bool = true
    /// Barbell weight used by the workout keypad's plate maths, always in kg.
    var barKg: Double = 20

    init() {}

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }
    var experience: Experience {
        get { Experience(rawValue: experienceRaw) ?? .intermediate }
        set { experienceRaw = newValue.rawValue }
    }
    var theme: ThemeKind {
        get { ThemeKind(rawValue: themeRaw) ?? .forge }
        set { themeRaw = newValue.rawValue }
    }

    func oneRepMaxKg(_ lift: MainLift) -> Double {
        switch lift { case .squat: return squatKg; case .bench: return benchKg; case .deadlift: return deadliftKg }
    }
    func setOneRepMaxKg(_ lift: MainLift, _ value: Double) {
        switch lift { case .squat: squatKg = value; case .bench: benchKg = value; case .deadlift: deadliftKg = value }
    }
}

@Model
final class Program {
    var id = UUID()
    var name: String = ""
    var planData: Data = Data()
    var createdAt = Date()
    var completedSessions: Int = 0
    var isActive: Bool = false

    init(plan: ProgramPlan) {
        self.name = plan.name
        self.planData = (try? plan.encoded()) ?? Data()
    }

    var plan: ProgramPlan {
        get { (try? ProgramPlan.decode(planData)) ?? ProgramPlan(name: name, blocks: []) }
        set { planData = (try? newValue.encoded()) ?? planData; name = newValue.name }
    }
}

@Model
final class WorkoutSession {
    var id = UUID()
    var date = Date()
    var programID: UUID?
    var dayName: String = ""
    var blockName: String = ""
    var weekLabel: String = ""
    var readinessScore: Int = 0
    var isFinished: Bool = false
    var isRest: Bool = false
    /// Load multiplier from the readiness check-in when the workout started (1 = unchanged).
    var loadMultiplier: Double = 1
    /// Shown in the workout when later exercises were eased or nudged up from how earlier ones went.
    var easeNote: String = ""
    var finishedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session) var sets: [LoggedSet] = []

    init(programID: UUID?, dayName: String, blockName: String, weekLabel: String, readinessScore: Int) {
        self.programID = programID; self.dayName = dayName; self.blockName = blockName
        self.weekLabel = weekLabel; self.readinessScore = readinessScore
    }

    var sortedSets: [LoggedSet] {
        sets.sorted { ($0.exerciseOrder, $0.setIndex) < ($1.exerciseOrder, $1.setIndex) }
    }
    var exerciseIDsInOrder: [String] {
        var seen = Set<String>(); var out: [String] = []
        for s in sortedSets where seen.insert(s.exerciseID).inserted { out.append(s.exerciseID) }
        return out
    }
    var duration: TimeInterval? { finishedAt.map { $0.timeIntervalSince(date) } }
}

@Model
final class LoggedSet {
    var exerciseID: String = ""
    var exerciseOrder: Int = 0
    var setIndex: Int = 0
    var restSeconds: Int = 120
    var targetReps: Int = 0
    var targetRepsLow: Int = 0
    var targetRIR: Double = 2
    var targetWeightKg: Double = 0
    var weightKg: Double = 0
    var reps: Int = 0
    var rir: Double = 2
    var isDone: Bool = false
    /// True once the lifter typed a weight, so auto-adjustment leaves it alone.
    var edited: Bool = false
    var date = Date()
    var session: WorkoutSession?

    init(exerciseID: String, exerciseOrder: Int, setIndex: Int, restSeconds: Int, targetReps: Int, targetRepsLow: Int,
         targetRIR: Double, targetWeightKg: Double) {
        self.exerciseID = exerciseID; self.exerciseOrder = exerciseOrder; self.setIndex = setIndex
        self.restSeconds = restSeconds; self.targetReps = targetReps; self.targetRepsLow = targetRepsLow
        self.targetRIR = targetRIR; self.targetWeightKg = targetWeightKg
        self.weightKg = targetWeightKg; self.reps = targetReps; self.rir = targetRIR
    }

    var record: SetRecord { SetRecord(exerciseID: exerciseID, weight: weightKg, reps: reps, rir: rir, date: date) }
}

@Model
final class ReadinessEntry {
    var date = Date()
    var sleep: Int = 3
    var energy: Int = 3
    var mood: Int = 3
    var soreness: Int = 2
    var score: Int = 0
    init(input: ReadinessInput) {
        sleep = input.sleep; energy = input.energy; mood = input.mood; soreness = input.soreness
        score = Readiness.score(input)
    }
    var input: ReadinessInput { ReadinessInput(sleep: sleep, energy: energy, mood: mood, soreness: soreness) }
}

@Model
final class CustomExercise {
    var id: String = ""
    var name: String = ""
    var pattern: String = "Accessory"
    var primaryMuscle: String = ""
    var equipment: String = "dumbbell"
    init(name: String, pattern: String, primaryMuscle: String, equipment: String) {
        self.id = "custom-" + UUID().uuidString.prefix(8).lowercased()
        self.name = name; self.pattern = pattern; self.primaryMuscle = primaryMuscle; self.equipment = equipment
    }
    var info: ExerciseInfo {
        ExerciseInfo(id: id, name: name, pattern: pattern, primary: primaryMuscle.isEmpty ? [] : [primaryMuscle],
                     cue: "Custom exercise.", equipment: equipment)
    }
}

@Model
final class BodyWeightEntry {
    var date = Date()
    var kg: Double = 0
    init(kg: Double, date: Date = .now) { self.kg = kg; self.date = date }
    var point: BodyWeightPoint { BodyWeightPoint(date: date, kg: kg) }
}

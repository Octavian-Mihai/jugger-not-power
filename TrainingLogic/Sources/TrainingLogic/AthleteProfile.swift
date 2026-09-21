import Foundation

public struct AthleteProfile: Equatable, Sendable {
    public var trainingMode: TrainingMode
    public var experienceLevel: ExperienceLevel
    public var bodyweightKg: Double
    public var preferredUnit: WeightUnit
    public var squatPR: Double?
    public var benchPR: Double?
    public var deadliftPR: Double?
    public var ohpPR: Double?

    public init(
        trainingMode: TrainingMode,
        experienceLevel: ExperienceLevel,
        bodyweightKg: Double,
        preferredUnit: WeightUnit = .kilogram,
        squatPR: Double? = nil,
        benchPR: Double? = nil,
        deadliftPR: Double? = nil,
        ohpPR: Double? = nil
    ) {
        self.trainingMode = trainingMode
        self.experienceLevel = experienceLevel
        self.bodyweightKg = bodyweightKg
        self.preferredUnit = preferredUnit
        self.squatPR = squatPR
        self.benchPR = benchPR
        self.deadliftPR = deadliftPR
        self.ohpPR = ohpPR
    }

    public func personalRecord(for lift: CompetitionLift) -> Double? {
        switch lift {
        case .squat: return squatPR
        case .bench: return benchPR
        case .deadlift: return deadliftPR
        case .ohp: return ohpPR
        }
    }
}

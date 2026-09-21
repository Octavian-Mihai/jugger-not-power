import Foundation

public enum OneRepMax {
    /// Epley: 1RM = weight * (1 + reps/30)
    public static func epley(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    public static func conservativeBodyweightEstimate(lift: CompetitionLift, profile: AthleteProfile) -> Double {
        let factor: Double
        switch (lift, profile.experienceLevel) {
        case (.squat, .novice): factor = 1.25
        case (.squat, .intermediate): factor = 1.50
        case (.squat, .advanced): factor = 1.75
        case (.bench, .novice): factor = 0.80
        case (.bench, .intermediate): factor = 1.00
        case (.bench, .advanced): factor = 1.25
        case (.deadlift, .novice): factor = 1.50
        case (.deadlift, .intermediate): factor = 1.75
        case (.deadlift, .advanced): factor = 2.00
        case (.ohp, .novice): factor = 0.50
        case (.ohp, .intermediate): factor = 0.65
        case (.ohp, .advanced): factor = 0.80
        }
        return profile.bodyweightKg * factor
    }

    public static func working1RM(lift: CompetitionLift, profile: AthleteProfile) -> Double {
        profile.personalRecord(for: lift) ?? conservativeBodyweightEstimate(lift: lift, profile: profile)
    }

    public static func workingLoadKg(for definition: ExerciseDefinition, profile: AthleteProfile, percent1RM: Double) -> Double {
        if definition.isBodyweight && definition.loadFraction == 0 {
            return 0
        }
        let oneRM = working1RM(lift: definition.relatedLift, profile: profile) * definition.loadFraction
        return roundToPlate(oneRM * percent1RM, unit: profile.preferredUnit)
    }

    /// Round to the smallest common plate in the athlete's display unit (2.5 kg or 5 lb), stored as kilograms.
    public static func roundToPlate(_ kg: Double, unit: WeightUnit = .kilogram) -> Double {
        guard kg > 0 else { return 0 }
        switch unit {
        case .kilogram:
            let increment = 2.5
            return max(increment, (kg / increment).rounded() * increment)
        case .pound:
            let poundsPerKilogram = 2.2046226218
            let pounds = kg * poundsPerKilogram
            let increment = 5.0
            let roundedPounds = max(increment, (pounds / increment).rounded() * increment)
            return roundedPounds / poundsPerKilogram
        }
    }
}

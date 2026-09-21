import Foundation

public enum TrainingMode: String, Codable, CaseIterable, Sendable, Hashable {
    case powerlifting
    case powerbuilding
    case bodybuilding
    case hybrid

    public var displayName: String {
        switch self {
        case .powerlifting: return "Powerlifting"
        case .powerbuilding: return "Powerbuilding"
        case .bodybuilding: return "Bodybuilding"
        case .hybrid: return "Hybrid"
        }
    }

    public var summary: String {
        switch self {
        case .powerlifting: return "4-day squat / bench / deadlift / press+back"
        case .powerbuilding: return "4-day upper / lower"
        case .bodybuilding: return "5-day push / pull / legs, hypertrophy-leaning peak"
        case .hybrid: return "4-day strength + hypertrophy mix"
        }
    }
}

public enum ExperienceLevel: String, Codable, CaseIterable, Sendable, Hashable {
    case novice
    case intermediate
    case advanced
}

public enum WeightUnit: String, Codable, CaseIterable, Sendable, Hashable {
    case kilogram
    case pound
}

public enum TrainingBlock: String, Codable, CaseIterable, Sendable, Hashable {
    case hypertrophy
    case strength
    case peaking
}

public enum MovementPattern: String, Codable, CaseIterable, Sendable, Hashable {
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case hinge
    case squat
    case carry
    case isolation
}

public enum MuscleGroup: String, Codable, CaseIterable, Sendable, Hashable {
    case chest
    case frontDelts
    case sideDelts
    case rearDelts
    case upperBack
    case lats
    case biceps
    case triceps
    case quads
    case hamstrings
    case glutes
    case calves
    case core
}

public enum CompetitionLift: String, Codable, CaseIterable, Sendable, Hashable {
    case squat
    case bench
    case deadlift
    case ohp
}

public enum ReadinessBand: String, Codable, Sendable, Hashable {
    case proceed
    case hold
    case cut
    case deload

    public var displayName: String {
        switch self {
        case .proceed: return "Proceed"
        case .hold: return "Hold"
        case .cut: return "Cut Volume"
        case .deload: return "Deload"
        }
    }
}

public enum ExerciseRole: String, Codable, Sendable, Hashable {
    case main
    case secondary
    case accessory
}

public enum Periodization {
    public static let defaultDurationWeeks = 12

    public static func block(forWeek weekNumber: Int) -> TrainingBlock {
        switch weekNumber {
        case 1...4: return .hypertrophy
        case 5...8: return .strength
        default: return .peaking
        }
    }
}

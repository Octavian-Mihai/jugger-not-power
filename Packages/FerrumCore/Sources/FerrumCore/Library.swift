import Foundation

public enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case kg, lb

    public var label: String { rawValue }
    /// Smallest loadable jump (a pair of the smallest plates).
    public var step: Double { self == .kg ? 2.5 : 5 }

    public func convert(_ value: Double, to other: WeightUnit) -> Double {
        if self == other { return value }
        return self == .kg ? value * 2.2046226218 : value / 2.2046226218
    }

    public func round(_ value: Double) -> Double {
        (value / step).rounded() * step
    }
}

public enum MainLift: String, Codable, CaseIterable, Identifiable, Sendable {
    case squat, bench, deadlift
    public var id: String { rawValue }
    public var exerciseID: String {
        switch self {
        case .squat: return "back-squat"
        case .bench: return "barbell-bench-press"
        case .deadlift: return "deadlift"
        }
    }
    public var title: String { rawValue.capitalized }

    /// Which main lift an exercise's percentage prescriptions refer to by default.
    public static func reference(forPattern pattern: String) -> MainLift? {
        switch pattern {
        case "Squat", "Lunge / Split": return .squat
        case "Hinge": return .deadlift
        case "Horizontal Push", "Vertical Push", "Chest Isolation", "Triceps": return .bench
        default: return nil
        }
    }
}

public struct ExerciseInfo: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let pattern: String
    public let split: String
    public let primary: [String]
    public let secondary: [String]
    public let cue: String
    public let equipment: String
    public let image: String?

    public init(id: String, name: String, pattern: String, split: String = "", primary: [String] = [],
                secondary: [String] = [], cue: String = "", equipment: String = "barbell", image: String? = nil) {
        self.id = id; self.name = name; self.pattern = pattern; self.split = split
        self.primary = primary; self.secondary = secondary; self.cue = cue
        self.equipment = equipment; self.image = image
    }
}

public struct MuscleInfo: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let region: String
    public let split: String
    public let role: String
    public let function: String
    public let examples: [String]
    public let patterns: [String]
    public let image: String?
}

public struct RIRLevel: Codable, Hashable, Sendable {
    public let title: String
    public let body: String
}

public struct ExerciseLibrary: Sendable {
    public let exercises: [ExerciseInfo]
    public let muscles: [MuscleInfo]
    public let rirGuide: [RIRLevel]
    private let byID: [String: ExerciseInfo]
    private let muscleByID: [String: MuscleInfo]

    public init(exercises: [ExerciseInfo], muscles: [MuscleInfo] = [], rirGuide: [RIRLevel] = []) {
        self.exercises = exercises
        self.muscles = muscles
        self.rirGuide = rirGuide
        self.byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.muscleByID = Dictionary(muscles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public static func load(exercisesJSON: Data, musclesJSON: Data, rirJSON: Data) throws -> ExerciseLibrary {
        let d = JSONDecoder()
        return ExerciseLibrary(exercises: try d.decode([ExerciseInfo].self, from: exercisesJSON),
                               muscles: try d.decode([MuscleInfo].self, from: musclesJSON),
                               rirGuide: try d.decode([RIRLevel].self, from: rirJSON))
    }

    public func exercise(_ id: String) -> ExerciseInfo? { byID[id] }
    public func muscle(_ id: String) -> MuscleInfo? { muscleByID[id] }
    public func name(for id: String) -> String { byID[id]?.name ?? id }
    public var patterns: [String] {
        var seen = Set<String>(); return exercises.compactMap { seen.insert($0.pattern).inserted ? $0.pattern : nil }
    }

    public func search(_ text: String, pattern: String? = nil, muscle: String? = nil) -> [ExerciseInfo] {
        exercises.filter { e in
            (pattern == nil || e.pattern == pattern) &&
            (muscle == nil || e.primary.contains(muscle!) || e.secondary.contains(muscle!)) &&
            (text.isEmpty || e.name.localizedCaseInsensitiveContains(text))
        }
    }

    /// Main lift that % prescriptions for this exercise are based on.
    public func referenceLift(for exerciseID: String) -> MainLift? {
        if let lift = MainLift.allCases.first(where: { $0.exerciseID == exerciseID }) { return lift }
        guard let e = byID[exerciseID] else { return nil }
        return MainLift.reference(forPattern: e.pattern)
    }
}

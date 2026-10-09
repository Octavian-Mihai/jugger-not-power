import Foundation

public enum PhaseKind: String, Codable, CaseIterable, Sendable {
    case hypertrophy, strength, peaking, general
    public var title: String { rawValue.capitalized }
}

public enum GoalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case powerlifting, powerbuilding, powerCombo, fullBody
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .powerlifting: return "Powerlifting"
        case .powerbuilding: return "Powerbuilding"
        case .powerCombo: return "PowerCombo"
        case .fullBody: return "Full Body"
        }
    }
    public var blurb: String {
        switch self {
        case .powerlifting: return "Peak squat, bench and deadlift through structured strength cycles."
        case .powerbuilding: return "Heavy main lifts plus bodybuilding volume for size."
        case .powerCombo: return "A hypertrophy phase followed by a strength phase."
        case .fullBody: return "Every session trains the whole body. Great for 2-4 days a week."
        }
    }
}

/// How one group of sets is prescribed.
public enum SetTarget: Codable, Hashable, Sendable {
    /// Fixed reps at a percentage of the reference lift's 1RM.
    case percent(pct: Double, reps: Int)
    /// Fixed reps, load chosen so that `rir` reps remain.
    case rir(reps: Int, rir: Double)
    /// Rep range with double progression, at an RIR target.
    case repRange(low: Int, high: Int, rir: Double)
    /// Fixed weight x reps entered by the lifter.
    case fixed(weight: Double, reps: Int)

    public var kindTitle: String {
        switch self {
        case .percent: return "% of 1RM"
        case .rir: return "RPE / RIR"
        case .repRange: return "Rep range"
        case .fixed: return "Fixed"
        }
    }
}

public struct SetGroup: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var count: Int
    public var target: SetTarget
    public init(count: Int, target: SetTarget) { self.count = count; self.target = target }
}

public struct PlannedExercise: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var exerciseID: String
    public var groups: [SetGroup]
    public var restSeconds: Int
    public var note: String
    /// Main lift whose 1RM % prescriptions use. nil = infer from the exercise.
    public var reference: MainLift?

    public init(exerciseID: String, groups: [SetGroup], restSeconds: Int = 120, note: String = "", reference: MainLift? = nil) {
        self.exerciseID = exerciseID; self.groups = groups
        self.restSeconds = restSeconds; self.note = note; self.reference = reference
    }
    public var totalSets: Int { groups.reduce(0) { $0 + $1.count } }
}

public struct PlannedDay: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var exercises: [PlannedExercise]
    /// A rest day has no exercises; it still takes a slot in the weekly rotation.
    public var isRest: Bool = false

    public init(name: String, exercises: [PlannedExercise] = [], isRest: Bool = false) {
        self.name = name; self.exercises = exercises; self.isRest = isRest
    }

    public static func rest(named name: String = "Rest day") -> PlannedDay { PlannedDay(name: name, exercises: [], isRest: true) }

    private enum CodingKeys: String, CodingKey { case id, name, exercises, isRest }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        exercises = try c.decode([PlannedExercise].self, forKey: .exercises)
        isRest = try c.decodeIfPresent(Bool.self, forKey: .isRest) ?? false
    }
}

public struct Block: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var phase: PhaseKind
    public var weeks: Int
    public var days: [PlannedDay]
    /// RIR targets shift linearly from `rirShiftStart` to `rirShiftEnd` across the working weeks.
    public var rirShiftStart: Double
    public var rirShiftEnd: Double
    /// Added to each % prescription per week.
    public var percentStep: Double
    public var deloadLastWeek: Bool

    public init(name: String, phase: PhaseKind, weeks: Int, days: [PlannedDay], rirShiftStart: Double = 0,
                rirShiftEnd: Double = 0, percentStep: Double = 0, deloadLastWeek: Bool = false) {
        self.name = name; self.phase = phase; self.weeks = weeks; self.days = days
        self.rirShiftStart = rirShiftStart; self.rirShiftEnd = rirShiftEnd
        self.percentStep = percentStep; self.deloadLastWeek = deloadLastWeek
    }
}

public struct ProgramPlan: Codable, Hashable, Sendable {
    public var name: String
    public var goal: GoalKind?          // nil = custom
    public var blocks: [Block]
    public init(name: String, goal: GoalKind? = nil, blocks: [Block]) {
        self.name = name; self.goal = goal; self.blocks = blocks
    }

    public var isCustom: Bool { goal == nil }
    public var totalWeeks: Int { blocks.reduce(0) { $0 + $1.weeks } }
    public var totalSessions: Int { blocks.reduce(0) { $0 + $1.weeks * $1.days.count } }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) throws -> ProgramPlan { try JSONDecoder().decode(ProgramPlan.self, from: data) }

    /// A copy that can be edited as a custom program.
    public func forkedAsCustom(named newName: String) -> ProgramPlan {
        var copy = self
        copy.name = newName
        copy.goal = nil
        return copy
    }
}

/// Where the lifter is in a plan after completing N sessions.
public struct PlanPosition: Hashable, Sendable {
    public let blockIndex: Int
    public let weekInBlock: Int   // 0-based
    public let dayIndex: Int
    public let weekOverall: Int   // 0-based
    public let isDeload: Bool
    public let isFinished: Bool
}

public extension ProgramPlan {
    func position(completedSessions n: Int) -> PlanPosition {
        var remaining = n
        var weekOverall = 0
        for (bi, block) in blocks.enumerated() {
            let perWeek = max(block.days.count, 1)
            let blockSessions = block.weeks * perWeek
            if remaining < blockSessions {
                let week = remaining / perWeek
                let day = remaining % perWeek
                return PlanPosition(blockIndex: bi, weekInBlock: week, dayIndex: day, weekOverall: weekOverall + week,
                                    isDeload: block.deloadLastWeek && week == block.weeks - 1 && block.weeks > 1,
                                    isFinished: false)
            }
            remaining -= blockSessions
            weekOverall += block.weeks
        }
        return PlanPosition(blockIndex: max(blocks.count - 1, 0), weekInBlock: 0, dayIndex: 0,
                            weekOverall: weekOverall, isDeload: false, isFinished: true)
    }
}

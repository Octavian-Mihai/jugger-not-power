import Foundation

public enum Experience: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct GeneratorInput: Sendable {
    public var goal: GoalKind
    public var daysPerWeek: Int
    public var experience: Experience
    /// Muscle ids to give extra weekly volume.
    public var emphasis: [String]
    public var name: String?
    public init(goal: GoalKind, daysPerWeek: Int, experience: Experience = .intermediate,
                emphasis: [String] = [], name: String? = nil) {
        self.goal = goal; self.daysPerWeek = min(max(daysPerWeek, 2), 6)
        self.experience = experience; self.emphasis = emphasis; self.name = name
    }
}

public struct ProgramGenerator {
    public let library: ExerciseLibrary
    public init(library: ExerciseLibrary) { self.library = library }

    // MARK: Schemes

    private enum MainScheme {
        case percent(sets: Int, reps: Int, pct: Double)
        case rir(sets: Int, reps: Int, rir: Double)
        case range(sets: Int, low: Int, high: Int, rir: Double)
    }

    private enum Item {
        case main(String)                         // the day's primary lift
        case secondary(String)                    // variation / second compound
        case accessory([String], sets: Int, low: Int, high: Int)
    }

    private struct DaySpec { var name: String; var items: [Item] }

    private func pick(_ ids: [String]) -> String? { ids.first { library.exercise($0) != nil } }

    private func build(_ spec: DaySpec, scheme: MainScheme, accessoryLimit: Int, extraSets: Int, secondaryRIR: Double) -> PlannedDay {
        var out: [PlannedExercise] = []
        var accCount = 0
        for item in spec.items {
            switch item {
            case .main(let id):
                guard let id = pick([id]) else { continue }
                let target: SetTarget; var sets: Int
                switch scheme {
                case .percent(let s, let r, let p): target = .percent(pct: p, reps: r); sets = s
                case .rir(let s, let r, let rir): target = .rir(reps: r, rir: rir); sets = s
                case .range(let s, let lo, let hi, let rir): target = .repRange(low: lo, high: hi, rir: rir); sets = s
                }
                out.append(PlannedExercise(exerciseID: id, groups: [SetGroup(count: sets, target: target)], restSeconds: 180))
            case .secondary(let id):
                guard let id = pick([id]) else { continue }
                out.append(PlannedExercise(exerciseID: id,
                                           groups: [SetGroup(count: 3, target: .repRange(low: 6, high: 10, rir: secondaryRIR))],
                                           restSeconds: 150))
            case .accessory(let ids, let sets, let lo, let hi):
                guard accCount < accessoryLimit, let id = pick(ids) else { continue }
                accCount += 1
                out.append(PlannedExercise(exerciseID: id,
                                           groups: [SetGroup(count: max(sets + extraSets, 2), target: .repRange(low: lo, high: hi, rir: 2))],
                                           restSeconds: 90))
            }
        }
        return PlannedDay(name: spec.name, exercises: out)
    }

    // MARK: Day catalogue

    private var squatDay: DaySpec { DaySpec(name: "Squat", items: [
        .main("back-squat"), .secondary("front-squat"),
        .accessory(["lying-leg-curl", "seated-leg-curl"], sets: 3, low: 8, high: 12),
        .accessory(["leg-press", "hack-squat"], sets: 3, low: 8, high: 12),
        .accessory(["hanging-leg-raise", "cable-crunch"], sets: 3, low: 10, high: 15),
        .accessory(["calf-raise"], sets: 3, low: 10, high: 15)]) }

    private var benchDay: DaySpec { DaySpec(name: "Bench", items: [
        .main("barbell-bench-press"), .secondary("close-grip-bench-press"),
        .accessory(["chest-supported-dumbbell-row", "one-arm-dumbbell-row"], sets: 3, low: 8, high: 12),
        .accessory(["incline-dumbbell-press"], sets: 3, low: 8, high: 12),
        .accessory(["lateral-raise"], sets: 3, low: 12, high: 15),
        .accessory(["tricep-pushdown", "skull-crusher"], sets: 3, low: 10, high: 15)]) }

    private var deadliftDay: DaySpec { DaySpec(name: "Deadlift", items: [
        .main("deadlift"), .secondary("romanian-deadlift"),
        .accessory(["lat-pulldown", "pull-up"], sets: 3, low: 8, high: 12),
        .accessory(["seated-cable-row", "barbell-row"], sets: 3, low: 8, high: 12),
        .accessory(["back-extension"], sets: 3, low: 10, high: 15),
        .accessory(["dumbbell-curl", "barbell-curl"], sets: 3, low: 10, high: 15)]) }

    private var upperVolumeDay: DaySpec { DaySpec(name: "Upper Volume", items: [
        .secondary("overhead-press"),
        .accessory(["incline-dumbbell-press"], sets: 3, low: 8, high: 12),
        .accessory(["chest-supported-t-bar-row", "machine-row"], sets: 3, low: 8, high: 12),
        .accessory(["lat-pulldown"], sets: 3, low: 8, high: 12),
        .accessory(["lateral-raise"], sets: 3, low: 12, high: 15),
        .accessory(["overhead-cable-triceps-extension", "tricep-pushdown"], sets: 3, low: 10, high: 15),
        .accessory(["hammer-curl", "dumbbell-curl"], sets: 3, low: 10, high: 15)]) }

    private var lowerVolumeDay: DaySpec { DaySpec(name: "Lower Volume", items: [
        .secondary("leg-press"),
        .accessory(["romanian-deadlift"], sets: 3, low: 8, high: 12),
        .accessory(["bulgarian-split-squat", "walking-lunge"], sets: 3, low: 8, high: 12),
        .accessory(["lying-leg-curl", "seated-leg-curl"], sets: 3, low: 8, high: 12),
        .accessory(["leg-extension"], sets: 3, low: 10, high: 15),
        .accessory(["calf-raise"], sets: 4, low: 10, high: 15)]) }

    private var benchVolumeDay: DaySpec { DaySpec(name: "Bench Volume", items: [
        .secondary("barbell-bench-press"),
        .accessory(["pull-up", "lat-pulldown"], sets: 3, low: 6, high: 10),
        .accessory(["dumbbell-shoulder-press", "machine-shoulder-press"], sets: 3, low: 8, high: 12),
        .accessory(["cable-fly", "pec-deck"], sets: 3, low: 10, high: 15),
        .accessory(["face-pull", "rear-delt-fly"], sets: 3, low: 12, high: 20)]) }

    private func fullBodyDays(count: Int) -> [DaySpec] {
        let a = DaySpec(name: "Full Body A", items: [
            .main("back-squat"), .secondary("barbell-bench-press"),
            .accessory(["barbell-row", "seated-cable-row"], sets: 3, low: 8, high: 12),
            .accessory(["lateral-raise"], sets: 3, low: 12, high: 15),
            .accessory(["hanging-leg-raise", "cable-crunch"], sets: 3, low: 10, high: 15)])
        let b = DaySpec(name: "Full Body B", items: [
            .main("deadlift"), .secondary("overhead-press"),
            .accessory(["lat-pulldown", "pull-up"], sets: 3, low: 8, high: 12),
            .accessory(["leg-extension", "leg-press"], sets: 3, low: 10, high: 15),
            .accessory(["dumbbell-curl"], sets: 2, low: 10, high: 15),
            .accessory(["tricep-pushdown"], sets: 2, low: 10, high: 15)])
        let c = DaySpec(name: "Full Body C", items: [
            .secondary("front-squat"), .secondary("incline-dumbbell-press"),
            .accessory(["chest-supported-dumbbell-row", "machine-row"], sets: 3, low: 8, high: 12),
            .accessory(["romanian-deadlift"], sets: 3, low: 8, high: 12),
            .accessory(["face-pull", "rear-delt-fly"], sets: 3, low: 12, high: 20),
            .accessory(["calf-raise"], sets: 3, low: 10, high: 15)])
        let d = DaySpec(name: "Full Body D", items: [
            .main("barbell-bench-press"), .secondary("trap-bar-deadlift"),
            .accessory(["one-arm-cable-row", "one-arm-dumbbell-row"], sets: 3, low: 8, high: 12),
            .accessory(["bulgarian-split-squat", "walking-lunge"], sets: 3, low: 8, high: 12),
            .accessory(["cable-lateral-raise", "lateral-raise"], sets: 3, low: 12, high: 15),
            .accessory(["plank", "ab-wheel"], sets: 3, low: 30, high: 60)])
        let cycle = [a, b, c, d]
        return (0..<count).map { cycle[$0 % cycle.count] }
    }

    private func powerDays(count: Int) -> [DaySpec] {
        switch count {
        case 2:
            var d1 = squatDay; d1.name = "Squat & Bench"
            d1.items = [.main("back-squat"), .accessory(["lying-leg-curl"], sets: 3, low: 8, high: 12),
                        .secondary("barbell-bench-press"), .accessory(["chest-supported-dumbbell-row"], sets: 3, low: 8, high: 12)]
            var d2 = deadliftDay; d2.name = "Deadlift & Press"
            d2.items = [.main("deadlift"), .accessory(["lat-pulldown"], sets: 3, low: 8, high: 12),
                        .secondary("overhead-press"), .accessory(["tricep-pushdown"], sets: 3, low: 10, high: 15)]
            return [d1, d2]
        case 3: return [squatDay, benchDay, deadliftDay]
        case 4: return [squatDay, benchDay, deadliftDay, upperVolumeDay]
        case 5: return [squatDay, benchDay, deadliftDay, upperVolumeDay, lowerVolumeDay]
        default: return [squatDay, benchDay, deadliftDay, upperVolumeDay, lowerVolumeDay, benchVolumeDay]
        }
    }

    // MARK: Blocks

    private func days(_ specs: [DaySpec], scheme: MainScheme, accessoryLimit: Int, extraSets: Int, secondaryRIR: Double) -> [PlannedDay] {
        specs.map { build($0, scheme: scheme, accessoryLimit: accessoryLimit, extraSets: extraSets, secondaryRIR: secondaryRIR) }
    }

    public func generate(_ input: GeneratorInput) -> ProgramPlan {
        let specs = input.goal == .fullBody ? fullBodyDays(count: input.daysPerWeek) : powerDays(count: input.daysPerWeek)
        let extra = input.experience == .advanced ? 1 : (input.experience == .beginner ? -1 : 0)
        let beginnerOffset = input.experience == .beginner ? -0.05 : 0

        func block(_ name: String, _ phase: PhaseKind, weeks: Int, scheme: MainScheme, accLimit: Int,
                   rirStart: Double = 0, rirEnd: Double = 0, step: Double = 0, deload: Bool = false, secondaryRIR: Double = 2) -> Block {
            Block(name: name, phase: phase, weeks: weeks,
                  days: days(specs, scheme: scheme, accessoryLimit: accLimit, extraSets: extra, secondaryRIR: secondaryRIR),
                  rirShiftStart: rirStart, rirShiftEnd: rirEnd, percentStep: step, deloadLastWeek: deload)
        }

        var blocks: [Block]
        switch input.goal {
        case .powerlifting:
            blocks = [
                block("Accumulation", .hypertrophy, weeks: 4, scheme: .percent(sets: 4, reps: 6, pct: 0.70 + beginnerOffset), accLimit: 3, step: 0.025, deload: true),
                block("Intensification", .strength, weeks: 4, scheme: .percent(sets: 4, reps: 4, pct: 0.80 + beginnerOffset), accLimit: 2, step: 0.025, deload: true),
            ]
            if input.experience != .beginner {
                blocks.append(block("Peaking", .peaking, weeks: 3, scheme: .percent(sets: 3, reps: 2, pct: 0.88), accLimit: 1, step: 0.02))
            }
        case .powerbuilding:
            blocks = [
                block("Hypertrophy", .hypertrophy, weeks: 4, scheme: .range(sets: 4, low: 6, high: 10, rir: 3), accLimit: 5, rirStart: 0, rirEnd: -1, deload: true),
                block("Strength", .strength, weeks: 4, scheme: .rir(sets: 4, reps: 5, rir: 3), accLimit: 4, rirStart: 0, rirEnd: -1, deload: true),
                block("Intensity", .peaking, weeks: 3, scheme: .rir(sets: 3, reps: 3, rir: 2), accLimit: 3, rirStart: 0, rirEnd: -1),
            ]
        case .powerCombo:
            blocks = [
                block("Hypertrophy Phase", .hypertrophy, weeks: 6, scheme: .range(sets: 4, low: 8, high: 12, rir: 3), accLimit: 5, rirStart: 0, rirEnd: -2, deload: true),
                block("Strength Phase", .strength, weeks: 6, scheme: .percent(sets: 4, reps: 5, pct: 0.75 + beginnerOffset), accLimit: 3, step: 0.02, deload: true),
            ]
        case .fullBody:
            blocks = [
                block("Volume", .hypertrophy, weeks: 6, scheme: .range(sets: 3, low: 6, high: 10, rir: 3), accLimit: 5, rirStart: 0, rirEnd: -1, deload: true),
                block("Strength", .strength, weeks: 6, scheme: .rir(sets: 4, reps: 5, rir: 3), accLimit: 5, rirStart: 0, rirEnd: -1, deload: true),
            ]
        }

        applyEmphasis(input.emphasis, to: &blocks)
        let name = input.name ?? "\(input.goal.title) · \(input.daysPerWeek) days"
        return ProgramPlan(name: name, goal: input.goal, blocks: blocks)
    }

    /// Adds an isolation exercise for each emphasised muscle onto two different days.
    private func applyEmphasis(_ muscles: [String], to blocks: inout [Block]) {
        for muscle in muscles {
            let candidates = library.exercises.filter {
                $0.primary.first == muscle && ["Biceps", "Triceps", "Delt Isolation", "Chest Isolation", "Knee Flexion",
                    "Knee Extension", "Glute Isolation", "Other Isolation", "Accessory", "Vertical Pull", "Horizontal Pull", "Flexion"].contains($0.pattern)
            }
            guard let ex = candidates.first else { continue }
            for bi in blocks.indices {
                let n = blocks[bi].days.count
                guard n > 0 else { continue }
                let targets = n >= 4 ? [0, n / 2] : [0, n - 1]
                for di in Set(targets) where !blocks[bi].days[di].exercises.contains(where: { $0.exerciseID == ex.id }) {
                    blocks[bi].days[di].exercises.append(
                        PlannedExercise(exerciseID: ex.id, groups: [SetGroup(count: 3, target: .repRange(low: 10, high: 15, rir: 1))],
                                        restSeconds: 75, note: "Emphasis"))
                }
            }
        }
    }
}

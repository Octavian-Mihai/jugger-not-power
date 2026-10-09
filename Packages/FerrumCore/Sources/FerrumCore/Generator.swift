import Foundation

public enum Experience: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Everything the questionnaire collects.
public struct GeneratorInput: Sendable {
    public var goal: GoalKind
    public var daysPerWeek: Int
    public var experience: Experience
    /// Muscle ids to give extra weekly volume.
    public var emphasis: [String]
    public var name: String?
    /// Target session length. nil = no limit.
    public var sessionMinutes: Int?
    /// Equipment ids available (see `ProgramGenerator.equipmentOptions`). Empty = everything. Bodyweight is always allowed.
    public var equipment: Set<String>
    /// Exercises the lifter enjoys; each is worked into the week when it fits.
    public var favorites: Set<String>
    /// Exercises that must never appear.
    public var dislikes: Set<String>
    /// Movement patterns to avoid entirely (e.g. "Vertical Push").
    public var avoidPatterns: Set<String>

    public init(goal: GoalKind, daysPerWeek: Int, experience: Experience = .intermediate, emphasis: [String] = [],
                name: String? = nil, sessionMinutes: Int? = nil, equipment: Set<String> = [],
                favorites: Set<String> = [], dislikes: Set<String> = [], avoidPatterns: Set<String> = []) {
        self.goal = goal; self.daysPerWeek = min(max(daysPerWeek, 2), 6)
        self.experience = experience; self.emphasis = emphasis; self.name = name
        self.sessionMinutes = sessionMinutes; self.equipment = equipment
        self.favorites = favorites; self.dislikes = dislikes; self.avoidPatterns = avoidPatterns
    }
}

public extension PlannedDay {
    /// Rough session length: warm-up plus (set time + rest) for every set.
    var estimatedMinutes: Int {
        let seconds = exercises.reduce(0) { $0 + $1.totalSets * (40 + $1.restSeconds) }
        return 5 + Int((Double(seconds) / 60).rounded())
    }
}

public struct ProgramGenerator {
    public let library: ExerciseLibrary
    public init(library: ExerciseLibrary) { self.library = library }

    public static let equipmentOptions: [(id: String, title: String)] = [
        ("barbell", "Barbell & plates"), ("dumbbell", "Dumbbells"), ("cable", "Cable station"), ("machine", "Machines"),
        ("smith machine", "Smith machine"), ("kettlebell", "Kettlebells"), ("landmine", "Landmine"),
        ("trap bar", "Trap bar"), ("safety bar", "Safety squat bar"), ("band", "Bands"),
    ]

    /// Equipment that never needs to be asked about.
    private static let alwaysAvailable: Set<String> = ["bodyweight", "gripper", "ab wheel"]

    // MARK: Schemes

    private enum MainScheme {
        case percent(sets: Int, reps: Int, pct: Double)
        case rir(sets: Int, reps: Int, rir: Double)
        case range(sets: Int, low: Int, high: Int, rir: Double)
    }

    private enum Item {
        case main([String])                       // preference chain for the day's primary lift
        case secondary([String])                  // variation / second compound
        case accessory([String], muscle: String, sets: Int, low: Int, high: Int)
    }

    private struct DaySpec { var name: String; var items: [Item] }

    /// Collects human-readable notes about substitutions.
    private final class Report { var notes: [String] = [] }

    // MARK: Filtering

    private struct Filter {
        let library: ExerciseLibrary
        let input: GeneratorInput

        func allowed(_ id: String) -> Bool {
            guard let e = library.exercise(id) else { return false }
            if input.dislikes.contains(id) || input.avoidPatterns.contains(e.pattern) { return false }
            if input.equipment.isEmpty { return true }
            return input.equipment.contains(e.equipment) || ProgramGenerator.alwaysAvailable.contains(e.equipment)
        }

        /// First allowed id from the chain, favouring liked exercises that train the same muscle.
        func pick(_ chain: [String], muscle: String? = nil) -> String? {
            var candidates = chain.filter(allowed)
            if let muscle {
                let mains = Set(MainLift.allCases.map(\.exerciseID))
                let extra = library.exercises.filter { $0.primary.first == muscle && !mains.contains($0.id) && allowed($0.id) }.map(\.id)
                candidates += extra.filter { !candidates.contains($0) }
                if let fav = candidates.first(where: { input.favorites.contains($0) }) { return fav }
            }
            return candidates.first
        }
    }

    // MARK: Day building

    private func build(_ spec: DaySpec, scheme: MainScheme, accessoryLimit: Int, extraSets: Int, secondaryRIR: Double,
                       filter: Filter, report: Report) -> (day: PlannedDay, core: [Bool]) {
        var out: [PlannedExercise] = []
        var core: [Bool] = []
        var accCount = 0
        for item in spec.items {
            switch item {
            case .main(let chain):
                guard let id = filter.pick(chain) else { continue }
                let canonical = MainLift.allCases.contains { $0.exerciseID == id }
                if id != chain[0] {
                    report.notes.append("\(library.name(for: chain[0])) swapped for \(library.name(for: id)) based on your equipment and exercise choices.")
                }
                var target: SetTarget; var sets: Int
                switch scheme {
                case .percent(let s, let r, let p): target = .percent(pct: p, reps: r); sets = s
                case .rir(let s, let r, let rir): target = .rir(reps: r, rir: rir); sets = s
                case .range(let s, let lo, let hi, let rir): target = .repRange(low: lo, high: hi, rir: rir); sets = s
                }
                // Percentages and RIR targets are only meaningful against the real main lift.
                if !canonical {
                    switch target {
                    case .percent(_, let r): target = .repRange(low: r, high: r + 3, rir: 2)
                    case .rir(let r, let rir): target = .repRange(low: r, high: r + 3, rir: rir)
                    default: break
                    }
                }
                out.append(PlannedExercise(exerciseID: id, groups: [SetGroup(count: sets, target: target)], restSeconds: 180))
                core.append(true)
            case .secondary(let chain):
                guard let id = filter.pick(chain) else { continue }
                out.append(PlannedExercise(exerciseID: id,
                                           groups: [SetGroup(count: 3, target: .repRange(low: 6, high: 10, rir: secondaryRIR))],
                                           restSeconds: 150))
                core.append(true)
            case .accessory(let chain, let muscle, let sets, let lo, let hi):
                guard accCount < accessoryLimit, let id = filter.pick(chain, muscle: muscle),
                      !out.contains(where: { $0.exerciseID == id }) else { continue }
                accCount += 1
                out.append(PlannedExercise(exerciseID: id,
                                           groups: [SetGroup(count: max(sets + extraSets, 2), target: .repRange(low: lo, high: hi, rir: 2))],
                                           restSeconds: 90))
                core.append(false)
            }
        }
        return (PlannedDay(name: spec.name, exercises: out), core)
    }

    /// Trim a day to the time budget: drop accessories from the end, then shave sets.
    private func fit(_ day: PlannedDay, core: [Bool], minutes: Int?) -> PlannedDay {
        guard let minutes else { return day }
        var day = day
        var core = core
        var guardCount = 0
        while day.estimatedMinutes > minutes, let idx = core.lastIndex(of: false), guardCount < 50 {
            day.exercises.remove(at: idx); core.remove(at: idx); guardCount += 1
        }
        while day.estimatedMinutes > minutes, guardCount < 100 {
            guardCount += 1
            guard let i = day.exercises.indices.max(by: { day.exercises[$0].totalSets < day.exercises[$1].totalSets }),
                  day.exercises[i].totalSets > 2,
                  let g = day.exercises[i].groups.indices.last(where: { day.exercises[i].groups[$0].count > 1 }) else { break }
            day.exercises[i].groups[g].count -= 1
        }
        return day
    }

    private func isLowerDay(_ d: PlannedDay) -> Bool {
        guard let first = d.exercises.first, let e = library.exercise(first.exerciseID) else { return false }
        return ["Squat", "Lunge / Split", "Hinge", "Knee Flexion", "Knee Extension", "Glute Isolation"].contains(e.pattern)
    }

    /// Make sure every liked exercise shows up once a week on a day that suits it.
    private func addFavorites(_ days: inout [(day: PlannedDay, core: [Bool])], filter: Filter) {
        let used = Set(days.flatMap { $0.day.exercises.map(\.exerciseID) })
        for id in filter.input.favorites.sorted() where !used.contains(id) && filter.allowed(id) {
            guard let e = library.exercise(id) else { continue }
            let lower = ["Squat", "Lunge / Split", "Hinge", "Knee Flexion", "Knee Extension", "Glute Isolation"].contains(e.pattern)
                || (e.pattern == "Other Isolation" && e.primary.first == "calves")
            let matching = days.indices.filter { isLowerDay(days[$0].day) == lower }
            let pool = matching.isEmpty ? Array(days.indices) : matching
            guard let target = pool.min(by: { days[$0].day.exercises.count < days[$1].day.exercises.count }) else { continue }
            days[target].day.exercises.append(PlannedExercise(
                exerciseID: id, groups: [SetGroup(count: 3, target: .repRange(low: 8, high: 12, rir: 2))], restSeconds: 90, note: "Favourite"))
            days[target].core.append(false)
        }
    }

    // MARK: Day catalogue

    private var squatDay: DaySpec { DaySpec(name: "Squat", items: [
        .main(["back-squat", "safety-bar-squat", "front-squat", "smith-machine-squat", "hack-squat", "leg-press", "goblet-squat", "sissy-squat"]),
        .secondary(["front-squat", "hack-squat", "leg-press", "goblet-squat", "bulgarian-split-squat"]),
        .accessory(["lying-leg-curl", "seated-leg-curl", "nordic-curl"], muscle: "hamstrings", sets: 3, low: 8, high: 12),
        .accessory(["leg-press", "hack-squat", "leg-extension"], muscle: "quadriceps", sets: 3, low: 8, high: 12),
        .accessory(["hanging-leg-raise", "cable-crunch", "plank"], muscle: "core-and-abs", sets: 3, low: 10, high: 15),
        .accessory(["calf-raise"], muscle: "calves", sets: 3, low: 10, high: 15)]) }

    private var benchDay: DaySpec { DaySpec(name: "Bench", items: [
        .main(["barbell-bench-press", "dumbbell-bench-press", "smith-machine-bench-press", "machine-chest-press", "push-up"]),
        .secondary(["close-grip-bench-press", "incline-dumbbell-press", "dips", "push-up"]),
        .accessory(["chest-supported-dumbbell-row", "one-arm-dumbbell-row", "machine-row", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
        .accessory(["incline-dumbbell-press", "machine-press", "push-up"], muscle: "chest-pectorals", sets: 3, low: 8, high: 12),
        .accessory(["lateral-raise", "cable-lateral-raise"], muscle: "lateral-delts", sets: 3, low: 12, high: 15),
        .accessory(["tricep-pushdown", "skull-crusher", "dips"], muscle: "triceps", sets: 3, low: 10, high: 15)]) }

    private var deadliftDay: DaySpec { DaySpec(name: "Deadlift", items: [
        .main(["deadlift", "trap-bar-deadlift", "sumo-deadlift", "romanian-deadlift", "single-leg-romanian-deadlift", "back-extension"]),
        .secondary(["romanian-deadlift", "single-leg-romanian-deadlift", "good-morning", "back-extension"]),
        .accessory(["lat-pulldown", "pull-up", "assisted-pull-up", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
        .accessory(["seated-cable-row", "barbell-row", "one-arm-dumbbell-row", "inverted-row"], muscle: "rhomboids", sets: 3, low: 8, high: 12),
        .accessory(["back-extension"], muscle: "erectors", sets: 3, low: 10, high: 15),
        .accessory(["dumbbell-curl", "barbell-curl", "cable-curl"], muscle: "biceps", sets: 3, low: 10, high: 15)]) }

    private var upperVolumeDay: DaySpec { DaySpec(name: "Upper Volume", items: [
        .secondary(["overhead-press", "dumbbell-shoulder-press", "machine-shoulder-press", "landmine-press", "push-up"]),
        .accessory(["incline-dumbbell-press", "machine-press", "push-up"], muscle: "chest-pectorals", sets: 3, low: 8, high: 12),
        .accessory(["chest-supported-t-bar-row", "machine-row", "one-arm-dumbbell-row", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
        .accessory(["lat-pulldown", "pull-up", "assisted-pull-up"], muscle: "lats", sets: 3, low: 8, high: 12),
        .accessory(["lateral-raise", "cable-lateral-raise"], muscle: "lateral-delts", sets: 3, low: 12, high: 15),
        .accessory(["overhead-cable-triceps-extension", "tricep-pushdown", "skull-crusher", "dips"], muscle: "triceps", sets: 3, low: 10, high: 15),
        .accessory(["hammer-curl", "dumbbell-curl", "cable-curl"], muscle: "biceps", sets: 3, low: 10, high: 15)]) }

    private var lowerVolumeDay: DaySpec { DaySpec(name: "Lower Volume", items: [
        .secondary(["leg-press", "hack-squat", "goblet-squat", "bulgarian-split-squat", "sissy-squat"]),
        .accessory(["romanian-deadlift", "single-leg-romanian-deadlift", "back-extension"], muscle: "hamstrings", sets: 3, low: 8, high: 12),
        .accessory(["bulgarian-split-squat", "walking-lunge", "step-up", "reverse-lunge"], muscle: "quadriceps", sets: 3, low: 8, high: 12),
        .accessory(["lying-leg-curl", "seated-leg-curl", "nordic-curl"], muscle: "hamstrings", sets: 3, low: 8, high: 12),
        .accessory(["leg-extension"], muscle: "quadriceps", sets: 3, low: 10, high: 15),
        .accessory(["calf-raise"], muscle: "calves", sets: 4, low: 10, high: 15)]) }

    private var benchVolumeDay: DaySpec { DaySpec(name: "Bench Volume", items: [
        .secondary(["barbell-bench-press", "dumbbell-bench-press", "machine-chest-press", "push-up"]),
        .accessory(["pull-up", "lat-pulldown", "assisted-pull-up", "inverted-row"], muscle: "lats", sets: 3, low: 6, high: 10),
        .accessory(["dumbbell-shoulder-press", "machine-shoulder-press", "overhead-press"], muscle: "anterior-delts", sets: 3, low: 8, high: 12),
        .accessory(["cable-fly", "pec-deck", "dumbbell-fly"], muscle: "chest-pectorals", sets: 3, low: 10, high: 15),
        .accessory(["face-pull", "rear-delt-fly", "reverse-pec-deck"], muscle: "posterior-delts", sets: 3, low: 12, high: 20)]) }

    private func fullBodyDays(count: Int) -> [DaySpec] {
        let a = DaySpec(name: "Full Body A", items: [
            .main(["back-squat", "safety-bar-squat", "smith-machine-squat", "hack-squat", "leg-press", "goblet-squat", "sissy-squat"]),
            .secondary(["barbell-bench-press", "dumbbell-bench-press", "machine-chest-press", "push-up"]),
            .accessory(["barbell-row", "seated-cable-row", "machine-row", "one-arm-dumbbell-row", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
            .accessory(["lateral-raise", "cable-lateral-raise"], muscle: "lateral-delts", sets: 3, low: 12, high: 15),
            .accessory(["hanging-leg-raise", "cable-crunch", "plank"], muscle: "core-and-abs", sets: 3, low: 10, high: 15)])
        let b = DaySpec(name: "Full Body B", items: [
            .main(["deadlift", "trap-bar-deadlift", "romanian-deadlift", "single-leg-romanian-deadlift", "back-extension"]),
            .secondary(["overhead-press", "dumbbell-shoulder-press", "machine-shoulder-press", "landmine-press", "push-up"]),
            .accessory(["lat-pulldown", "pull-up", "assisted-pull-up", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
            .accessory(["leg-extension", "leg-press", "bulgarian-split-squat"], muscle: "quadriceps", sets: 3, low: 10, high: 15),
            .accessory(["dumbbell-curl", "cable-curl", "barbell-curl"], muscle: "biceps", sets: 2, low: 10, high: 15),
            .accessory(["tricep-pushdown", "skull-crusher", "dips"], muscle: "triceps", sets: 2, low: 10, high: 15)])
        let c = DaySpec(name: "Full Body C", items: [
            .secondary(["front-squat", "hack-squat", "leg-press", "goblet-squat", "bulgarian-split-squat"]),
            .secondary(["incline-dumbbell-press", "machine-press", "dips", "push-up"]),
            .accessory(["chest-supported-dumbbell-row", "machine-row", "one-arm-dumbbell-row", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
            .accessory(["romanian-deadlift", "single-leg-romanian-deadlift", "back-extension"], muscle: "hamstrings", sets: 3, low: 8, high: 12),
            .accessory(["face-pull", "rear-delt-fly", "reverse-pec-deck"], muscle: "posterior-delts", sets: 3, low: 12, high: 20),
            .accessory(["calf-raise"], muscle: "calves", sets: 3, low: 10, high: 15)])
        let d = DaySpec(name: "Full Body D", items: [
            .main(["barbell-bench-press", "dumbbell-bench-press", "smith-machine-bench-press", "machine-chest-press", "push-up"]),
            .secondary(["trap-bar-deadlift", "romanian-deadlift", "single-leg-romanian-deadlift", "back-extension"]),
            .accessory(["one-arm-cable-row", "one-arm-dumbbell-row", "machine-row", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
            .accessory(["bulgarian-split-squat", "walking-lunge", "step-up", "reverse-lunge"], muscle: "quadriceps", sets: 3, low: 8, high: 12),
            .accessory(["cable-lateral-raise", "lateral-raise"], muscle: "lateral-delts", sets: 3, low: 12, high: 15),
            .accessory(["plank", "ab-wheel"], muscle: "core-and-abs", sets: 3, low: 30, high: 60)])
        let cycle = [a, b, c, d]
        return (0..<count).map { cycle[$0 % cycle.count] }
    }

    private func powerDays(count: Int) -> [DaySpec] {
        switch count {
        case 2:
            var d1 = squatDay; d1.name = "Squat & Bench"
            d1.items = [squatDay.items[0],
                        .accessory(["lying-leg-curl", "seated-leg-curl", "nordic-curl"], muscle: "hamstrings", sets: 3, low: 8, high: 12),
                        .secondary(["barbell-bench-press", "dumbbell-bench-press", "machine-chest-press", "push-up"]),
                        .accessory(["chest-supported-dumbbell-row", "one-arm-dumbbell-row", "machine-row", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12)]
            var d2 = deadliftDay; d2.name = "Deadlift & Press"
            d2.items = [deadliftDay.items[0],
                        .accessory(["lat-pulldown", "pull-up", "assisted-pull-up", "inverted-row"], muscle: "lats", sets: 3, low: 8, high: 12),
                        .secondary(["overhead-press", "dumbbell-shoulder-press", "machine-shoulder-press", "push-up"]),
                        .accessory(["tricep-pushdown", "skull-crusher", "dips"], muscle: "triceps", sets: 3, low: 10, high: 15)]
            return [d1, d2]
        case 3: return [squatDay, benchDay, deadliftDay]
        case 4: return [squatDay, benchDay, deadliftDay, upperVolumeDay]
        case 5: return [squatDay, benchDay, deadliftDay, upperVolumeDay, lowerVolumeDay]
        default: return [squatDay, benchDay, deadliftDay, upperVolumeDay, lowerVolumeDay, benchVolumeDay]
        }
    }

    // MARK: Generate

    public func generate(_ input: GeneratorInput) -> ProgramPlan { generateWithNotes(input).plan }

    public func generateWithNotes(_ input: GeneratorInput) -> (plan: ProgramPlan, notes: [String]) {
        let specs = input.goal == .fullBody ? fullBodyDays(count: input.daysPerWeek) : powerDays(count: input.daysPerWeek)
        let extra = input.experience == .advanced ? 1 : (input.experience == .beginner ? -1 : 0)
        let beginnerOffset = input.experience == .beginner ? -0.05 : 0
        let filter = Filter(library: library, input: input)
        let report = Report()

        func block(_ name: String, _ phase: PhaseKind, weeks: Int, scheme: MainScheme, accLimit: Int,
                   rirStart: Double = 0, rirEnd: Double = 0, step: Double = 0, deload: Bool = false, secondaryRIR: Double = 2) -> Block {
            var built = specs.map { build($0, scheme: scheme, accessoryLimit: accLimit, extraSets: extra,
                                          secondaryRIR: secondaryRIR, filter: filter, report: report) }
            addFavorites(&built, filter: filter)
            let days = built.map { fit($0.day, core: $0.core, minutes: input.sessionMinutes) }
            return Block(name: name, phase: phase, weeks: weeks, days: days,
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

        applyEmphasis(input.emphasis, to: &blocks, filter: filter, minutes: input.sessionMinutes)
        let name = input.name ?? "\(input.goal.title) · \(input.daysPerWeek) days"
        var notes: [String] = []
        for n in report.notes where !notes.contains(n) { notes.append(n) }
        return (ProgramPlan(name: name, goal: input.goal, blocks: blocks), notes)
    }

    /// Adds an isolation exercise for each emphasised muscle onto two different days (if time allows).
    private func applyEmphasis(_ muscles: [String], to blocks: inout [Block], filter: Filter, minutes: Int?) {
        let isolation: Set<String> = ["Biceps", "Triceps", "Delt Isolation", "Chest Isolation", "Knee Flexion", "Knee Extension",
                                      "Glute Isolation", "Other Isolation", "Accessory", "Vertical Pull", "Horizontal Pull", "Flexion"]
        for muscle in muscles {
            let candidates = library.exercises.filter { $0.primary.first == muscle && isolation.contains($0.pattern) && filter.allowed($0.id) }
            guard let ex = candidates.first(where: { filter.input.favorites.contains($0.id) }) ?? candidates.first else { continue }
            for bi in blocks.indices {
                let n = blocks[bi].days.count
                guard n > 0 else { continue }
                let targets = n >= 4 ? [0, n / 2] : [0, n - 1]
                for di in Set(targets) where !blocks[bi].days[di].exercises.contains(where: { $0.exerciseID == ex.id }) {
                    var day = blocks[bi].days[di]
                    day.exercises.append(PlannedExercise(exerciseID: ex.id,
                        groups: [SetGroup(count: 3, target: .repRange(low: 10, high: 15, rir: 1))], restSeconds: 75, note: "Emphasis"))
                    if let minutes, day.estimatedMinutes > minutes { continue }
                    blocks[bi].days[di] = day
                }
            }
        }
    }
}

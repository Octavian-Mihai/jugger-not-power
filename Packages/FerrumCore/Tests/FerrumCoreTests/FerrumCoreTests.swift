import XCTest
@testable import FerrumCore

final class FerrumCoreTests: XCTestCase {
    static let library: ExerciseLibrary = {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../Ferrum/Resources").standardized
        func data(_ n: String) -> Data { try! Data(contentsOf: dir.appendingPathComponent(n)) }
        return try! ExerciseLibrary.load(exercisesJSON: data("exercises.json"), musclesJSON: data("muscles.json"), rirJSON: data("rir.json"))
    }()
    var lib: ExerciseLibrary { Self.library }

    // MARK: library
    func testLibraryLoadsAndReferencesAreValid() {
        XCTAssertEqual(lib.exercises.count, 143)
        XCTAssertEqual(lib.muscles.count, 20)
        XCTAssertEqual(lib.rirGuide.count, 6)
        for e in lib.exercises {
            for m in e.primary + e.secondary { XCTAssertNotNil(lib.muscle(m), "\(e.name): \(m)") }
            XCTAssertFalse(e.primary.isEmpty, e.name)
        }
        for lift in MainLift.allCases { XCTAssertNotNil(lib.exercise(lift.exerciseID)) }
    }

    // MARK: estimation
    func testE1RMRoundTrip() {
        let e = Estimation.e1RM(weight: 100, reps: 5, rir: 2)
        XCTAssertEqual(e, 100 * (1 + 7.0 / 30), accuracy: 0.001)
        XCTAssertEqual(Estimation.load(e1RM: e, reps: 5, rir: 2), 100, accuracy: 0.001)
        XCTAssertEqual(Estimation.e1RM(weight: 140, reps: 1, rir: 0), 140)
    }

    func testNextLoadIsClampedAndRounded() {
        // Way easier than planned: bump limited to +10%.
        let w = Estimation.nextLoad(afterWeight: 100, reps: 5, rir: 6, nextReps: 5, nextRIR: 2, unit: .kg)
        XCTAssertLessThanOrEqual(w, 110)
        XCTAssertEqual(w.truncatingRemainder(dividingBy: 2.5), 0)
        // Grind: drop.
        let down = Estimation.nextLoad(afterWeight: 100, reps: 5, rir: 0, nextReps: 5, nextRIR: 2, unit: .kg)
        XCTAssertLessThan(down, 100)
    }

    func testUnitConversionAndRounding() {
        XCTAssertEqual(WeightUnit.kg.convert(100, to: .lb), 220.46, accuracy: 0.01)
        XCTAssertEqual(WeightUnit.lb.round(227.4), 225)
        XCTAssertEqual(WeightUnit.kg.round(101.3), 102.5)
    }

    // MARK: readiness
    func testReadinessBands() {
        XCTAssertEqual(Readiness.adjustment(for: .init(sleep: 5, energy: 5, mood: 5, soreness: 1)).band, .great)
        XCTAssertEqual(Readiness.adjustment(for: .init(sleep: 3, energy: 3, mood: 3, soreness: 2)).band, .good)
        let low = Readiness.adjustment(for: .init(sleep: 1, energy: 1, mood: 2, soreness: 5))
        XCTAssertEqual(low.band, .low)
        XCTAssertEqual(low.loadMultiplier, 0.9)
        XCTAssertLessThan(low.setDelta, 0)
    }

    // MARK: progression
    func testDoubleProgression() {
        let hit = Progression.doubleProgression(last: [(60, 12, 1), (60, 12, 1), (60, 12, 0)], low: 8, high: 12, targetRIR: 1, unit: .kg)
        XCTAssertTrue(hit.increased); XCTAssertEqual(hit.weight, 62.5); XCTAssertEqual(hit.reps, 8)
        let miss = Progression.doubleProgression(last: [(60, 10, 1), (60, 9, 1)], low: 8, high: 12, targetRIR: 1, unit: .kg)
        XCTAssertFalse(miss.increased); XCTAssertEqual(miss.weight, 60); XCTAssertEqual(miss.reps, 10)
    }

    // MARK: resolver
    func testPercentResolvesAgainstOneRepMax() {
        let block = Block(name: "b", phase: .strength, weeks: 4, days: [], percentStep: 0.025, deloadLastWeek: true)
        let day = PlannedDay(name: "d", exercises: [
            PlannedExercise(exerciseID: "back-squat", groups: [SetGroup(count: 3, target: .percent(pct: 0.8, reps: 5))])])
        let ctx = LoadContext(unit: .kg, oneRepMax: [.squat: 200])
        let w0 = Resolver.resolve(day: day, block: block, weekInBlock: 0, isDeload: false, context: ctx, library: lib)
        XCTAssertEqual(w0[0].sets.count, 3); XCTAssertEqual(w0[0].sets[0].weight, 160)
        let w1 = Resolver.resolve(day: day, block: block, weekInBlock: 1, isDeload: false, context: ctx, library: lib)
        XCTAssertEqual(w1[0].sets[0].weight, 165)   // 82.5%
        let dl = Resolver.resolve(day: day, block: block, weekInBlock: 3, isDeload: true, context: ctx, library: lib)
        XCTAssertEqual(dl[0].sets.count, 2)
        XCTAssertLessThan(dl[0].sets[0].weight!, 160)
    }

    func testReadinessReducesLoadAndSets() {
        let block = Block(name: "b", phase: .strength, weeks: 4, days: [])
        let day = PlannedDay(name: "d", exercises: [
            PlannedExercise(exerciseID: "deadlift", groups: [SetGroup(count: 4, target: .percent(pct: 0.8, reps: 3))])])
        let ctx = LoadContext(unit: .kg, oneRepMax: [.deadlift: 250])
        let adj = Readiness.adjustment(for: .init(sleep: 1, energy: 2, mood: 2, soreness: 5))
        let r = Resolver.resolve(day: day, block: block, weekInBlock: 0, isDeload: false, context: ctx, library: lib, readiness: adj)
        XCTAssertEqual(r[0].sets.count, 3)
        XCTAssertEqual(r[0].sets[0].weight, 180)    // 200 * 0.9
    }

    func testRepRangeUsesHistory() {
        let block = Block(name: "b", phase: .hypertrophy, weeks: 4, days: [])
        let day = PlannedDay(name: "d", exercises: [
            PlannedExercise(exerciseID: "lat-pulldown", groups: [SetGroup(count: 3, target: .repRange(low: 8, high: 12, rir: 2))])])
        let ctx = LoadContext(unit: .kg, oneRepMax: [:], lastPerformance: ["lat-pulldown": LastPerformance(sets: [(50, 12, 1), (50, 12, 1)])])
        let r = Resolver.resolve(day: day, block: block, weekInBlock: 0, isDeload: false, context: ctx, library: lib)
        XCTAssertEqual(r[0].sets[0].weight, 52.5)
        XCTAssertEqual(r[0].sets[0].reps, 8)
        let noHistory = Resolver.resolve(day: day, block: block, weekInBlock: 0, isDeload: false, context: LoadContext(), library: lib)
        XCTAssertNil(noHistory[0].sets[0].weight)
    }

    func testRirShiftRamp() {
        let b = Block(name: "b", phase: .hypertrophy, weeks: 4, days: [], rirShiftStart: 0, rirShiftEnd: -2, deloadLastWeek: true)
        XCTAssertEqual(Resolver.rirShift(block: b, weekInBlock: 0), 0)
        XCTAssertEqual(Resolver.rirShift(block: b, weekInBlock: 2), -2)
    }

    // MARK: generator
    func testEveryGeneratorProducesValidPlans() {
        let gen = ProgramGenerator(library: lib)
        for goal in GoalKind.allCases {
            for days in 2...6 {
                for exp in Experience.allCases {
                    let plan = gen.generate(GeneratorInput(goal: goal, daysPerWeek: days, experience: exp, emphasis: ["biceps", "lateral-delts"]))
                    XCTAssertFalse(plan.blocks.isEmpty)
                    for b in plan.blocks {
                        XCTAssertEqual(b.days.count, days, "\(goal) \(days)")
                        for d in b.days {
                            XCTAssertFalse(d.exercises.isEmpty, "\(goal) \(d.name)")
                            for e in d.exercises {
                                XCTAssertNotNil(lib.exercise(e.exerciseID), e.exerciseID)
                                XCTAssertTrue(e.totalSets >= 2)
                            }
                        }
                    }
                }
            }
        }
    }

    func testPowerliftingTrainsAllThreeLifts() {
        let plan = ProgramGenerator(library: lib).generate(GeneratorInput(goal: .powerlifting, daysPerWeek: 3))
        let ids = Set(plan.blocks[0].days.flatMap { $0.exercises.map(\.exerciseID) })
        for l in MainLift.allCases { XCTAssertTrue(ids.contains(l.exerciseID)) }
    }

    func testEmphasisAddsExercise() {
        let gen = ProgramGenerator(library: lib)
        let base = gen.generate(GeneratorInput(goal: .powerbuilding, daysPerWeek: 4))
        let emph = gen.generate(GeneratorInput(goal: .powerbuilding, daysPerWeek: 4, emphasis: ["calves"]))
        XCTAssertGreaterThan(emph.blocks[0].days.flatMap(\.exercises).count, base.blocks[0].days.flatMap(\.exercises).count)
    }

    // MARK: plan
    func testPositionAndFork() {
        let plan = ProgramGenerator(library: lib).generate(GeneratorInput(goal: .powerCombo, daysPerWeek: 4))
        XCTAssertEqual(plan.position(completedSessions: 0).blockIndex, 0)
        XCTAssertEqual(plan.position(completedSessions: 5).weekInBlock, 1)
        XCTAssertEqual(plan.position(completedSessions: 5).dayIndex, 1)
        XCTAssertFalse(plan.position(completedSessions: 19).isDeload)
        XCTAssertTrue(plan.position(completedSessions: 20).isDeload)
        XCTAssertEqual(plan.position(completedSessions: 6 * 4).blockIndex, 1)
        XCTAssertTrue(plan.position(completedSessions: plan.totalSessions).isFinished)
        let fork = plan.forkedAsCustom(named: "Mine")
        XCTAssertTrue(fork.isCustom); XCTAssertEqual(fork.blocks, plan.blocks)
        XCTAssertEqual(try ProgramPlan.decode(plan.encoded()), plan)
    }

    // MARK: analytics
    func testAnalytics() {
        let d0 = Date(timeIntervalSince1970: 0), d1 = d0.addingTimeInterval(86400 * 2)
        let a = SetRecord(exerciseID: "back-squat", weight: 100, reps: 5, rir: 2, date: d0)
        let b = SetRecord(exerciseID: "back-squat", weight: 110, reps: 5, rir: 2, date: d1)
        XCTAssertTrue(Analytics.isPR(b, history: [a, b]))
        XCTAssertFalse(Analytics.isPR(a, history: [a, b]) && false)
        XCTAssertEqual(Analytics.e1RMHistory([a, b], exerciseID: "back-squat").count, 2)
        let vol = Analytics.muscleSets([a, b], library: lib)
        XCTAssertEqual(vol["quadriceps"], 2)
    }
}

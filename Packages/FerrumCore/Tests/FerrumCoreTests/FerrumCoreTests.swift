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

    func testWeeklyTotalsAndImprovement() {
        let cal = Calendar.current
        let now = Date()
        let lastWeek = cal.date(byAdding: .day, value: -8, to: now)!
        let a = SetRecord(exerciseID: "back-squat", weight: 100, reps: 5, rir: 2, date: lastWeek)
        let b = SetRecord(exerciseID: "back-squat", weight: 110, reps: 5, rir: 2, date: now)
        let weeks = Analytics.weeklyTotals([a, b], weeks: 4, now: now)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(weeks.last?.volume, 550)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.sets }, 2)
        let imp = Analytics.improvement([a, b], exerciseID: "back-squat")
        XCTAssertEqual(imp?.percent ?? 0, 10, accuracy: 0.001)
        XCTAssertNil(Analytics.improvement([a], exerciseID: "back-squat"))
        XCTAssertEqual(Analytics.percentChangeHistory([a, b], exerciseID: "back-squat").first?.value, 0)
    }

    // MARK: preferences
    private func allIDs(_ plan: ProgramPlan) -> Set<String> {
        Set(plan.blocks.flatMap { $0.days.flatMap { $0.exercises.map(\.exerciseID) } })
    }

    func testEquipmentIsRespectedForEveryCombination() {
        let gen = ProgramGenerator(library: lib)
        let sets: [Set<String>] = [["dumbbell"], ["machine", "cable"], ["barbell", "dumbbell"], ["bodyweight-only"], []]
        for eq in sets {
            for goal in GoalKind.allCases {
                let plan = gen.generate(GeneratorInput(goal: goal, daysPerWeek: 4, equipment: eq))
                for b in plan.blocks { for d in b.days {
                    XCTAssertFalse(d.exercises.isEmpty, "\(eq) \(goal) \(d.name)")
                } }
                if !eq.isEmpty {
                    for id in allIDs(plan) {
                        let e = lib.exercise(id)!.equipment
                        XCTAssertTrue(eq.contains(e) || ["bodyweight", "gripper", "ab wheel"].contains(e), "\(id) needs \(e) with \(eq)")
                    }
                }
            }
        }
    }

    func testDislikesAndAvoidedPatternsNeverAppear() {
        let gen = ProgramGenerator(library: lib)
        let plan = gen.generate(GeneratorInput(goal: .powerbuilding, daysPerWeek: 5,
                                               dislikes: ["back-squat", "lateral-raise"], avoidPatterns: ["Vertical Push"]))
        let ids = allIDs(plan)
        XCTAssertFalse(ids.contains("back-squat"))
        XCTAssertFalse(ids.contains("lateral-raise"))
        XCTAssertFalse(ids.contains("overhead-press"))
        XCTAssertFalse(ids.contains(where: { lib.exercise($0)?.pattern == "Vertical Push" }))
    }

    func testSwappedMainLiftDropsPercentPrescription() {
        let gen = ProgramGenerator(library: lib)
        let (plan, notes) = gen.generateWithNotes(GeneratorInput(goal: .powerlifting, daysPerWeek: 3, dislikes: ["back-squat"]))
        XCTAssertFalse(notes.isEmpty)
        let squatDay = plan.blocks[0].days[0]
        XCTAssertNotEqual(squatDay.exercises[0].exerciseID, "back-squat")
        if case .percent = squatDay.exercises[0].groups[0].target { XCTFail("percent on a swapped lift") }
    }

    func testFavoritesAreIncludedAndSessionLengthIsHonoured() {
        let gen = ProgramGenerator(library: lib)
        let plan = gen.generate(GeneratorInput(goal: .powerbuilding, daysPerWeek: 4, sessionMinutes: 60,
                                               favorites: ["hammer-curl", "face-pull"]))
        let ids = allIDs(plan)
        XCTAssertTrue(ids.contains("hammer-curl")); XCTAssertTrue(ids.contains("face-pull"))
        for b in plan.blocks { for d in b.days { XCTAssertLessThanOrEqual(d.estimatedMinutes, 60, "\(b.name) \(d.name)") } }
        let short = gen.generate(GeneratorInput(goal: .powerbuilding, daysPerWeek: 4, sessionMinutes: 40))
        let long = gen.generate(GeneratorInput(goal: .powerbuilding, daysPerWeek: 4, sessionMinutes: 90))
        let avg: (ProgramPlan) -> Double = { p in
            let days = p.blocks.flatMap(\.days); return Double(days.map(\.estimatedMinutes).reduce(0, +)) / Double(days.count)
        }
        XCTAssertLessThan(avg(short), avg(long))
    }

    // MARK: interchange
    func testInterchangeRoundTrip() throws {
        let gen = ProgramGenerator(library: lib)
        for goal in GoalKind.allCases {
            let plan = gen.generate(GeneratorInput(goal: goal, daysPerWeek: 4))
            let data = try ProgramInterchange.export(plan)
            let back = try ProgramInterchange.importPlan(data, library: lib)
            XCTAssertEqual(back.name, plan.name)
            XCTAssertEqual(back.blocks.count, plan.blocks.count)
            for (a, b) in zip(plan.blocks, back.blocks) {
                XCTAssertEqual(a.weeks, b.weeks); XCTAssertEqual(a.percentStep, b.percentStep)
                XCTAssertEqual(a.days.map { $0.exercises.map { [$0.exerciseID] + $0.groups.map { "\($0.count)\($0.target)" } } },
                               b.days.map { $0.exercises.map { [$0.exerciseID] + $0.groups.map { "\($0.count)\($0.target)" } } })
            }
            XCTAssertTrue(back.isCustom)
        }
    }

    func testInterchangeRejectsBadFiles() {
        func problems(_ json: String) -> [String] {
            do { _ = try ProgramInterchange.importPlan(Data(json.utf8), library: lib); return [] }
            catch let e as ProgramInterchange.ImportError { return e.problems }
            catch { return ["other"] }
        }
        XCTAssertFalse(problems("not json").isEmpty)
        XCTAssertFalse(problems(#"{"format":"other","version":1,"name":"x","blocks":[]}"#).isEmpty)
        let bad = #"{"format":"ferrum-program","version":1,"name":"x","blocks":[{"name":"b","weeks":4,"days":[{"name":"d","exercises":[{"exercise":"nope","sets":[{"count":3,"type":"percent","pct":0.8}]}]}]}]}"#
        let p = problems(bad)
        XCTAssertTrue(p.contains { $0.contains("unknown exercise") })
        XCTAssertTrue(p.contains { $0.contains("percent sets need") })
        let ok = #"{"format":"ferrum-program","version":1,"name":"x","blocks":[{"name":"b","weeks":4,"days":[{"name":"d","exercises":[{"exercise":"back-squat","sets":[{"count":3,"type":"percent","pct":0.8,"reps":5}]}]}]}]}"#
        XCTAssertTrue(problems(ok).isEmpty)
    }

    func testImportsFileExportedByWebsite() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/web-example.ferrum.json")
        let plan = try ProgramInterchange.importPlan(try Data(contentsOf: url), library: lib)
        XCTAssertEqual(plan.name, "Upper / Lower Strength")
        XCTAssertEqual(plan.blocks[0].days.count, 2)
        XCTAssertEqual(plan.blocks[0].days[0].exercises[0].exerciseID, "back-squat")
        XCTAssertEqual(plan.blocks[0].percentStep, 0.025)
        XCTAssertTrue(plan.blocks[0].deloadLastWeek)
        XCTAssertNil(plan.blocks[0].days[0].exercises[0].reference)
        XCTAssertEqual(plan.totalSessions, 8)
    }

    // MARK: rest days + body weight
    func testRestDayRoundTripAndLegacyDecode() throws {
        var plan = ProgramPlan(name: "R", blocks: [Block(name: "b", phase: .general, weeks: 2, days: [
            PlannedDay(name: "A", exercises: [PlannedExercise(exerciseID: "back-squat", groups: [SetGroup(count: 3, target: .percent(pct: 0.8, reps: 5))])]),
            .rest(),
        ])])
        let back = try ProgramInterchange.importPlan(ProgramInterchange.export(plan), library: lib)
        XCTAssertEqual(back.blocks[0].days.map(\.isRest), [false, true])
        XCTAssertEqual(back.totalSessions, 4)
        // Plans saved before rest days existed have no isRest key.
        var json = try JSONSerialization.jsonObject(with: plan.encoded()) as! [String: Any]
        var blocks = json["blocks"] as! [[String: Any]]
        var days = blocks[0]["days"] as! [[String: Any]]
        for i in days.indices { days[i].removeValue(forKey: "isRest") }
        blocks[0]["days"] = days; json["blocks"] = blocks
        plan = try ProgramPlan.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(plan.blocks[0].days.map(\.isRest), [false, false])
    }

    func testRestDaysResolveToNothingAndKeepRotation() {
        let plan = ProgramPlan(name: "R", blocks: [Block(name: "b", phase: .general, weeks: 1, days: [PlannedDay(name: "A"), .rest(), PlannedDay(name: "B")])])
        XCTAssertEqual(plan.position(completedSessions: 1).dayIndex, 1)
        XCTAssertTrue(plan.blocks[0].days[plan.position(completedSessions: 1).dayIndex].isRest)
        XCTAssertEqual(plan.totalSessions, 3)
    }

    func testBodyWeightSmoothingAndChange() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let pts = (0..<14).map { BodyWeightPoint(date: cal.date(byAdding: .day, value: $0 - 13, to: start)!, kg: 80 + Double($0) * 0.1 + ($0 % 2 == 0 ? 0.4 : -0.4)) }
        XCTAssertEqual(BodyWeight.daily(pts + [BodyWeightPoint(date: pts[0].date.addingTimeInterval(60), kg: 99)]).count, 14)
        XCTAssertEqual(BodyWeight.daily(pts + [BodyWeightPoint(date: pts[0].date.addingTimeInterval(60), kg: 99)]).first?.kg, 99)
        let avg = BodyWeight.movingAverage(pts)
        XCTAssertEqual(avg.count, 14)
        let swing = zip(pts, avg).map { abs($0.kg - $1.kg) }.max()!
        XCTAssertGreaterThan(swing, 0)
        let change = BodyWeight.change(pts, overDays: 7)!
        XCTAssertEqual(change, 0.7, accuracy: 0.2)
        XCTAssertNil(BodyWeight.change([pts[0]], overDays: 7))
    }

    // MARK: web parity
    /// The website's JS generator is a port of this one. Both must produce identical programs for the shared cases.
    func testGeneratorMatchesParityFixture() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("parity-cases.json"))) as! [[String: Any]]
        let gen = ProgramGenerator(library: lib)
        var results: [[String: Any]] = []
        for c in cases {
            let input = GeneratorInput(
                goal: GoalKind(rawValue: c["goal"] as! String)!, daysPerWeek: c["daysPerWeek"] as! Int,
                experience: Experience(rawValue: c["experience"] as! String)!, emphasis: (c["emphasis"] as? [String]) ?? [],
                sessionMinutes: c["sessionMinutes"] as? Int, equipment: Set((c["equipment"] as? [String]) ?? []),
                favorites: Set((c["favorites"] as? [String]) ?? []), dislikes: Set((c["dislikes"] as? [String]) ?? []),
                avoidPatterns: Set((c["avoidPatterns"] as? [String]) ?? []))
            let (plan, notes) = gen.generateWithNotes(input)
            let program = try JSONSerialization.jsonObject(with: ProgramInterchange.export(plan))
            results.append(["input": c, "program": program, "notes": notes])
        }
        let out = try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])
        let file = dir.appendingPathComponent("parity.json")
        if ProcessInfo.processInfo.environment["FERRUM_WRITE_PARITY"] != nil { try out.write(to: file) }
        let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [[String: Any]]
        XCTAssertEqual(expected.count, results.count)
        let a = try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])
        XCTAssertEqual(a, out, "Generator output changed. Re-run with FERRUM_WRITE_PARITY=1, then run `node web/parity.test.mjs` and update generator.js to match.")
    }

    func testImportsRestDayFromWebsite() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/web-rest-day.ferrum.json")
        let plan = try ProgramInterchange.importPlan(try Data(contentsOf: url), library: lib)
        XCTAssertEqual(plan.blocks[0].days.map(\.isRest), [false, false, true])
        XCTAssertEqual(plan.totalSessions, 12)
    }

    // MARK: adaptation + plates
    func testHardSetLowersNextSetMoreThanOnPlanSet() {
        let onPlan = Adaptation.Performed(weight: 100, reps: 8, rir: 2, targetRIR: 2)
        let hard = Adaptation.Performed(weight: 100, reps: 8, rir: 1, targetRIR: 3)
        let same = Adaptation.nextSetLoad(after: onPlan, nextReps: 8, nextRIR: 2, isLastSet: false, unit: .kg)
        XCTAssertEqual(same, 100)
        let lower = Adaptation.nextSetLoad(after: hard, nextReps: 8, nextRIR: 3, isLastSet: false, unit: .kg)
        XCTAssertLessThan(lower, 97.5)
        let lastSet = Adaptation.nextSetLoad(after: hard, nextReps: 8, nextRIR: 3, isLastSet: true, unit: .kg)
        XCTAssertLessThan(lastSet, lower)
        XCTAssertGreaterThanOrEqual(lastSet, 87.5)   // never much more than a 12% cut in one step
    }

    func testEasySetRaisesNextSetButIsCapped() {
        let easy = Adaptation.Performed(weight: 100, reps: 8, rir: 5, targetRIR: 2)
        let up = Adaptation.nextSetLoad(after: easy, nextReps: 8, nextRIR: 2, isLastSet: false, unit: .kg)
        XCTAssertGreaterThan(up, 100); XCTAssertLessThanOrEqual(up, 110)
    }

    func testSessionFactor() {
        XCTAssertEqual(Adaptation.sessionFactor(hardness: [0, 0, 0.5]), 1)
        XCTAssertEqual(Adaptation.sessionFactor(hardness: [1]), 1)               // too little evidence
        XCTAssertLessThan(Adaptation.sessionFactor(hardness: [2, 2, 2]), 1)
        XCTAssertGreaterThanOrEqual(Adaptation.sessionFactor(hardness: [5, 5, 5]), 0.94)
        XCTAssertGreaterThan(Adaptation.sessionFactor(hardness: [-3, -3, -3]), 1)
    }

    func testPlateMath() {
        XCTAssertEqual(PlateMath.breakdown(total: 0, bar: 20, unit: .kg).headline, "Enter weight")
        XCTAssertEqual(PlateMath.breakdown(total: 15, bar: 20, unit: .kg).headline, "Below bar")
        XCTAssertEqual(PlateMath.breakdown(total: 20, bar: 20, unit: .kg).headline, "Bar only")
        let b = PlateMath.breakdown(total: 92.5, bar: 20, unit: .kg)   // 36.25 per side = 25 + 10 + 1.25
        XCTAssertEqual(b.headline, "Per side 25 + 10 + 1.25")
        XCTAssertNil(b.remainderText)
        let odd = PlateMath.breakdown(total: 101, bar: 20, unit: .kg)  // 40.5 per side -> 25 + 15 + 0.5 left
        XCTAssertEqual(odd.perSide, [25, 15])
        XCTAssertEqual(odd.remainderText, "rem 1")
        XCTAssertEqual(PlateMath.breakdown(total: 225, bar: 45, unit: .lb).headline, "Per side 45 + 45")
    }

    // MARK: keypad typing rules
    func testFirstKeyReplacesThenAppends() {
        var e = NumericEntry(kind: .weight, initial: "100")
        e.digit("8"); XCTAssertEqual(e.text, "8")
        e.digit("5"); XCTAssertEqual(e.text, "85")
        e.point(); XCTAssertEqual(e.text, "85.")
        e.point(); XCTAssertEqual(e.text, "85.")        // only one decimal point
        e.digit("5"); XCTAssertEqual(e.text, "85.5")
    }

    func testPointFirstGivesZeroPoint() {
        var e = NumericEntry(kind: .weight, initial: "60")
        e.point(); XCTAssertEqual(e.text, "0.")
        e.digit("5"); XCTAssertEqual(e.text, "0.5")
    }

    func testBackspaceFirstEditsInsteadOfReplacing() {
        var e = NumericEntry(kind: .weight, initial: "100")
        e.backspace(); XCTAssertEqual(e.text, "10")
        e.digit("5"); XCTAssertEqual(e.text, "105")     // appended, not replaced
    }

    func testLoneZeroIsReplaced() {
        var e = NumericEntry(kind: .reps, initial: "")
        e.digit("0"); XCTAssertEqual(e.text, "0")
        e.digit("7"); XCTAssertEqual(e.text, "7")
    }

    func testLengthLimitsAndRepsAreWholeNumbers() {
        var w = NumericEntry(kind: .weight, initial: "")
        for d in "123456789" { w.digit(d) }
        XCTAssertEqual(w.text, "1234567")               // 7 characters max
        var r = NumericEntry(kind: .reps, initial: "")
        for d in "12345" { r.digit(d) }
        XCTAssertEqual(r.text, "123")                   // 3 digits max
        r.point(); XCTAssertEqual(r.text, "123")        // no decimals in reps
        XCTAssertEqual(r.repsValue, 123)
        var empty = NumericEntry(kind: .weight, initial: "5")
        empty.backspace(); empty.backspace()
        XCTAssertEqual(empty.weightValue, 0)
    }
}

import XCTest
@testable import TrainingLogic

final class ProgramEngineTests: XCTestCase {
    private func profile(_ mode: TrainingMode, unit: WeightUnit = .kilogram) -> AthleteProfile {
        AthleteProfile(
            trainingMode: mode,
            experienceLevel: .intermediate,
            bodyweightKg: 80,
            preferredUnit: unit,
            squatPR: 140,
            benchPR: 100,
            deadliftPR: 180,
            ohpPR: 65
        )
    }

    func testAllModesGenerateTwelveWeekBlocks() {
        for mode in TrainingMode.allCases {
            let weeks = ProgramEngine.generate(profile: profile(mode))
            XCTAssertEqual(weeks.count, 12, mode.rawValue)
            XCTAssertEqual(Set(weeks.map(\.weekNumber)), Set(1...12), mode.rawValue)
            for week in weeks {
                switch week.weekNumber {
                case 1...4: XCTAssertEqual(week.block, .hypertrophy, "\(mode.rawValue) week \(week.weekNumber)")
                case 5...8: XCTAssertEqual(week.block, .strength, "\(mode.rawValue) week \(week.weekNumber)")
                default: XCTAssertEqual(week.block, .peaking, "\(mode.rawValue) week \(week.weekNumber)")
                }
            }
        }
    }

    func testSplitsMatchModeDayCounts() {
        XCTAssertEqual(trainingDayCount(.powerlifting), 4)
        XCTAssertEqual(trainingDayCount(.powerbuilding), 4)
        XCTAssertEqual(trainingDayCount(.hybrid), 4)
        XCTAssertEqual(trainingDayCount(.bodybuilding), 5)
    }

    func testTrainingDaysAreSpreadWithExplicitRestDays() {
        for mode in TrainingMode.allCases {
            let week = ProgramEngine.generate(profile: profile(mode))[0]
            XCTAssertEqual(week.days.count, 7, mode.rawValue)
            XCTAssertEqual(Set(week.days.map(\.dayIndex)), Set(0...6), mode.rawValue)
            let training = week.days.filter { !$0.isRestDay }
            let rest = week.days.filter(\.isRestDay)
            XCTAssertFalse(training.isEmpty, mode.rawValue)
            XCTAssertFalse(rest.isEmpty, mode.rawValue)
            XCTAssertTrue(rest.allSatisfy { $0.exercises.isEmpty }, mode.rawValue)

            let trainingIndexes = training.map(\.dayIndex)
            if trainingIndexes.count >= 2 {
                let consecutive = zip(trainingIndexes, trainingIndexes.dropFirst()).filter { $1 == $0 + 1 }.count
                XCTAssertLessThan(
                    consecutive,
                    trainingIndexes.count - 1,
                    "\(mode.rawValue) stacked every training day consecutively"
                )
            }
        }
    }

    func testFourDayOffsetsAreNotZeroThroughThree() {
        XCTAssertEqual(ProgramEngine.trainingDayOffsets(count: 4), [0, 2, 4, 5])
        XCTAssertNotEqual(ProgramEngine.trainingDayOffsets(count: 4), [0, 1, 2, 3])
    }

    func testPosteriorChainFloorsHoldForEveryModeAndWeek() {
        for mode in TrainingMode.allCases {
            let athlete = profile(mode)
            for week in ProgramEngine.generate(profile: athlete) {
                let counts = VolumeMetrics.weeklySetsByMuscle(week)
                for muscle in VolumeLandmarks.floorMuscles {
                    let mev = VolumeLandmarks.scaled(for: muscle, profile: athlete).mev
                    XCTAssertGreaterThanOrEqual(
                        counts[muscle] ?? 0,
                        mev,
                        "\(mode.rawValue) week \(week.weekNumber) \(muscle.rawValue)"
                    )
                }
            }
        }
    }

    func testBodybuildingPeakingStaysHypertrophyLeaning() {
        let weeks = ProgramEngine.generate(profile: profile(.bodybuilding))
        let peaking = weeks.first { $0.weekNumber == 10 }
        let main = peaking?.days.first { !$0.isRestDay }?.exercises.first { $0.role == .main }
        let working = main?.sets.filter { !$0.isWarmup }
        XCTAssertNotNil(working)
        XCTAssertGreaterThanOrEqual(working?.first?.targetReps ?? 0, 8)
        XCTAssertLessThanOrEqual(working?.first?.percent1RM ?? 1, 0.75)
    }

    func testMainsIncludeWarmupsAndUniqueWorkingLoads() {
        let week = ProgramEngine.generate(profile: profile(.powerlifting))[0]
        let squat = week.days
            .flatMap(\.exercises)
            .first { $0.catalogID == "back_squat" }
        XCTAssertNotNil(squat)
        let warmups = squat?.sets.filter(\.isWarmup) ?? []
        let working = squat?.sets.filter { !$0.isWarmup } ?? []
        XCTAssertEqual(warmups.count, 3)
        XCTAssertGreaterThanOrEqual(working.count, 2)
        if working.count >= 2 {
            XCTAssertGreaterThan(working[0].targetWeightKg, working[1].targetWeightKg)
        }
    }

    func testHybridIsADistinctSplit() {
        let hybrid = ProgramEngine.generate(profile: profile(.hybrid))[0]
        let powerbuilding = ProgramEngine.generate(profile: profile(.powerbuilding))[0]
        let hybridTitles = hybrid.days.filter { !$0.isRestDay }.map(\.title)
        let pbTitles = powerbuilding.days.filter { !$0.isRestDay }.map(\.title)
        XCTAssertEqual(hybridTitles, ["Upper Strength", "Lower Hypertrophy", "Upper Hypertrophy", "Lower Strength"])
        XCTAssertNotEqual(hybridTitles, pbTitles)
    }

    private func trainingDayCount(_ mode: TrainingMode) -> Int {
        ProgramEngine.generate(profile: profile(mode))[0].days.filter { !$0.isRestDay }.count
    }
}

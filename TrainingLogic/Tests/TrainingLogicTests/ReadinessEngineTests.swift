import XCTest
@testable import TrainingLogic

final class ReadinessEngineTests: XCTestCase {
    func testMinScoreIsTwenty() {
        let result = ReadinessEngine.evaluate(sleep: 1, energy: 1, motivation: 1, soreness: 5, stress: 5)
        XCTAssertEqual(result.score, 20, accuracy: 0.001)
        XCTAssertEqual(result.band, .deload)
        XCTAssertTrue(result.replaceWithRecovery)
    }

    func testMaxScoreIsOneHundred() {
        let result = ReadinessEngine.evaluate(sleep: 5, energy: 5, motivation: 5, soreness: 1, stress: 1)
        XCTAssertEqual(result.score, 100, accuracy: 0.001)
        XCTAssertEqual(result.band, .proceed)
        XCTAssertEqual(result.loadMultiplier, 1.025, accuracy: 0.0001)
    }

    func testBandBoundary39IsDeload() {
        let result = ReadinessEngine.evaluate(sleep: 2, energy: 2, motivation: 3, soreness: 5, stress: 5)
        XCTAssertEqual(result.score, 39, accuracy: 0.001)
        XCTAssertEqual(result.band, .deload)
    }

    func testBandBoundary40IsCut() {
        let result = ReadinessEngine.evaluate(sleep: 2, energy: 2, motivation: 2, soreness: 4, stress: 4)
        XCTAssertEqual(result.score, 40, accuracy: 0.001)
        XCTAssertEqual(result.band, .cut)
        XCTAssertEqual(result.volumeMultiplier, 0.75, accuracy: 0.0001)
        XCTAssertEqual(result.loadMultiplier, 1.0, accuracy: 0.0001)
    }

    func testBandBoundary59IsCut() {
        let result = ReadinessEngine.evaluate(sleep: 3, energy: 3, motivation: 3, soreness: 2, stress: 5)
        XCTAssertEqual(result.score, 59, accuracy: 0.001)
        XCTAssertEqual(result.band, .cut)
    }

    func testBandBoundary60IsHold() {
        let result = ReadinessEngine.evaluate(sleep: 3, energy: 3, motivation: 3, soreness: 3, stress: 3)
        XCTAssertEqual(result.score, 60, accuracy: 0.001)
        XCTAssertEqual(result.band, .hold)
        XCTAssertEqual(result.loadMultiplier, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.volumeMultiplier, 1.0, accuracy: 0.0001)
    }

    func testBandBoundary79IsHold() {
        let result = ReadinessEngine.evaluate(sleep: 4, energy: 4, motivation: 4, soreness: 3, stress: 1)
        XCTAssertEqual(result.score, 79, accuracy: 0.001)
        XCTAssertEqual(result.band, .hold)
    }

    func testBandBoundary80IsProceed() {
        let result = ReadinessEngine.evaluate(sleep: 4, energy: 4, motivation: 4, soreness: 2, stress: 2)
        XCTAssertEqual(result.score, 80, accuracy: 0.001)
        XCTAssertEqual(result.band, .proceed)
    }

    func testHigherSorenessLowersScore() {
        let fresh = ReadinessEngine.evaluate(sleep: 4, energy: 4, motivation: 4, soreness: 1, stress: 2)
        let sore = ReadinessEngine.evaluate(sleep: 4, energy: 4, motivation: 4, soreness: 5, stress: 2)
        XCTAssertGreaterThan(fresh.score, sore.score)
    }

    func testHigherStressLowersScore() {
        let calm = ReadinessEngine.evaluate(sleep: 4, energy: 4, motivation: 4, soreness: 2, stress: 1)
        let stressed = ReadinessEngine.evaluate(sleep: 4, energy: 4, motivation: 4, soreness: 2, stress: 5)
        XCTAssertGreaterThan(calm.score, stressed.score)
    }

    func testExactWeightedFormula() {
        let sleep = 4, energy = 3, motivation = 5, soreness = 2, stress = 3
        let expected = (Double(sleep) * 0.3 + Double(energy) * 0.25 + Double(motivation) * 0.2
            + Double(6 - soreness) * 0.15 + Double(6 - stress) * 0.1) * 20
        let result = ReadinessEngine.evaluate(sleep: sleep, energy: energy, motivation: motivation, soreness: soreness, stress: stress)
        XCTAssertEqual(result.score, expected, accuracy: 0.0001)
    }

    func testRecoveryLoadsScaleFromPersonalRecords() {
        let light = AthleteProfile(
            trainingMode: .powerbuilding,
            experienceLevel: .intermediate,
            bodyweightKg: 80,
            squatPR: 100,
            benchPR: 80,
            deadliftPR: 120,
            ohpPR: 50
        )
        let heavy = AthleteProfile(
            trainingMode: .powerbuilding,
            experienceLevel: .intermediate,
            bodyweightKg: 80,
            squatPR: 200,
            benchPR: 150,
            deadliftPR: 250,
            ohpPR: 90
        )
        let lightHinge = ReadinessEngine.recoveryWorkout(dayIndex: 0, profile: light).exercises.first { $0.catalogID == "romanian_deadlift" }?.sets.first?.targetWeightKg ?? 0
        let heavyHinge = ReadinessEngine.recoveryWorkout(dayIndex: 0, profile: heavy).exercises.first { $0.catalogID == "romanian_deadlift" }?.sets.first?.targetWeightKg ?? 0
        XCTAssertGreaterThan(heavyHinge, lightHinge)
        XCTAssertGreaterThan(lightHinge, 0)
        XCTAssertNotEqual(lightHinge, 40, accuracy: 0.001)
    }
}

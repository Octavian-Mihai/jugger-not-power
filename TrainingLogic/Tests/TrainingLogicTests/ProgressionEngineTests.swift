import XCTest
@testable import TrainingLogic

final class ProgressionEngineTests: XCTestCase {
    func testMissedRPEByOneCutsLoadFivePercent() {
        let sets = [
            CompletedSet(targetReps: 5, targetWeightKg: 100, targetRPE: 8, actualReps: 5, actualWeightKg: 100, actualRPE: 9, isCompleted: true),
            CompletedSet(targetReps: 5, targetWeightKg: 100, targetRPE: 8, actualReps: 5, actualWeightKg: 100, actualRPE: 9, isCompleted: true)
        ]
        XCTAssertEqual(ProgressionEngine.loadMultiplier(for: sets), 0.95, accuracy: 0.0001)
    }

    func testEasyRPEAddsTwoPointFivePercent() {
        let sets = [
            CompletedSet(targetReps: 5, targetWeightKg: 100, targetRPE: 8, actualReps: 5, actualWeightKg: 100, actualRPE: 7, isCompleted: true),
            CompletedSet(targetReps: 5, targetWeightKg: 100, targetRPE: 8, actualReps: 5, actualWeightKg: 100, actualRPE: 6.5, isCompleted: true)
        ]
        XCTAssertEqual(ProgressionEngine.loadMultiplier(for: sets), 1.025, accuracy: 0.0001)
    }

    func testOnTargetCompletedSetsGetSmallBump() {
        let sets = [
            CompletedSet(targetReps: 5, targetWeightKg: 100, targetRPE: 8, actualReps: 5, actualWeightKg: 100, actualRPE: 8, isCompleted: true)
        ]
        XCTAssertEqual(ProgressionEngine.loadMultiplier(for: sets), 1.01, accuracy: 0.0001)
    }

    func testIncompleteWeekDoesNotIncreaseVolume() {
        let next = ProgressionEngine.nextSetCount(
            current: 4,
            mev: 2,
            mrv: 8,
            completionRate: 0.5,
            averageSoreness: 1.0
        )
        XCTAssertLessThanOrEqual(next, 4)
        XCTAssertEqual(next, 3)
    }

    func testHighCompletionLowSorenessDriftsTowardMRV() {
        let next = ProgressionEngine.nextSetCount(
            current: 4,
            mev: 2,
            mrv: 8,
            completionRate: 1.0,
            averageSoreness: 2.0
        )
        XCTAssertEqual(next, 5)
    }
}

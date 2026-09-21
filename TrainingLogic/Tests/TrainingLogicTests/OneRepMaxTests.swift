import XCTest
@testable import TrainingLogic

final class OneRepMaxTests: XCTestCase {
    func testEpleyKnownTriple100x5() {
        let result = OneRepMax.epley(weight: 100, reps: 5)
        XCTAssertEqual(result, 100.0 * (1.0 + 5.0 / 30.0), accuracy: 0.0001)
        XCTAssertEqual(result, 116.6666666667, accuracy: 0.001)
        XCTAssertEqual((result * 10).rounded() / 10, 116.7, accuracy: 0.05)
    }

    func testEpleySingleIsUnchanged() {
        XCTAssertEqual(OneRepMax.epley(weight: 140, reps: 1), 140, accuracy: 0.0001)
    }

    func testRoundToPlateUsesDisplayUnit() {
        XCTAssertEqual(OneRepMax.roundToPlate(101.2, unit: .kilogram), 100, accuracy: 0.001)
        XCTAssertEqual(OneRepMax.roundToPlate(103.8, unit: .kilogram), 105, accuracy: 0.001)
        let roundedPounds = OneRepMax.roundToPlate(100, unit: .pound)
        let asPounds = roundedPounds * 2.2046226218
        XCTAssertEqual(asPounds.truncatingRemainder(dividingBy: 5), 0, accuracy: 0.05)
    }

    func testProgressionEngineDelegatesToEpley() {
        XCTAssertEqual(ProgressionEngine.estimated1RM(weight: 100, reps: 5), OneRepMax.epley(weight: 100, reps: 5), accuracy: 0.0001)
    }
}

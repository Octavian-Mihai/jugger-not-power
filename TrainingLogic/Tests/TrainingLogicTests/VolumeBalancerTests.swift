import XCTest
@testable import TrainingLogic

final class VolumeBalancerTests: XCTestCase {
    private var profile: AthleteProfile {
        AthleteProfile(
            trainingMode: .powerbuilding,
            experienceLevel: .intermediate,
            bodyweightKg: 80,
            preferredUnit: .kilogram,
            squatPR: 140,
            benchPR: 100,
            deadliftPR: 180,
            ohpPR: 65
        )
    }

    func testUnderPulledWeekReachesMinimumAndTargetRatio() {
        let raw = pushHeavyWeek()
        XCTAssertLessThan(VolumeMetrics.pullPushRatio(raw), 1.0)

        let balanced = VolumeBalancer.rebalance(raw, profile: profile)
        let ratio = VolumeMetrics.pullPushRatio(balanced)
        XCTAssertGreaterThanOrEqual(ratio, VolumeBalancer.minimumPullPushRatio)
        XCTAssertGreaterThanOrEqual(ratio, VolumeBalancer.targetPullPushRatio - 0.0001)
        XCTAssertGreaterThan(VolumeMetrics.pullSets(balanced), VolumeMetrics.pullSets(raw))
    }

    func testFloorsHoldAfterBalancing() {
        let balanced = VolumeBalancer.rebalance(pushHeavyWeek(), profile: profile)
        let counts = VolumeMetrics.weeklySetsByMuscle(balanced)
        for muscle in VolumeLandmarks.floorMuscles {
            let mev = VolumeLandmarks.scaled(for: muscle, profile: profile).mev
            XCTAssertGreaterThanOrEqual(counts[muscle] ?? 0, mev, "Floor failed for \(muscle.rawValue)")
        }
    }

    func testGeneratedProgramsSatisfyBalancerInvariants() {
        for mode in TrainingMode.allCases {
            let athlete = AthleteProfile(
                trainingMode: mode,
                experienceLevel: .intermediate,
                bodyweightKg: 80,
                squatPR: 140,
                benchPR: 100,
                deadliftPR: 180,
                ohpPR: 65
            )
            let weeks = ProgramEngine.generate(profile: athlete)
            XCTAssertEqual(weeks.count, 12)
            for week in weeks {
                XCTAssertGreaterThanOrEqual(VolumeMetrics.pullPushRatio(week), VolumeBalancer.minimumPullPushRatio)
                let counts = VolumeMetrics.weeklySetsByMuscle(week)
                for muscle in VolumeLandmarks.floorMuscles {
                    let mev = VolumeLandmarks.scaled(for: muscle, profile: athlete).mev
                    XCTAssertGreaterThanOrEqual(counts[muscle] ?? 0, mev, "\(mode.rawValue) week \(week.weekNumber) \(muscle.rawValue)")
                }
            }
        }
    }

    func testBodybuildingPeakingStaysHypertrophyLeaning() {
        let athlete = AthleteProfile(trainingMode: .bodybuilding, experienceLevel: .intermediate, bodyweightKg: 80)
        let weeks = ProgramEngine.generate(profile: athlete)
        let peakingMain = weeks.first { $0.weekNumber == 10 }?.days.first { !$0.isRestDay }?.exercises.first { $0.role == .main }
        let working = peakingMain?.sets.filter { !$0.isWarmup }
        XCTAssertNotNil(working)
        XCTAssertGreaterThanOrEqual(working?.first?.targetReps ?? 0, 8)
    }

    private func pushHeavyWeek() -> TrainingWeek {
        let bench = ExerciseLibrary.require("barbell_bench_press")
        let incline = ExerciseLibrary.require("incline_dumbbell_press")
        let ohp = ExerciseLibrary.require("overhead_press")
        let row = ExerciseLibrary.require("barbell_row")

        func sets(_ count: Int, reps: Int = 8) -> [PlannedSet] {
            (0..<count).map { _ in PlannedSet(targetReps: reps, targetWeightKg: 80, targetRPE: 7.5) }
        }

        let pushDay = PlannedWorkout(
            dayIndex: 0,
            title: "Push Heavy",
            exercises: [
                PlannedExercise(catalogID: bench.id, name: bench.name, movementPattern: bench.movementPattern, primaryMuscles: bench.primaryMuscles, role: .main, sets: sets(6)),
                PlannedExercise(catalogID: incline.id, name: incline.name, movementPattern: incline.movementPattern, primaryMuscles: incline.primaryMuscles, role: .secondary, sets: sets(5)),
                PlannedExercise(catalogID: ohp.id, name: ohp.name, movementPattern: ohp.movementPattern, primaryMuscles: ohp.primaryMuscles, role: .secondary, sets: sets(4))
            ]
        )
        let tokenPull = PlannedWorkout(
            dayIndex: 1,
            title: "Sparse Pull",
            exercises: [
                PlannedExercise(catalogID: row.id, name: row.name, movementPattern: row.movementPattern, primaryMuscles: row.primaryMuscles, role: .accessory, sets: sets(2))
            ]
        )
        return TrainingWeek(weekNumber: 1, block: .hypertrophy, days: [pushDay, tokenPull])
    }
}

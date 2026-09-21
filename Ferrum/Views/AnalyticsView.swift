import SwiftUI
import SwiftData
import Charts
import TrainingLogic

struct AnalyticsView: View {
    @Bindable var user: User

    private var completedSets: [SetLog] {
        user.programs
            .flatMap(\.weeks)
            .flatMap(\.days)
            .flatMap(\.exercises)
            .flatMap(\.setLogs)
            .filter { $0.isCompleted && !$0.isWarmup && $0.actualWeightKg != nil && $0.actualReps != nil }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    private var oneRMPoints: [ChartPoint] {
        let mains: Set<String> = ["back_squat", "barbell_bench_press", "conventional_deadlift", "overhead_press"]
        return completedSets.compactMap { set in
            guard let exercise = set.exercise, mains.contains(exercise.catalogID),
                  let weight = set.actualWeightKg, let reps = set.actualReps else { return nil }
            return ChartPoint(
                id: "\(exercise.catalogID)-\(set.persistentModelID)",
                date: set.completedAt ?? set.exercise?.workoutDay?.scheduledDate ?? .now,
                value: OneRepMax.epley(weight: weight, reps: reps),
                series: exercise.name
            )
        }
    }

    private var latestOneRMs: [OneRMRow] {
        let order = ["Back Squat", "Barbell Bench Press", "Conventional Deadlift", "Overhead Press"]
        var latest: [String: ChartPoint] = [:]
        for point in oneRMPoints {
            if let existing = latest[point.series], existing.date > point.date { continue }
            latest[point.series] = point
        }
        return order.compactMap { name in
            latest[name].map { OneRMRow(lift: name, valueKg: $0.value, date: $0.date) }
        }
    }

    private var volumePoints: [VolumePoint] {
        var result: [VolumePoint] = []
        for week in user.activeProgram?.orderedWeeks ?? [] {
            var planned: [String: Int] = [:]
            var actual: [String: Int] = [:]
            for day in week.days where !day.isRestDay {
                for exercise in day.exercises {
                    let group = volumeGroup(for: exercise)
                    let working = exercise.setLogs.filter { !$0.isWarmup }
                    planned[group, default: 0] += working.count
                    actual[group, default: 0] += working.filter(\.isCompleted).count
                }
            }
            for group in ["Push", "Pull", "Legs", "Other"] {
                let plannedCount = planned[group] ?? 0
                let actualCount = actual[group] ?? 0
                if plannedCount > 0 || actualCount > 0 {
                    result.append(VolumePoint(week: week.weekNumber, series: "\(group) planned", sets: plannedCount))
                    result.append(VolumePoint(week: week.weekNumber, series: "\(group) actual", sets: actualCount))
                }
            }
        }
        return result
    }

    private var readinessPoints: [ChartPoint] {
        user.checkIns.sorted { $0.date < $1.date }.map {
            ChartPoint(id: $0.dayKey, date: $0.date, value: $0.score, series: "Readiness")
        }
    }

    private var currentRatio: Double {
        guard let week = currentWeek else { return 1 }
        let generated = TrainingLogic.TrainingWeek(
            weekNumber: week.weekNumber,
            block: week.block,
            days: week.orderedDays.map { day in
                PlannedWorkout(
                    dayIndex: day.dayIndex,
                    title: day.title,
                    exercises: day.orderedExercises.map {
                        PlannedExercise(
                            catalogID: $0.catalogID,
                            name: $0.name,
                            movementPattern: $0.movementPattern,
                            primaryMuscles: $0.primaryMuscles,
                            role: $0.role,
                            sets: $0.orderedSets.map {
                                PlannedSet(
                                    targetReps: $0.targetReps,
                                    targetWeightKg: $0.targetWeightKg,
                                    targetRPE: $0.targetRPE,
                                    percent1RM: $0.percent1RM,
                                    isWarmup: $0.isWarmup
                                )
                            }
                        )
                    },
                    isRestDay: day.isRestDay
                )
            }
        )
        return VolumeMetrics.pullPushRatio(generated)
    }

    private var currentWeek: TrainingWeek? {
        user.activeProgram?.orderedWeeks.first { week in
            week.days.contains { FerrumDates.isSameDay($0.scheduledDate, .now) } || !week.isCompleted
        } ?? user.activeProgram?.orderedWeeks.last
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ratioCard
                    oneRMTable
                    chartCard(title: "Estimated 1RM") {
                        if oneRMPoints.isEmpty {
                            empty
                        } else {
                            Chart(oneRMPoints) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", UnitConverter.display(fromKilograms: point.value, unit: user.preferredUnit))
                                )
                                .foregroundStyle(by: .value("Lift", point.series))
                            }
                            .chartForegroundStyleScale([
                                "Back Squat": FerrumTheme.copper,
                                "Barbell Bench Press": FerrumTheme.iron,
                                "Conventional Deadlift": FerrumTheme.success,
                                "Overhead Press": FerrumTheme.warning
                            ])
                            .frame(height: 220)
                        }
                    }
                    chartCard(title: "Planned vs actual volume") {
                        if volumePoints.isEmpty {
                            empty
                        } else {
                            Chart(volumePoints) { point in
                                BarMark(
                                    x: .value("Week", point.week),
                                    y: .value("Sets", point.sets)
                                )
                                .foregroundStyle(by: .value("Series", point.series))
                                .position(by: .value("Series", point.series))
                            }
                            .frame(height: 260)
                        }
                    }
                    chartCard(title: "Readiness trend") {
                        if readinessPoints.isEmpty {
                            empty
                        } else {
                            Chart(readinessPoints) { point in
                                LineMark(x: .value("Date", point.date), y: .value("Score", point.value))
                                    .foregroundStyle(FerrumTheme.copper)
                                AreaMark(x: .value("Date", point.date), y: .value("Score", point.value))
                                    .foregroundStyle(FerrumTheme.copper.opacity(0.18))
                            }
                            .chartYScale(domain: 0...100)
                            .frame(height: 200)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .ferrumScreen()
        }
    }

    private var oneRMTable: some View {
        FerrumCard {
            Text("Estimated 1RM")
                .font(.headline)
                .foregroundStyle(FerrumTheme.textPrimary)
            if latestOneRMs.isEmpty {
                empty
            } else {
                ForEach(latestOneRMs) { row in
                    HStack {
                        Text(row.lift)
                            .foregroundStyle(FerrumTheme.textPrimary)
                        Spacer()
                        Text(UnitConverter.formatted(row.valueKg, unit: user.preferredUnit))
                            .foregroundStyle(FerrumTheme.copper)
                        Text(row.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(FerrumTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var ratioCard: some View {
        let ratio = currentRatio
        let underPulled = ratio.isFinite && ratio < 1.0
        return FerrumCard {
            Text("Push / pull")
                .font(.headline)
                .foregroundStyle(FerrumTheme.textPrimary)
            Text(ratio.isFinite ? String(format: "Pull is %.2f× push this week", ratio) : "No push work this week")
                .foregroundStyle(FerrumTheme.textSecondary)
            if underPulled {
                Text("Pull volume is below push. Posterior-chain work is flagged.")
                    .foregroundStyle(FerrumTheme.warning)
            }
        }
    }

    private var empty: some View {
        Text("Log sets to populate this chart.")
            .foregroundStyle(FerrumTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func volumeGroup(for exercise: Exercise) -> String {
        if VolumeClassifier.isPush(primaryMuscles: exercise.primaryMuscles, pattern: exercise.movementPattern) {
            return "Push"
        }
        if VolumeClassifier.isPull(primaryMuscles: exercise.primaryMuscles, pattern: exercise.movementPattern) {
            return "Pull"
        }
        let legs: Set<MuscleGroup> = [.quads, .hamstrings, .glutes, .calves]
        if exercise.primaryMuscles.contains(where: { legs.contains($0) }) {
            return "Legs"
        }
        return "Other"
    }

    private func chartCard<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        FerrumCard {
            Text(title)
                .font(.headline)
                .foregroundStyle(FerrumTheme.textPrimary)
            content()
        }
    }
}

private struct ChartPoint: Identifiable {
    var id: String
    var date: Date
    var value: Double
    var series: String
}

private struct VolumePoint: Identifiable {
    var id: String { "\(week)-\(series)" }
    var week: Int
    var series: String
    var sets: Int
}

private struct OneRMRow: Identifiable {
    var id: String { lift }
    var lift: String
    var valueKg: Double
    var date: Date
}

import Foundation
import SwiftData
import TrainingLogic

@MainActor
struct ProgramService {
    var context: ModelContext

    func generateAndPersist(for user: User, startDate: Date = .now) throws {
        user.programs.forEach { context.delete($0) }
        let generated = ProgramEngine.generateProgram(profile: user.athleteProfile)
        let program = TrainingProgram(
            createdAt: .now,
            mode: generated.mode,
            durationWeeks: generated.durationWeeks,
            user: user
        )
        context.insert(program)
        user.programs.append(program)

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)

        for generatedWeek in generated.weeks {
            let storedWeek = TrainingWeek(weekNumber: generatedWeek.weekNumber, block: generatedWeek.block, program: program)
            context.insert(storedWeek)
            program.weeks.append(storedWeek)

            let weekStart = calendar.date(byAdding: .day, value: (generatedWeek.weekNumber - 1) * 7, to: start) ?? start
            for day in generatedWeek.days {
                let date = calendar.date(byAdding: .day, value: day.dayIndex, to: weekStart) ?? weekStart
                let storedDay = WorkoutDay(
                    dayIndex: day.dayIndex,
                    scheduledDate: date,
                    title: day.title,
                    isRestDay: day.isRestDay,
                    week: storedWeek
                )
                context.insert(storedDay)
                storedWeek.days.append(storedDay)
                populate(storedDay, from: day, snapshotOriginal: true)
            }
        }
        try context.save()
    }

    func todaysWorkout(for user: User, now: Date = .now) -> WorkoutDay? {
        guard let program = user.activeProgram else { return nil }
        let days = program.orderedWeeks.flatMap(\.orderedDays)
        let start = Calendar.current.startOfDay(for: now)
        if let today = days.first(where: { FerrumDates.isSameDay($0.scheduledDate, now) }) {
            return today
        }
        if let overdue = days.first(where: {
            Calendar.current.startOfDay(for: $0.scheduledDate) <= start && !$0.isCompleted && !$0.isRestDay
        }) {
            return overdue
        }
        return days.first(where: { !$0.isCompleted && !$0.isRestDay })
    }

    func checkIn(for user: User, on date: Date = .now) -> ReadinessCheckIn? {
        let key = ReadinessCheckIn.dayKey(for: date)
        return user.checkIns.first { $0.dayKey == key }
    }

    func applyReadiness(_ result: ReadinessResult, input: ReadinessCheckInInput, to day: WorkoutDay, user: User) throws {
        if let existing = checkIn(for: user, on: day.scheduledDate) {
            context.delete(existing)
        }
        let checkIn = ReadinessCheckIn(
            date: FerrumDates.startOfDay(day.scheduledDate),
            sleep: input.sleep,
            energy: input.energy,
            motivation: input.motivation,
            soreness: input.soreness,
            stress: input.stress,
            score: result.score,
            band: result.band,
            user: user
        )
        context.insert(checkIn)
        user.checkIns.append(checkIn)

        let planned = originalPlannedWorkout(from: day)
        let adjusted = ReadinessEngine.apply(result, to: planned, profile: user.athleteProfile)
        replaceExercises(on: day, with: adjusted, snapshotOriginal: false)
        day.appliedLoadMultiplier = result.loadMultiplier
        day.appliedVolumeMultiplier = result.volumeMultiplier
        day.appliedReadinessScore = result.score
        day.appliedReadinessBand = result.band.rawValue
        day.title = adjusted.title
        day.isRestDay = adjusted.isRestDay
        try context.save()
    }

    func completeSet(_ set: SetLog, reps: Int, weightKg: Double, rpe: Double) throws {
        set.actualReps = reps
        set.actualWeightKg = weightKg
        set.actualRPE = rpe
        set.isCompleted = true
        set.completedAt = .now
        refreshDayCompletion(set.exercise?.workoutDay)
        try context.save()
        if let user = set.exercise?.workoutDay?.week?.program?.user {
            try progressIfNeeded(for: user)
        }
    }

    func undoSet(_ set: SetLog) throws {
        set.actualReps = nil
        set.actualWeightKg = nil
        set.actualRPE = nil
        set.isCompleted = false
        set.completedAt = nil
        if let day = set.exercise?.workoutDay {
            day.isCompleted = false
            day.isSkipped = false
        }
        try context.save()
    }

    func skip(_ day: WorkoutDay) throws {
        guard !day.isRestDay else { return }
        day.isSkipped = true
        day.isCompleted = true
        try context.save()
        if let user = day.week?.program?.user {
            try progressIfNeeded(for: user)
        }
    }

    func postpone(_ day: WorkoutDay) throws {
        guard !day.isRestDay else { return }
        if let rest = nextRestDay(after: day) {
            let original = day.scheduledDate
            day.scheduledDate = rest.scheduledDate
            rest.scheduledDate = original
        } else {
            shiftFollowingDays(from: day, by: 1)
        }
        try context.save()
    }

    func substitute(_ exercise: Exercise, with definition: ExerciseDefinition, user: User) throws {
        guard exercise.catalogID != definition.id else { return }
        let previousID = exercise.catalogID
        exercise.catalogID = definition.id
        exercise.name = definition.name
        exercise.movementPattern = definition.movementPattern
        exercise.primaryMuscles = definition.primaryMuscles
        for set in exercise.orderedSets {
            let percent = set.percent1RM ?? inferredPercent(for: set, previousID: previousID, user: user)
            set.percent1RM = percent
            set.targetWeightKg = OneRepMax.workingLoadKg(for: definition, profile: user.athleteProfile, percent1RM: percent)
            if !set.isCompleted {
                set.actualWeightKg = nil
                set.actualReps = nil
                set.actualRPE = nil
            }
        }
        if let day = exercise.workoutDay {
            updateOriginalSnapshot(on: day, replacing: previousID, with: plannedExercise(from: exercise))
        }
        try context.save()
    }

    func progressIfNeeded(for user: User) throws {
        guard let program = user.activeProgram else { return }
        let weeks = program.orderedWeeks
        for (index, week) in weeks.enumerated() {
            guard week.isCompleted, !week.didProgressNextWeek else { continue }
            let nextIndex = index + 1
            guard nextIndex < weeks.count else {
                week.didProgressNextWeek = true
                try context.save()
                continue
            }
            try applyProgression(from: week, to: weeks[nextIndex], user: user)
            week.didProgressNextWeek = true
            try context.save()
        }
    }

    func applyProgression(from completed: TrainingWeek, to next: TrainingWeek, user: User) throws {
        let completedExercises: [CompletedExercise] = completed.orderedDays.flatMap(\.orderedExercises).map { exercise in
            CompletedExercise(
                catalogID: exercise.catalogID,
                sets: exercise.orderedSets.map {
                    CompletedSet(
                        targetReps: $0.targetReps,
                        targetWeightKg: $0.targetWeightKg,
                        targetRPE: $0.targetRPE,
                        actualReps: $0.actualReps,
                        actualWeightKg: $0.actualWeightKg,
                        actualRPE: $0.actualRPE,
                        isCompleted: $0.isCompleted,
                        isWarmup: $0.isWarmup
                    )
                }
            )
        }
        let setCounts = Dictionary(uniqueKeysWithValues: completedExercises.map {
            ($0.catalogID, $0.sets.filter { !$0.isWarmup }.count)
        })
        let recent = user.checkIns.sorted { $0.date > $1.date }.prefix(7)
        let averageSoreness = recent.isEmpty ? 3.0 : Double(recent.map(\.soreness).reduce(0, +)) / Double(recent.count)
        let adjustments = ProgressionEngine.adjustments(
            exercises: completedExercises,
            currentSetCounts: setCounts,
            profile: user.athleteProfile,
            averageSoreness: averageSoreness
        )
        let generatedNext = plannedWeek(from: next)
        let progressed = ProgressionEngine.apply(adjustments: adjustments, to: generatedNext, profile: user.athleteProfile)
        for day in next.orderedDays {
            day.exercises.forEach { context.delete($0) }
        }
        for plannedDay in progressed.days {
            guard let stored = next.orderedDays.first(where: { $0.dayIndex == plannedDay.dayIndex }) else { continue }
            populate(stored, from: plannedDay, snapshotOriginal: true)
        }
        try context.save()
    }

    func deleteAllData() throws {
        try context.delete(model: User.self)
        try context.delete(model: TrainingProgram.self)
        try context.delete(model: TrainingWeek.self)
        try context.delete(model: WorkoutDay.self)
        try context.delete(model: Exercise.self)
        try context.delete(model: SetLog.self)
        try context.delete(model: ReadinessCheckIn.self)
        try context.save()
    }

    private func populate(_ storedDay: WorkoutDay, from planned: PlannedWorkout, snapshotOriginal: Bool) {
        storedDay.exercises.forEach { context.delete($0) }
        storedDay.title = planned.title
        storedDay.isRestDay = planned.isRestDay
        for (index, plannedExercise) in planned.exercises.enumerated() {
            let stored = Exercise(
                catalogID: plannedExercise.catalogID,
                name: plannedExercise.name,
                movementPattern: plannedExercise.movementPattern,
                primaryMuscles: plannedExercise.primaryMuscles,
                role: plannedExercise.role,
                sortIndex: index,
                plannedSetCount: plannedExercise.sets.filter { !$0.isWarmup }.count,
                workoutDay: storedDay
            )
            context.insert(stored)
            storedDay.exercises.append(stored)
            for (setIndex, plannedSet) in plannedExercise.sets.enumerated() {
                let log = SetLog(
                    setIndex: setIndex,
                    targetReps: plannedSet.targetReps,
                    targetWeightKg: plannedSet.targetWeightKg,
                    targetRPE: plannedSet.targetRPE,
                    isWarmup: plannedSet.isWarmup,
                    percent1RM: plannedSet.percent1RM,
                    exercise: stored
                )
                context.insert(log)
                stored.setLogs.append(log)
            }
        }
        if snapshotOriginal {
            storeOriginalPlan(planned, on: storedDay)
        }
    }

    private func replaceExercises(on day: WorkoutDay, with planned: PlannedWorkout, snapshotOriginal: Bool) {
        populate(day, from: planned, snapshotOriginal: snapshotOriginal)
    }

    private func originalPlannedWorkout(from day: WorkoutDay) -> PlannedWorkout {
        if let data = day.originalPlanJSON,
           let decoded = try? JSONDecoder().decode(PlannedWorkout.self, from: data) {
            return decoded
        }
        let current = plannedWorkout(from: day)
        storeOriginalPlan(current, on: day)
        return current
    }

    private func storeOriginalPlan(_ planned: PlannedWorkout, on day: WorkoutDay) {
        day.originalPlanJSON = try? JSONEncoder().encode(planned)
    }

    private func updateOriginalSnapshot(on day: WorkoutDay, replacing previousID: String, with replacement: PlannedExercise) {
        var baseline = originalPlannedWorkout(from: day)
        if let index = baseline.exercises.firstIndex(where: { $0.catalogID == previousID }) {
            baseline.exercises[index] = replacement
            storeOriginalPlan(baseline, on: day)
        }
    }

    private func plannedWorkout(from day: WorkoutDay) -> PlannedWorkout {
        PlannedWorkout(
            dayIndex: day.dayIndex,
            title: day.title,
            exercises: day.orderedExercises.map(plannedExercise(from:)),
            isRestDay: day.isRestDay
        )
    }

    private func plannedExercise(from exercise: Exercise) -> PlannedExercise {
        PlannedExercise(
            catalogID: exercise.catalogID,
            name: exercise.name,
            movementPattern: exercise.movementPattern,
            primaryMuscles: exercise.primaryMuscles,
            role: exercise.role,
            sets: exercise.orderedSets.map {
                PlannedSet(
                    targetReps: $0.targetReps,
                    targetWeightKg: $0.targetWeightKg,
                    targetRPE: $0.targetRPE,
                    percent1RM: $0.percent1RM,
                    isWarmup: $0.isWarmup
                )
            }
        )
    }

    private func plannedWeek(from week: TrainingWeek) -> TrainingLogic.TrainingWeek {
        TrainingLogic.TrainingWeek(
            weekNumber: week.weekNumber,
            block: week.block,
            days: week.orderedDays.map(plannedWorkout(from:))
        )
    }

    private func refreshDayCompletion(_ day: WorkoutDay?) {
        guard let day, !day.isRestDay else { return }
        let remaining = day.exercises.flatMap(\.setLogs).contains { !$0.isCompleted }
        day.isCompleted = !remaining
        if remaining {
            day.isSkipped = false
        }
    }

    private func nextRestDay(after day: WorkoutDay) -> WorkoutDay? {
        guard let program = day.week?.program else { return nil }
        let days = program.orderedWeeks.flatMap(\.orderedDays)
        return days.first {
            $0.isRestDay
                && !$0.isSkipped
                && $0.scheduledDate > day.scheduledDate
        }
    }

    private func shiftFollowingDays(from day: WorkoutDay, by days: Int) {
        guard let program = day.week?.program else { return }
        let calendar = Calendar.current
        let affected = program.orderedWeeks
            .flatMap(\.orderedDays)
            .filter { $0.scheduledDate >= day.scheduledDate }
        for item in affected {
            item.scheduledDate = calendar.date(byAdding: .day, value: days, to: item.scheduledDate) ?? item.scheduledDate
        }
    }

    private func inferredPercent(for set: SetLog, previousID: String, user: User) -> Double {
        if let percent = set.percent1RM, percent > 0 { return percent }
        guard let previous = ExerciseLibrary.exercise(id: previousID) else { return 0.70 }
        let oneRM = OneRepMax.working1RM(lift: previous.relatedLift, profile: user.athleteProfile) * previous.loadFraction
        guard oneRM > 0 else { return 0.70 }
        return set.targetWeightKg / oneRM
    }
}

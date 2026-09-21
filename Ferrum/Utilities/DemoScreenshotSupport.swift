import Foundation
import SwiftData
import TrainingLogic

enum DemoScreenshotSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoScreenshots")
    }

    static var initialTab: FerrumTab {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-demoTab"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1) else {
            return .today
        }
        switch ProcessInfo.processInfo.arguments[index + 1].lowercased() {
        case "log": return .log
        case "analytics": return .analytics
        case "settings": return .settings
        default: return .today
        }
    }

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard isEnabled else { return }
        let existing = try? context.fetch(FetchDescriptor<User>())
        if let user = existing?.first(where: \.hasCompletedOnboarding) {
            enrichAnalyticsIfNeeded(user: user, context: context)
            return
        }

        let user = User(
            trainingMode: .powerbuilding,
            experienceLevel: .intermediate,
            bodyweightKg: 82,
            preferredUnit: .kilogram,
            squatPR: 160,
            benchPR: 110,
            deadliftPR: 200,
            ohpPR: 70,
            hasCompletedOnboarding: true
        )
        context.insert(user)

        let service = ProgramService(context: context)
        try? service.generateAndPersist(for: user, startDate: .now)

        if let today = service.todaysWorkout(for: user), !today.isRestDay {
            let input = ReadinessCheckInInput(sleep: 4, energy: 4, motivation: 4, soreness: 2, stress: 2)
            let result = ReadinessEngine.evaluate(input)
            try? service.applyReadiness(result, input: input, to: today, user: user)
        }

        enrichAnalyticsIfNeeded(user: user, context: context)
        try? context.save()
    }

    @MainActor
    private static func enrichAnalyticsIfNeeded(user: User, context: ModelContext) {
        guard let program = user.activeProgram else { return }
        let trainingDays = program.orderedWeeks
            .prefix(2)
            .flatMap(\.trainingDays)
            .filter { Calendar.current.startOfDay(for: $0.scheduledDate) < Calendar.current.startOfDay(for: .now) }

        for day in trainingDays.prefix(4) {
            for exercise in day.orderedExercises {
                for set in exercise.orderedSets where !set.isWarmup {
                    set.actualReps = set.targetReps
                    set.actualWeightKg = set.targetWeightKg
                    set.actualRPE = set.targetRPE
                    set.isCompleted = true
                    set.completedAt = day.scheduledDate
                }
            }
            day.isCompleted = true
        }
        try? context.save()
    }
}

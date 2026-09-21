import SwiftUI
import SwiftData
import TrainingLogic

struct DashboardView: View {
    @Bindable var user: User
    @Binding var selectedTab: FerrumTab
    @Binding var focusedDayID: PersistentIdentifier?
    @Environment(\.modelContext) private var context

    private var service: ProgramService { ProgramService(context: context) }

    private var today: WorkoutDay? {
        service.todaysWorkout(for: user)
    }

    private var todaysCheckIn: ReadinessCheckIn? {
        service.checkIn(for: user)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if todaysCheckIn == nil {
                        readinessCTA
                    } else if let checkIn = todaysCheckIn {
                        readinessChip(checkIn)
                    }
                    if let today {
                        if today.isRestDay {
                            restCard(today)
                        } else {
                            sessionCard(today)
                            startSessionButton(today)
                            if let preview = today.nextIncompleteSet {
                                nextSetCard(preview.0, preview.1)
                            }
                        }
                    } else {
                        FerrumCard {
                            Text("No session queued")
                                .font(.headline)
                                .foregroundStyle(FerrumTheme.textPrimary)
                            Text("The current mesocycle is complete. Regenerate from Settings when you are ready for another 12 weeks.")
                                .foregroundStyle(FerrumTheme.textSecondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .ferrumScreen()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ferrum")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundStyle(FerrumTheme.textPrimary)
            if let week = today?.week {
                HStack(spacing: 8) {
                    chip("Week \(week.weekNumber)")
                    chip(week.block.rawValue.capitalized)
                    chip(user.trainingMode.displayName)
                }
            }
        }
    }

    private var readinessCTA: some View {
        NavigationLink {
            if let today, !today.isRestDay {
                ReadinessView(user: user, day: today)
            } else {
                Text("No session to adjust")
                    .ferrumScreen()
            }
        } label: {
            FerrumCard {
                Text("Readiness check-in")
                    .font(.headline)
                    .foregroundStyle(FerrumTheme.copper)
                Text("Score sleep, energy, motivation, soreness, and stress before training. Today's plan will auto-regulate.")
                    .foregroundStyle(FerrumTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func readinessChip(_ checkIn: ReadinessCheckIn) -> some View {
        FerrumCard {
            HStack {
                VStack(alignment: .leading) {
                    Text("Readiness \(Int(checkIn.score.rounded()))")
                        .font(.headline)
                        .foregroundStyle(FerrumTheme.textPrimary)
                    Text(checkIn.band.displayName)
                        .foregroundStyle(FerrumTheme.copper)
                }
                Spacer()
                NavigationLink("Edit") {
                    if let today, !today.isRestDay {
                        ReadinessView(user: user, day: today)
                    }
                }
            }
        }
    }

    private func restCard(_ day: WorkoutDay) -> some View {
        FerrumCard {
            Text("Rest day")
                .font(.title2.weight(.semibold))
                .foregroundStyle(FerrumTheme.textPrimary)
            Text("No training session is scheduled. The next lift will appear here when it is due.")
                .foregroundStyle(FerrumTheme.textSecondary)
            if let next = nextTraining(after: day) {
                Text("Next: \(next.title)")
                    .foregroundStyle(FerrumTheme.copper)
            }
        }
    }

    private func sessionCard(_ day: WorkoutDay) -> some View {
        FerrumCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FerrumTheme.textPrimary)
                    Text("\(day.orderedExercises.count) lifts · \(day.exercises.flatMap(\.setLogs).filter { !$0.isWarmup }.count) working sets")
                        .foregroundStyle(FerrumTheme.textSecondary)
                }
                Spacer()
                if day.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(FerrumTheme.success)
                }
            }
            ForEach(day.orderedExercises, id: \.persistentModelID) { exercise in
                HStack {
                    Text(exercise.name)
                        .foregroundStyle(FerrumTheme.textPrimary)
                    Spacer()
                    Text("\(exercise.orderedSets.filter { $0.isCompleted && !$0.isWarmup }.count)/\(exercise.orderedSets.filter { !$0.isWarmup }.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(FerrumTheme.textSecondary)
                }
            }
        }
    }

    private func startSessionButton(_ day: WorkoutDay) -> some View {
        Button {
            focusedDayID = day.persistentModelID
            selectedTab = .log
        } label: {
            Text(day.isCompleted ? "Review session" : "Start session")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CopperButtonStyle())
    }

    private func nextSetCard(_ exercise: Exercise, _ set: SetLog) -> some View {
        FerrumCard {
            Text(set.isWarmup ? "Next warm-up" : "Next set")
                .font(.caption)
                .foregroundStyle(FerrumTheme.copper)
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(FerrumTheme.textPrimary)
            Text("\(set.targetReps) × \(UnitConverter.formatted(set.targetWeightKg, unit: user.preferredUnit)) @ RPE \(String(format: "%g", set.targetRPE))")
                .foregroundStyle(FerrumTheme.textSecondary)
        }
    }

    private func nextTraining(after day: WorkoutDay) -> WorkoutDay? {
        user.activeProgram?.orderedWeeks
            .flatMap(\.orderedDays)
            .first { !$0.isRestDay && $0.scheduledDate > day.scheduledDate && !$0.isCompleted }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(FerrumTheme.elevated)
            .foregroundStyle(FerrumTheme.copper)
            .clipShape(Capsule())
    }
}

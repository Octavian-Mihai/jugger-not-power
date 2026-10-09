import SwiftUI
import SwiftData
import FerrumCore

struct TodayView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query(filter: #Predicate<Program> { $0.isActive }) private var active: [Program]
    @Query(sort: \ReadinessEntry.date, order: .reverse) private var readiness: [ReadinessEntry]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var allSets: [LoggedSet]
    @State private var showCheckIn = false
    @State private var showMaxes = false
    @State private var workout: WorkoutSession?

    private var program: Program? { active.first }
    private var todaysReadiness: ReadinessEntry? { readiness.first(where: { $0.date.isToday }) }
    private var inProgress: WorkoutSession? { sessions.first(where: { !$0.isFinished }) }
    private var adjustment: ReadinessAdjustment {
        todaysReadiness.map { Readiness.adjustment(for: $0.input) } ?? .neutral
    }

    var body: some View {
        Screen(title: "Today") {
            if let inProgress {
                resumeCard(inProgress)
            } else if let program {
                planCard(program)
            } else {
                emptyCard
            }
            if MainLift.allCases.contains(where: { profile.oneRepMaxKg($0) <= 0 }) { maxesCard }
            readinessCard
            recent
        }
        .sheet(isPresented: $showCheckIn) { ReadinessSheet() }
        .sheet(isPresented: $showMaxes) { MaxesSheet(profile: profile) }
        .fullScreenCover(item: $workout) { session in
            WorkoutView(session: session, profile: profile)
        }
    }

    // MARK: cards
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No active program").font(.title2.bold()).foregroundStyle(t.text)
            Text("Generate a program or build your own from the Programs tab.").foregroundStyle(t.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func resumeCard(_ s: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(text: "Workout in progress")
            Text(s.dayName).font(.title2.bold()).foregroundStyle(t.text)
            Text("\(s.sets.filter(\.isDone).count) of \(s.sets.count) sets done").foregroundStyle(t.secondary)
            Button("Resume workout") { workout = s }.buttonStyle(PrimaryButton())
            Button("Discard", role: .destructive) { context.delete(s) }.font(.subheadline)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func planCard(_ program: Program) -> some View {
        let plan = program.plan
        let pos = plan.position(completedSessions: program.completedSessions)
        return VStack(alignment: .leading, spacing: 12) {
            if pos.isFinished {
                Text("Program complete").font(.title2.bold()).foregroundStyle(t.text)
                Text("Nice work. Generate a new program or restart this one.").foregroundStyle(t.secondary)
                Button("Restart program") { program.completedSessions = 0 }.buttonStyle(PrimaryButton())
            } else {
                let block = plan.blocks[pos.blockIndex]
                let day = block.days[pos.dayIndex]
                SectionHeader(text: "\(block.name) · Week \(pos.weekInBlock + 1) of \(block.weeks)\(pos.isDeload ? " · Deload" : "")")
                Text(day.name).font(.largeTitle.bold()).foregroundStyle(t.text)
                let resolved = Resolver.resolve(day: day, block: block, weekInBlock: pos.weekInBlock, isDeload: pos.isDeload,
                                                context: store.loadContext(profile: profile, sets: allSets), library: store.library,
                                                readiness: adjustment)
                ForEach(resolved) { ex in
                    HStack(spacing: 12) {
                        ExerciseThumb(file: store.library.exercise(ex.exerciseID)?.image, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.library.name(for: ex.exerciseID)).font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                            Text(summary(ex)).font(.caption).foregroundStyle(t.secondary)
                        }
                        Spacer()
                    }
                }
                if todaysReadiness == nil {
                    Button { showCheckIn = true } label: { Label("Check in to adjust today's load", systemImage: "heart.text.square") }
                        .buttonStyle(PrimaryButton(prominent: false))
                }
                Button("Start workout") { start(program, resolved: resolved, day: day, block: block, pos: pos) }
                    .buttonStyle(PrimaryButton())
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func summary(_ ex: ResolvedExercise) -> String {
        guard let first = ex.sets.first else { return "" }
        let reps = first.isRange ? "\(first.repsLow)-\(first.reps)" : "\(first.reps)"
        let w = first.weight.map { " @ \(store.format(store.toKg($0)))" } ?? ""
        return "\(ex.sets.count) × \(reps)\(w) · RIR \(Int(first.targetRIR))"
    }

    private var maxesCard: some View {
        let missing = MainLift.allCases.filter { profile.oneRepMaxKg($0) <= 0 }.map(\.title).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Set your maxes")
            Text("Add your 1RM for \(missing) so Ferrum can show the weight for each set.").foregroundStyle(t.secondary)
            Button("Enter maxes") { showMaxes = true }.buttonStyle(PrimaryButton())
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private var readinessCard: some View {
        let adj = adjustment
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Readiness")
            if let e = todaysReadiness {
                HStack {
                    Text("\(e.score)").font(.system(size: 44, weight: .black)).foregroundStyle(color(adj.band))
                    VStack(alignment: .leading) {
                        Text(adj.band.title).font(.headline).foregroundStyle(t.text)
                        Text(adj.summary).font(.caption).foregroundStyle(t.secondary)
                    }
                }
                Button("Update check-in") { showCheckIn = true }.font(.subheadline)
            } else {
                Text("How are you feeling? A 20-second check-in tunes today's volume and loads.").foregroundStyle(t.secondary)
                Button("Check in") { showCheckIn = true }.buttonStyle(PrimaryButton(prominent: false))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func color(_ band: ReadinessBand) -> Color {
        switch band { case .great, .good: return t.good; case .moderate: return t.warn; case .low: return t.bad }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Recent sessions")
            let done = sessions.filter(\.isFinished).prefix(5)
            if done.isEmpty { Text("Finished workouts appear here.").foregroundStyle(t.secondary) }
            ForEach(Array(done)) { s in
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.dayName).foregroundStyle(t.text).font(.subheadline.weight(.semibold))
                        Text(s.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(t.secondary)
                    }
                    Spacer()
                    Text("\(s.sets.filter(\.isDone).count) sets").font(.caption).foregroundStyle(t.secondary)
                }.card()
            }
        }
    }

    // MARK: start
    private func start(_ program: Program, resolved: [ResolvedExercise], day: PlannedDay, block: Block, pos: PlanPosition) {
        let session = WorkoutSession(programID: program.id, dayName: day.name, blockName: block.name,
                                     weekLabel: "Week \(pos.weekInBlock + 1)", readinessScore: todaysReadiness?.score ?? 0)
        context.insert(session)
        for (order, ex) in resolved.enumerated() {
            for s in ex.sets {
                let kg = s.weight.map { store.toKg($0) } ?? 0
                let set = LoggedSet(exerciseID: ex.exerciseID, exerciseOrder: order, setIndex: s.index, restSeconds: ex.restSeconds,
                                    targetReps: s.reps, targetRepsLow: s.repsLow, targetRIR: s.targetRIR, targetWeightKg: kg)
                set.session = session
                context.insert(set)
            }
        }
        workout = session
    }
}

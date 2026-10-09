import SwiftUI
import SwiftData
import FerrumCore

struct WorkoutView: View {
    @Bindable var session: WorkoutSession
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query private var programs: [Program]
    @Query private var allSets: [LoggedSet]
    @State private var restEnd: Date?
    @State private var restTotal = 0
    @State private var confirmFinish = false
    @State private var infoExercise: ExerciseInfo?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(session.exerciseIDsInOrder, id: \.self) { id in exerciseCard(id) }
                        Button("Finish workout") { confirmFinish = true }.buttonStyle(PrimaryButton()).padding(.top, 8)
                    }.padding(16).padding(.bottom, restEnd == nil ? 20 : 90)
                }
                .scrollDismissesKeyboard(.interactively)
                if let restEnd { RestBar(end: restEnd, total: restTotal) { self.restEnd = nil } }
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle(session.dayName)
            .keyboardDoneBar()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish") { finish() }
                Button("Keep training", role: .cancel) {}
            } message: {
                Text("\(session.sets.filter(\.isDone).count) of \(session.sets.count) sets logged.")
            }
            .sheet(item: $infoExercise) { ExerciseDetailView(exercise: $0) }
        }
    }

    private func exerciseCard(_ id: String) -> some View {
        let sets = session.sortedSets.filter { $0.exerciseID == id }
        let info = store.library.exercise(id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ExerciseThumb(file: info?.image, size: 52)
                VStack(alignment: .leading) {
                    Text(store.library.name(for: id)).font(.headline).foregroundStyle(t.text)
                    if let s = sets.first {
                        let reps = s.targetRepsLow != s.targetReps ? "\(s.targetRepsLow)-\(s.targetReps)" : "\(s.targetReps)"
                        Text("Target \(reps) reps · RIR \(Int(s.targetRIR))").font(.caption).foregroundStyle(t.secondary)
                    }
                }
                Spacer()
                if let info { Button { infoExercise = info } label: { Image(systemName: "info.circle") } }
            }
            HStack {
                Text("SET").frame(width: 30, alignment: .leading)
                Text(store.unit.label.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("RIR").frame(width: 62)
                Text("").frame(width: 40)
            }.font(.caption2.weight(.bold)).foregroundStyle(t.secondary)
            ForEach(sets) { set in
                SetRow(set: set, index: sets.firstIndex(of: set) ?? 0) { completed in
                    didToggle(set, in: sets, done: completed)
                }
            }
            Button { addSet(to: sets) } label: { Label("Add set", systemImage: "plus") }
                .font(.subheadline.weight(.semibold))
        }.card()
    }

    private func addSet(to sets: [LoggedSet]) {
        guard let last = sets.last else { return }
        let n = LoggedSet(exerciseID: last.exerciseID, exerciseOrder: last.exerciseOrder, setIndex: last.setIndex + 1,
                          restSeconds: last.restSeconds, targetReps: last.targetReps, targetRepsLow: last.targetRepsLow,
                          targetRIR: last.targetRIR, targetWeightKg: last.weightKg)
        n.session = session
        context.insert(n)
    }

    /// After a set is checked off, re-aim the next untouched set from how this one went.
    private func didToggle(_ set: LoggedSet, in sets: [LoggedSet], done: Bool) {
        set.date = .now
        guard done else { return }
        restTotal = set.restSeconds
        restEnd = Date().addingTimeInterval(Double(set.restSeconds))
        guard set.weightKg > 0, set.reps > 0,
              let next = sets.first(where: { !$0.isDone && $0.setIndex > set.setIndex }) else { return }
        let weight = store.display(set.weightKg)
        let suggested = Estimation.nextLoad(afterWeight: weight, reps: set.reps, rir: set.rir,
                                            nextReps: next.targetReps, nextRIR: next.targetRIR, unit: store.unit)
        next.weightKg = store.toKg(suggested)
    }

    private func finish() {
        let now = Date()
        // Drop sets that were never completed.
        for s in session.sets where !s.isDone { context.delete(s) }
        session.isFinished = true
        session.finishedAt = now
        if let pid = session.programID, let program = programs.first(where: { $0.id == pid }) {
            program.completedSessions += 1
        }
        dismiss()
    }
}

struct SetRow: View {
    @Bindable var set: LoggedSet
    let index: Int
    let onToggle: (Bool) -> Void
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)").font(.headline).frame(width: 30, alignment: .leading).foregroundStyle(t.secondary)
            NumberField(value: Binding(get: { store.display(set.weightKg) }, set: { set.weightKg = store.toKg($0) }))
                .multilineTextAlignment(.center).textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
            NumberField(value: $set.reps.asDouble, decimals: false)
                .multilineTextAlignment(.center).textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
            Menu {
                ForEach([0, 1, 2, 3, 4, 5], id: \.self) { r in
                    Button(r == 5 ? "5+ (easy)" : "\(r)") { set.rir = Double(r) }
                }
            } label: {
                Text(set.rir >= 5 ? "5+" : "\(Int(set.rir))").font(.headline).frame(width: 62, height: 34)
                    .background(rirColor.opacity(0.25), in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(t.text)
            }
            Button {
                set.isDone.toggle(); onToggle(set.isDone)
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle").font(.title2)
                    .foregroundStyle(set.isDone ? t.good : t.secondary)
            }.frame(width: 40)
        }
        .opacity(set.isDone ? 0.65 : 1)
    }

    private var rirColor: Color {
        switch set.rir { case ..<1.5: return t.bad; case ..<3.5: return t.good; default: return t.warn }
    }
}

struct RestBar: View {
    let end: Date
    let total: Int
    let onSkip: () -> Void
    @Environment(\.theme) private var t
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let left = max(0, Int(end.timeIntervalSince(ctx.date).rounded(.up)))
            HStack {
                Image(systemName: "timer")
                Text(String(format: "%d:%02d", left / 60, left % 60)).font(.title2.monospacedDigit().bold())
                Text(left == 0 ? "Rest over" : "Rest").foregroundStyle(t.onAccent.opacity(0.7))
                Spacer()
                Button("Skip", action: onSkip).buttonStyle(.bordered).tint(t.onAccent)
            }
            .padding(.horizontal, 20).frame(height: 66)
            .foregroundStyle(t.onAccent).background(t.accent)
        }
    }
}

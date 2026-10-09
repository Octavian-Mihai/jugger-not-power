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
    @State private var restExerciseID: String?
    @State private var keypad = KeypadController()
    @State private var confirmFinish = false
    @State private var infoExercise: ExerciseInfo?
    @State private var page = 0

    var body: some View {
        NavigationStack {
            Group { if profile.swipeWorkout { pager } else { scroller } }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        if let restEnd {
                            RestBar(end: restEnd, onAdjust: adjustRest) { self.restEnd = nil }
                        }
                        if keypad.isActive {
                            WorkoutKeypad(keypad: keypad, profile: profile, onComplete: completeFromKeypad)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: keypad.isActive)
                }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle(session.dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { withAnimation { profile.swipeWorkout.toggle() } } label: {
                        Image(systemName: profile.swipeWorkout ? "list.bullet" : "rectangle.stack")
                    }
                    .accessibilityLabel(profile.swipeWorkout ? "Switch to scrolling list" : "Switch to swipe mode")
                }
            }
            .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish") { keypad.deactivate(); finish() }
                Button("Keep training", role: .cancel) {}
            } message: {
                Text("\(session.sets.filter(\.isDone).count) of \(session.sets.count) sets logged.")
            }
            .sheet(item: $infoExercise) { ExerciseDetailView(exercise: $0) }
        }
    }

    private var exerciseIDs: [String] { session.exerciseIDsInOrder }

    /// All exercises in one scrolling list.
    private var scroller: some View {
        KeypadScroll(keypad: keypad) {
            VStack(alignment: .leading, spacing: 20) {
                sessionStatus
                ForEach(exerciseIDs, id: \.self) { id in exerciseCard(id) }
                Button("Finish workout") { confirmFinish = true }.buttonStyle(PrimaryButton()).padding(.top, 8)
            }.padding(16).padding(.bottom, 20)
        }
    }

    /// Readiness and in-session adjustments, so it's clear why the loads are what they are.
    @ViewBuilder private var sessionStatus: some View {
        let hasReadiness = session.readinessScore > 0
        if hasReadiness || !session.easeNote.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if hasReadiness {
                    let pct = Int(((session.loadMultiplier - 1) * 100).rounded())
                    Label("Readiness \(session.readinessScore) · " + (pct == 0 ? "loads as planned" : "loads \(pct)%"),
                          systemImage: "heart.text.square").font(.footnote).foregroundStyle(t.secondary)
                }
                if !session.easeNote.isEmpty {
                    Label(session.easeNote, systemImage: "gauge.with.needle").font(.footnote.weight(.semibold)).foregroundStyle(t.warn)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One exercise per screen; swipe sideways (or use the arrows) to move on.
    private var pager: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { go(-1) } label: { Image(systemName: "chevron.left") }.disabled(page == 0)
                VStack(spacing: 6) {
                    Text("Exercise \(min(page, max(exerciseIDs.count - 1, 0)) + 1) of \(exerciseIDs.count)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                    HStack(spacing: 5) {
                        ForEach(exerciseIDs.indices, id: \.self) { i in
                            Capsule().fill(i == page ? t.accent : (exerciseDone(i) ? t.good : t.secondary.opacity(0.35)))
                                .frame(height: 5)
                        }
                    }
                }
                Button { go(1) } label: { Image(systemName: "chevron.right") }.disabled(page >= exerciseIDs.count - 1)
            }
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            TabView(selection: $page) {
                ForEach(Array(exerciseIDs.enumerated()), id: \.element) { i, id in
                    KeypadScroll(keypad: keypad) {
                        VStack(alignment: .leading, spacing: 16) {
                            if i == 0 { sessionStatus }
                            exerciseCard(id)
                            if i < exerciseIDs.count - 1 {
                                Button { go(1) } label: { Label("Next exercise", systemImage: "arrow.right") }.buttonStyle(PrimaryButton(prominent: false))
                            } else {
                                Button("Finish workout") { confirmFinish = true }.buttonStyle(PrimaryButton())
                            }
                        }.padding(16).padding(.bottom, 20)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: page) { _, _ in keypad.deactivate() }
        }
        .onAppear { page = min(page, max(exerciseIDs.count - 1, 0)) }
    }

    private func go(_ delta: Int) {
        keypad.deactivate()
        withAnimation { page = min(max(page + delta, 0), max(exerciseIDs.count - 1, 0)) }
    }

    private func exerciseDone(_ i: Int) -> Bool {
        guard exerciseIDs.indices.contains(i) else { return false }
        let sets = session.sets.filter { $0.exerciseID == exerciseIDs[i] }
        return !sets.isEmpty && sets.allSatisfy(\.isDone)
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
                SetRow(set: set, index: sets.firstIndex(of: set) ?? 0, keypad: keypad) { completed in
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

    /// Check-off from the keypad's "Complete Set": log it, then jump to the next set of the same exercise.
    private func completeFromKeypad(_ set: LoggedSet) {
        let sets = session.sortedSets.filter { $0.exerciseID == set.exerciseID }
        set.isDone = true
        didToggle(set, in: sets, done: true)
        if let next = sets.first(where: { !$0.isDone && $0.setIndex > set.setIndex }) {
            keypad.activate(next, field: .weight, store: store)
        } else {
            keypad.deactivate()
        }
    }

    /// After a set is checked off: start rest, re-aim the next set from how this one went, and
    /// ease (or nudge up) the exercises still to come if the finished ones ran hard (or easy).
    private func didToggle(_ set: LoggedSet, in sets: [LoggedSet], done: Bool) {
        set.date = .now
        guard done else { return }
        restExerciseID = set.exerciseID
        restEnd = Date().addingTimeInterval(Double(set.restSeconds))

        if set.weightKg > 0, set.reps > 0,
           let next = sets.first(where: { !$0.isDone && $0.setIndex > set.setIndex }), !next.edited {
            let isLast = !sets.contains { !$0.isDone && $0.setIndex > next.setIndex }
            let performed = Adaptation.Performed(weight: store.display(set.weightKg), reps: set.reps,
                                                 rir: set.rir, targetRIR: set.targetRIR)
            let w = Adaptation.nextSetLoad(after: performed, nextReps: next.targetReps, nextRIR: next.targetRIR,
                                           isLastSet: isLast, unit: store.unit)
            if w > 0 { next.weightKg = store.toKg(w) }
        }
        easeUpcomingExercises(after: set)
    }

    private func easeUpcomingExercises(after set: LoggedSet) {
        let all = session.sets
        guard all.filter({ $0.exerciseID == set.exerciseID }).allSatisfy(\.isDone) else { return }   // only once an exercise is finished
        let finishedIDs = Set(all.map(\.exerciseID).filter { id in all.filter { $0.exerciseID == id }.allSatisfy(\.isDone) })
        let hardness = all.filter { $0.isDone && finishedIDs.contains($0.exerciseID) }.map { $0.targetRIR - $0.rir }
        let factor = Adaptation.sessionFactor(hardness: hardness)
        for later in all where !later.isDone && !later.edited && later.exerciseOrder > set.exerciseOrder && later.targetWeightKg > 0 {
            later.weightKg = store.toKg(store.unit.round(store.display(later.targetWeightKg) * factor))
        }
        let pct = Int(abs((factor - 1) * 100).rounded())
        if factor < 0.995 { session.easeNote = "Tough start: upcoming loads eased \(pct)%" }
        else if factor > 1.005 { session.easeNote = "Moving well: upcoming loads nudged up \(pct)%" }
        else { session.easeNote = "" }
    }

    /// +/- on the rest timer; the change carries over to this exercise's remaining sets.
    private func adjustRest(_ delta: Int) {
        guard let end = restEnd else { return }
        let next = end.addingTimeInterval(Double(delta))
        if next <= Date() { restEnd = nil } else { restEnd = next }
        if let id = restExerciseID {
            for s in session.sets where s.exerciseID == id && !s.isDone { s.restSeconds = max(15, s.restSeconds + delta) }
        }
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
    let keypad: KeypadController
    let onToggle: (Bool) -> Void
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)").font(.headline).frame(width: 30, alignment: .leading).foregroundStyle(t.secondary)
            cell(.weight)
            cell(.reps)
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
        .id(set.persistentModelID)
    }

    /// Tappable value that opens the workout keypad on this field.
    private func cell(_ field: KeypadController.Field) -> some View {
        let active = keypad.isEditing(set, field)
        let value: String = keypad.liveText(set, field) ?? shown(field)
        return Button {
            keypad.activate(set, field: field, store: store)
        } label: {
            Text(value).font(.body.monospacedDigit())
                .foregroundStyle(value == "0" && !active ? t.secondary : t.text)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(active ? t.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(field == .weight ? "Weight" : "Reps")
    }

    private func shown(_ field: KeypadController.Field) -> String {
        switch field {
        case .weight:
            let v = store.display(set.weightKg)
            return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
        case .reps: return String(set.reps)
        }
    }

    private var rirColor: Color {
        switch set.rir { case ..<1.5: return t.bad; case ..<3.5: return t.good; default: return t.warn }
    }
}

/// ScrollView that brings the set being edited into view above the keypad.
struct KeypadScroll<Content: View>: View {
    let keypad: KeypadController
    @ViewBuilder var content: Content
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { content }
                .onChange(of: keypad.current?.persistentModelID) { _, id in
                    guard let id else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
        }
    }
}

struct RestBar: View {
    let end: Date
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void
    @Environment(\.theme) private var t
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let left = max(0, Int(end.timeIntervalSince(ctx.date).rounded(.up)))
            HStack(spacing: 10) {
                Image(systemName: "timer")
                Text(String(format: "%d:%02d", left / 60, left % 60)).font(.title2.monospacedDigit().bold())
                    .contentTransition(.numericText())
                Spacer(minLength: 4)
                stepper("minus", delta: -15)
                stepper("plus", delta: 15)
                Button("Skip", action: onSkip).font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(t.onAccent.opacity(0.18), in: Capsule())
            }
            .padding(.horizontal, 16).frame(height: 56)
            .foregroundStyle(t.onAccent).background(t.accent)
        }
    }

    private func stepper(_ icon: String, delta: Int) -> some View {
        Button { Haptics.light(); onAdjust(delta) } label: {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.caption.weight(.bold))
                Text("15s").font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(t.onAccent.opacity(0.18), in: Capsule())
        }
        .accessibilityLabel(delta < 0 ? "Shorten rest by 15 seconds" : "Extend rest by 15 seconds")
    }
}

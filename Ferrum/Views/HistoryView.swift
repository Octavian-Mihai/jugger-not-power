import SwiftUI
import SwiftData
import FerrumCore

/// Every finished workout, newest first.
struct HistoryView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished }, sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if sessions.isEmpty {
                    Text("Finished workouts show up here.").foregroundStyle(t.secondary).card()
                }
                ForEach(sessions) { s in
                    if s.isRest { SessionRow(session: s) }
                    else { NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }.buttonStyle(.plain) }
                }
            }.padding(16)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("History")
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    var body: some View {
        let done = session.sets.filter(\.isDone)
        let volume = done.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.dayName).font(.headline).foregroundStyle(t.text)
                Text(session.date.formatted(date: .abbreviated, time: .omitted)
                     + (session.blockName.isEmpty ? "" : " · \(session.blockName)"))
                    .font(.caption).foregroundStyle(t.secondary)
            }
            Spacer()
            if session.isRest {
                Label("Rest", systemImage: "bed.double.fill").font(.subheadline).foregroundStyle(t.secondary)
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(done.count) sets").font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                    Text(store.format(volume)).font(.caption).foregroundStyle(t.secondary)
                }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(t.secondary)
        }.card()
    }
}

/// Exercises, sets, reps and weights from one past workout.
struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(Store.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    @Query private var allSets: [LoggedSet]
    @State private var confirmDelete = false

    var body: some View {
        let done = session.sortedSets.filter(\.isDone)
        let records = allSets.filter { $0.isDone && $0.session?.isFinished == true && $0.weightKg > 0 }.map(\.record)
        let volume = done.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    stat("\(done.count)", "Sets")
                    stat(store.format(volume, withUnit: false), "Volume \(store.unit.label)")
                    stat(session.duration.map { "\(Int($0 / 60))m" } ?? "—", "Duration")
                }
                if session.readinessScore > 0 {
                    Label("Readiness \(session.readinessScore)", systemImage: "heart.text.square")
                        .font(.subheadline).foregroundStyle(t.secondary)
                }
                ForEach(session.exerciseIDsInOrder.filter { id in done.contains { $0.exerciseID == id } }, id: \.self) { id in
                    exerciseCard(id, sets: done.filter { $0.exerciseID == id }, history: records)
                }
                if done.isEmpty { Text("No sets were logged in this workout.").foregroundStyle(t.secondary).card() }
                Button("Delete workout", role: .destructive) { confirmDelete = true }.padding(.top, 8)
            }.padding(16)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle(session.dayName).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { WorkoutSummaryView(session: session) { dismiss() } } label: { Label("Summary", systemImage: "chart.bar.doc.horizontal") }
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { context.delete(session); dismiss() }
        } message: { Text("Its sets are removed from your progress charts too.") }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title3.bold()).foregroundStyle(t.accent).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(t.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func exerciseCard(_ id: String, sets: [LoggedSet], history: [SetRecord]) -> some View {
        let info = store.library.exercise(id)
        let best = sets.map(\.record.e1RM).max() ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ExerciseThumb(file: info?.image, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.library.name(for: id)).font(.headline).foregroundStyle(t.text)
                    if best > 0 { Text("Best e1RM \(store.format(best))").font(.caption).foregroundStyle(t.secondary) }
                }
            }
            ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { i, s in
                HStack {
                    Text("\(i + 1)").frame(width: 22, alignment: .leading).foregroundStyle(t.secondary)
                    Text(s.weightKg > 0 ? "\(store.format(s.weightKg)) × \(s.reps)" : "\(s.reps) reps")
                        .font(.body.monospacedDigit()).foregroundStyle(t.text)
                    if i == (sets.firstIndex { $0.record.e1RM == s.record.e1RM } ?? i), Analytics.isPR(s.record, history: history) {
                        Text("PR").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(t.accent, in: Capsule()).foregroundStyle(t.onAccent)
                    }
                    Spacer()
                    Text(s.rir >= 5 ? "RIR 5+" : "RIR \(Int(s.rir))").font(.caption).foregroundStyle(t.secondary)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
}

import SwiftUI
import SwiftData
import Charts
import FerrumCore

struct ProgressTab: View {
    let profile: Profile
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query private var allSets: [LoggedSet]
    @Query private var sessions: [WorkoutSession]
    @State private var exerciseID = MainLift.squat.exerciseID
    @State private var windowDays = 7

    private var records: [SetRecord] { allSets.filter { $0.isDone && $0.session?.isFinished == true && $0.weightKg > 0 }.map(\.record) }

    var body: some View {
        Screen(title: "Progress") {
            summary
            e1rmChart
            volumeChart
            prs
        }
    }

    private var summary: some View {
        let finished = sessions.filter(\.isFinished)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return HStack(spacing: 12) {
            stat("\(finished.count)", "Sessions")
            stat("\(finished.filter { $0.date > weekAgo }.count)", "This week")
            stat(store.format(Analytics.totalVolume(records.filter { $0.date > weekAgo }), withUnit: false), "Vol/wk (\(store.unit.label))")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(t.accent).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(t.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private var trackedExercises: [String] {
        var ids = MainLift.allCases.map(\.exerciseID)
        for id in Set(records.map(\.exerciseID)).sorted() where !ids.contains(id) { ids.append(id) }
        return ids
    }

    private var e1rmChart: some View {
        let points = Analytics.e1RMHistory(records, exerciseID: exerciseID)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(text: "Estimated 1RM")
                Spacer()
                Picker("Exercise", selection: $exerciseID) {
                    ForEach(trackedExercises, id: \.self) { Text(store.library.name(for: $0)).tag($0) }
                }.labelsHidden()
            }
            if points.count < 2 {
                Text(points.isEmpty ? "Log sets for this lift to see your trend." : "Log one more session to draw the trend.")
                    .foregroundStyle(t.secondary).frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("e1RM", store.display(p.value))).foregroundStyle(t.accent)
                    PointMark(x: .value("Date", p.date), y: .value("e1RM", store.display(p.value))).foregroundStyle(t.accent)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
            }
        }.card()
    }

    private var volumeChart: some View {
        let since = Calendar.current.date(byAdding: .day, value: -windowDays, to: .now) ?? .now
        let sets = Analytics.muscleSets(records.filter { $0.date > since }, library: store.library)
        let rows = sets.compactMap { id, n in store.library.muscle(id).map { (name: $0.name, sets: n) } }.sorted { $0.sets > $1.sets }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(text: "Hard sets per muscle")
                Spacer()
                Picker("Window", selection: $windowDays) { Text("7d").tag(7); Text("14d").tag(14); Text("30d").tag(30) }
                    .pickerStyle(.segmented).frame(width: 150)
            }
            if rows.isEmpty {
                Text("Complete workouts to see weekly volume.").foregroundStyle(t.secondary).frame(maxWidth: .infinity, minHeight: 60)
            } else {
                Chart(rows, id: \.name) { r in
                    BarMark(x: .value("Sets", r.sets), y: .value("Muscle", r.name)).foregroundStyle(t.accent)
                        .annotation(position: .trailing) { Text(r.sets.formatted(.number.precision(.fractionLength(0...1)))).font(.caption2).foregroundStyle(t.secondary) }
                }
                .frame(height: CGFloat(rows.count) * 28 + 20)
            }
            Text("Primary muscle = 1 set, secondary = 0.5. Sets with 5+ RIR don't count.").font(.caption2).foregroundStyle(t.secondary)
        }.card()
    }

    private var prs: some View {
        let bests = Dictionary(grouping: records, by: \.exerciseID).compactMap { id, rs in
            rs.max(by: { $0.e1RM < $1.e1RM }).map { (id: id, set: $0) }
        }.sorted { $0.set.e1RM > $1.set.e1RM }.prefix(8)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "Personal records")
            if bests.isEmpty { Text("Your best sets show up here.").foregroundStyle(t.secondary) }
            ForEach(Array(bests), id: \.id) { b in
                HStack {
                    VStack(alignment: .leading) {
                        Text(store.library.name(for: b.id)).foregroundStyle(t.text)
                        Text("\(store.format(b.set.weight)) × \(b.set.reps) @ RIR \(Int(b.set.rir))").font(.caption).foregroundStyle(t.secondary)
                    }
                    Spacer()
                    Text("e1RM \(store.format(b.set.e1RM))").font(.subheadline.bold()).foregroundStyle(t.accent)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
}

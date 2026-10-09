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
    @State private var volumeMetric = 0   // 0 = tonnage, 1 = sets

    private var records: [SetRecord] { allSets.filter { $0.isDone && $0.session?.isFinished == true && $0.weightKg > 0 }.map(\.record) }

    var body: some View {
        Screen(title: "Progress") {
            summary
            NavigationLink { HistoryView() } label: {
                HStack { Label("Workout history", systemImage: "clock.arrow.circlepath").foregroundStyle(t.text); Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(t.secondary) }.card()
            }.buttonStyle(.plain)
            BodyWeightCard()
            improvementCard
            e1rmChart
            weeklyVolumeCard
            volumeChart
            prs
        }
    }

    private var summary: some View {
        let finished = sessions.filter { $0.isFinished && !$0.isRest }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return HStack(spacing: 12) {
            stat("\(finished.count)", "Sessions")
            stat("\(finished.filter { $0.date > weekAgo }.count)", "This week")
            stat(compact(store.display(Analytics.totalVolume(records.filter { $0.date > weekAgo }))), "Vol/wk (\(store.unit.label))")
        }
    }

    private func compact(_ v: Double) -> String {
        v >= 10_000 ? String(format: "%.1fk", v / 1000) : String(Int(v.rounded()))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(t.accent).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(t.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    // MARK: improvement
    private var improvementCard: some View {
        let lifts = MainLift.allCases.map(\.exerciseID)
        let extra = Set(records.map(\.exerciseID)).subtracting(lifts)
        let all = (lifts + extra.sorted()).compactMap { Analytics.improvement(records, exerciseID: $0) }
            .sorted { $0.percent > $1.percent }
        let series: [(name: String, point: E1RMPoint)] = lifts.flatMap { id in
            Analytics.percentChangeHistory(records, exerciseID: id).map { (store.library.name(for: id), $0) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(text: "Improvement")
            if all.isEmpty {
                EmptyState(icon: "chart.line.uptrend.xyaxis", title: "Nothing to compare yet", message: "Train the same lift on two different days to see how much you've improved.", compact: true)
            } else {
                if !series.isEmpty {
                    Chart {
                        ForEach(Array(series.enumerated()), id: \.offset) { _, row in
                            LineMark(x: .value("Date", row.point.date), y: .value("Change", row.point.value))
                                .foregroundStyle(by: .value("Lift", row.name))
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Date", row.point.date), y: .value("Change", row.point.value))
                                .foregroundStyle(by: .value("Lift", row.name))
                        }
                        RuleMark(y: .value("Start", 0)).foregroundStyle(t.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4]))
                    }
                    .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))%") } } } }
                    .chartLegend(position: .bottom)
                    .frame(height: 190)
                }
                ForEach(all.prefix(6), id: \.exerciseID) { imp in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(store.library.name(for: imp.exerciseID)).foregroundStyle(t.text)
                            Text("\(store.format(imp.first)) → \(store.format(imp.latest)) e1RM").font(.caption).foregroundStyle(t.secondary)
                        }
                        Spacer()
                        Label(String(format: "%+.1f%%", imp.percent), systemImage: imp.percent >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.subheadline.bold()).foregroundStyle(imp.percent >= 0 ? t.good : t.bad)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    // MARK: weekly volume
    private var weeklyVolumeCard: some View {
        let weeks = Analytics.weeklyTotals(records, weeks: 10)
        let useSets = volumeMetric == 1
        let total = weeks.reduce(0) { $0 + (useSets ? Double($1.sets) : $1.volume) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(text: "Weekly volume")
                Spacer()
                Picker("Metric", selection: $volumeMetric) { Text(store.unit.label).tag(0); Text("Sets").tag(1) }
                    .pickerStyle(.segmented).frame(width: 130)
            }
            if total == 0 {
                EmptyState(icon: "chart.bar", title: "No volume yet", message: "Finish a workout to see your weekly training volume.", compact: true)
            } else {
                Chart(weeks) { w in
                    BarMark(x: .value("Week", w.weekStart, unit: .weekOfYear),
                            y: .value("Volume", useSets ? Double(w.sets) : store.display(w.volume)))
                        .foregroundStyle(w.id == weeks.last?.id ? t.accent : t.accent.opacity(0.55))
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .frame(height: 170)
                Text(useSets ? "Completed sets per week." : "Tonnage (weight × reps) per week in \(store.unit.label).")
                    .font(.caption2).foregroundStyle(t.secondary)
            }
        }.card()
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
                EmptyState(icon: "chart.xyaxis.line", title: points.isEmpty ? "No data for this lift" : "One more session",
                           message: points.isEmpty ? "Log sets for this lift to see your trend." : "Log this lift again to draw the trend.", compact: true)
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
                EmptyState(icon: "figure.strengthtraining.traditional", title: "No hard sets yet", message: "Complete workouts to see which muscles you train.", compact: true)
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
            if bests.isEmpty { EmptyState(icon: "trophy", title: "No records yet", message: "Your best sets show up here.", compact: true) }
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

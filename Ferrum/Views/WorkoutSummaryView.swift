import SwiftUI
import SwiftData
import FerrumCore

/// Shown right after a workout is finished: what you did, what improved, and how it compares to last time.
struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query private var allSets: [LoggedSet]
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished && !$0.isRest }, sort: \WorkoutSession.date, order: .reverse)
    private var finishedSessions: [WorkoutSession]

    private var done: [LoggedSet] { session.sortedSets.filter(\.isDone) }
    private var volume: Double { done.reduce(0) { $0 + $1.weightKg * Double($1.reps) } }

    /// Most recent earlier session of the same day, for comparison.
    private var previous: WorkoutSession? {
        finishedSessions.first { $0 !== session && $0.dayName == session.dayName && $0.programID == session.programID && $0.date < session.date }
    }
    private var history: [SetRecord] {
        allSets.filter { $0.isDone && $0.session !== session && $0.session?.isFinished == true && $0.weightKg > 0 }.map(\.record)
    }

    private struct PR: Identifiable { let id: String; let weight: Double; let reps: Int; let e1RM: Double; let previous: Double }
    private var prs: [PR] {
        session.exerciseIDsInOrder.compactMap { id in
            let sets = done.filter { $0.exerciseID == id && $0.weightKg > 0 }
            guard let best = sets.max(by: { $0.record.e1RM < $1.record.e1RM }) else { return nil }
            let prior = Analytics.bestE1RM(history, exerciseID: id)
            guard prior > 0, best.record.e1RM > prior * 1.001 else { return nil }
            return PR(id: id, weight: best.weightKg, reps: best.reps, e1RM: best.record.e1RM, previous: prior)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statGrid
                comparison
                if !prs.isEmpty { prSection }
                muscleSection
                exerciseSection
                shareButton
                Button("Done", action: onDone).buttonStyle(PrimaryButton()).padding(.top, 8)
            }
            .padding(16)
        }
        .background(t.bg.ignoresSafeArea())
    }

    // MARK: share

    @State private var shareImage: UIImage?

    /// Sends the summary as a picture, so it lands in Messages (or anywhere else) looking the same as it does here.
    @ViewBuilder private var shareButton: some View {
        Group {
            if let shareImage {
                ShareLink(item: Image(uiImage: shareImage),
                          subject: Text("\(session.dayName) workout"),
                          message: Text(shareText),
                          preview: SharePreview("\(session.dayName) · \(done.count) sets", image: Image(uiImage: shareImage))) {
                    Label("Share as image", systemImage: "square.and.arrow.up")
                }
            } else {
                Label("Preparing image…", systemImage: "square.and.arrow.up").foregroundStyle(t.secondary)
            }
        }
        .font(.subheadline.weight(.semibold)).padding(.top, 4)
        .task(id: session.persistentModelID) { renderShareImage() }
    }

    private func renderShareImage() {
        let card = ShareCard(session: session, sets: done, volumeText: volumeText(volume),
                             prs: prs.map { ($0.id, $0.e1RM) }, setLine: setLine)
            .environment(store)
            .environment(\.theme, t)
            .environment(\.colorScheme, t.dark ? .dark : .light)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = .init(width: 390, height: nil)
        shareImage = renderer.uiImage
    }

    // MARK: sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(t.good)
            Text("Workout complete").font(.largeTitle.bold()).foregroundStyle(t.text)
            Text("\(session.dayName) · \(session.date.formatted(date: .complete, time: .omitted))")
                .font(.subheadline).foregroundStyle(t.secondary)
        }
    }

    private var statGrid: some View {
        let minutes = session.duration.map { max(1, Int($0 / 60)) }
        let hardSets = done.filter { $0.rir <= 1 }.count
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            stat("\(done.count)", "Sets completed")
            stat(minutes.map { "\($0) min" } ?? "—", "Duration")
            stat(volumeText(volume), "Volume (\(store.unit.label))")
            stat("\(session.exerciseIDsInOrder.filter { id in done.contains { $0.exerciseID == id } }.count)", "Exercises")
            if hardSets > 0 { stat("\(hardSets)", "Sets at RIR 0–1") }
            if prs.count > 0 { stat("\(prs.count)", prs.count == 1 ? "Personal record" : "Personal records", highlight: true) }
        }
    }

    private func volumeText(_ kg: Double) -> String {
        Int(store.display(kg).rounded()).formatted(.number.grouping(.automatic))
    }

    private func stat(_ value: String, _ label: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title.bold()).foregroundStyle(highlight ? t.good : t.accent).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(t.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    @ViewBuilder private var comparison: some View {
        if let previous {
            let prevDone = previous.sets.filter(\.isDone)
            let prevVolume = prevDone.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
            if prevVolume > 0 {
                let change = (volume - prevVolume) / prevVolume * 100
                HStack(spacing: 12) {
                    Image(systemName: change >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.title2).foregroundStyle(change >= 0 ? t.good : t.warn)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%+.0f%% volume vs last %@", change, session.dayName))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                        Text("\(volumeText(prevVolume)) \(store.unit.label) on \(previous.date.formatted(date: .abbreviated, time: .omitted)) · \(prevDone.count) sets")
                            .font(.caption).foregroundStyle(t.secondary)
                    }
                    Spacer()
                }.card()
            }
        }
        if !session.easeNote.isEmpty {
            Label(session.easeNote, systemImage: "gauge.with.needle").font(.footnote).foregroundStyle(t.warn)
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "New personal records")
            ForEach(prs) { pr in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.library.name(for: pr.id)).font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                        Text("\(store.format(pr.weight)) × \(pr.reps)").font(.caption).foregroundStyle(t.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("e1RM \(store.format(pr.e1RM))").font(.subheadline.bold()).foregroundStyle(t.good)
                        Text(String(format: "+%@ from %@", store.format(pr.e1RM - pr.previous, withUnit: false), store.format(pr.previous)))
                            .font(.caption).foregroundStyle(t.secondary)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private var muscleSection: some View {
        let records = done.map(\.record)
        let sets = Analytics.muscleSets(records, library: store.library)
        let rows = sets.compactMap { id, n in store.library.muscle(id).map { (name: $0.name, n: n) } }.sorted { $0.n > $1.n }.prefix(6)
        let maxN = rows.map(\.n).max() ?? 1
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(text: "Muscles worked (hard sets)")
                    ForEach(Array(rows), id: \.name) { r in
                        HStack(spacing: 10) {
                            Text(r.name).font(.subheadline).foregroundStyle(t.text).frame(width: 110, alignment: .leading)
                            GeometryReader { g in
                                Capsule().fill(t.accent).frame(width: max(8, g.size.width * r.n / maxN))
                            }.frame(height: 8)
                            Text(r.n.formatted(.number.precision(.fractionLength(0...1)))).font(.caption.monospacedDigit()).foregroundStyle(t.secondary)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).card()
            }
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "What you did")
            ForEach(session.exerciseIDsInOrder.filter { id in done.contains { $0.exerciseID == id } }, id: \.self) { id in
                let sets = done.filter { $0.exerciseID == id }
                HStack(alignment: .top, spacing: 12) {
                    ExerciseThumb(file: store.library.exercise(id)?.image, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.library.name(for: id)).font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                        Text(setLine(sets)).font(.caption).foregroundStyle(t.secondary)
                    }
                    Spacer()
                    if prs.contains(where: { $0.id == id }) {
                        Text("PR").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(t.good, in: Capsule()).foregroundStyle(.black)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }

    /// "3 × 100 kg × 5" when every set matched, otherwise each set in turn.
    private func setLine(_ sets: [LoggedSet]) -> String {
        let same = Set(sets.map { "\($0.weightKg)|\($0.reps)" }).count == 1
        func one(_ s: LoggedSet) -> String { s.weightKg > 0 ? "\(store.format(s.weightKg)) × \(s.reps)" : "\(s.reps) reps" }
        if same, let f = sets.first { return "\(sets.count) × \(one(f))" }
        return sets.map(one).joined(separator: " · ")
    }

    private var shareText: String {
        var lines = ["\(session.dayName) · \(session.date.formatted(date: .abbreviated, time: .omitted))",
                     "\(done.count) sets · \(store.format(volume)) volume"]
        for id in session.exerciseIDsInOrder {
            let sets = done.filter { $0.exerciseID == id }
            if !sets.isEmpty { lines.append("• \(store.library.name(for: id)): \(setLine(sets))") }
        }
        if !prs.isEmpty { lines.append("PRs: " + prs.map { store.library.name(for: $0.id) }.joined(separator: ", ")) }
        return lines.joined(separator: "\n")
    }
}

/// The picture that gets shared: compact, self-contained, always the same width.
private struct ShareCard: View {
    let session: WorkoutSession
    let sets: [LoggedSet]
    let volumeText: String
    let prs: [(id: String, e1RM: Double)]
    let setLine: ([LoggedSet]) -> String
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    private var exerciseIDs: [String] { session.exerciseIDsInOrder.filter { id in sets.contains { $0.exerciseID == id } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("FERRUM").font(.caption.weight(.black)).tracking(3).foregroundStyle(t.accent)
                Spacer()
                Text(session.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(t.secondary)
            }
            Text(session.dayName).font(.system(size: 34, weight: .black)).foregroundStyle(t.text)

            HStack(spacing: 10) {
                tile("\(sets.count)", "sets")
                tile(session.duration.map { "\(max(1, Int($0 / 60)))m" } ?? "—", "time")
                tile(volumeText, store.unit.label)
                if !prs.isEmpty { tile("\(prs.count)", prs.count == 1 ? "PR" : "PRs", highlight: true) }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(exerciseIDs.prefix(8), id: \.self) { id in
                    HStack(alignment: .top, spacing: 10) {
                        ExerciseThumb(file: store.library.exercise(id)?.image, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(store.library.name(for: id)).font(.subheadline.weight(.semibold)).foregroundStyle(t.text)
                                if prs.contains(where: { $0.id == id }) {
                                    Text("PR").font(.system(size: 9, weight: .heavy)).padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(t.good, in: Capsule()).foregroundStyle(.black)
                                }
                            }
                            Text(setLine(sets.filter { $0.exerciseID == id })).font(.caption).foregroundStyle(t.secondary)
                        }
                    }
                }
                if exerciseIDs.count > 8 {
                    Text("+ \(exerciseIDs.count - 8) more exercises").font(.caption).foregroundStyle(t.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 390, alignment: .leading)
        .background(t.bg)
    }

    private func tile(_ value: String, _ label: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.title3.bold()).foregroundStyle(highlight ? t.good : t.accent).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(t.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(t.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

import SwiftUI
import SwiftData
import FerrumCore

private func csv(_ s: String) -> Set<String> { Set(s.split(separator: ",").map(String.init)) }
private func join(_ s: Set<String>) -> String { s.sorted().joined(separator: ",") }

/// Step-by-step questionnaire that builds a program around the lifter's answers.
struct GeneratorView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query private var programs: [Program]

    @State private var step = 0
    @State private var goal: GoalKind = .powerbuilding
    @State private var days = 4
    @State private var minutes = 60            // 0 = no limit
    @State private var experience: Experience = .intermediate
    @State private var emphasis: Set<String> = []
    @State private var equipment: Set<String> = []
    @State private var equipmentPreset = "full"
    @State private var likes: Set<String> = []
    @State private var dislikes: Set<String> = []
    @State private var avoid: Set<String> = []
    @State private var name = ""
    @State private var picker: PickerKind?

    private enum PickerKind: Identifiable { case likes, dislikes; var id: Int { hashValue } }
    private let titles = ["Goal", "Schedule", "Experience", "Equipment", "Likes", "Dislikes", "Review"]
    private let emphasisChoices = ["chest-pectorals", "lats", "lateral-delts", "biceps", "triceps", "quadriceps", "hamstrings", "glutes", "calves", "core-and-abs"]
    private let avoidChoices = ["Vertical Push", "Horizontal Push", "Lunge / Split", "Hinge", "Squat", "Vertical Pull", "Horizontal Pull", "Plyometric", "Carry"]
    private let presets: [(id: String, title: String, set: Set<String>)] = [
        ("full", "Full gym", []),
        ("home", "Home gym", ["barbell", "dumbbell", "kettlebell", "band"]),
        ("db", "Dumbbells only", ["dumbbell"]),
        ("machines", "Machines & cables", ["machine", "cable", "smith machine"]),
        ("body", "Bodyweight only", ["bodyweight"]),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(titles.count)).tint(t.accent).padding(.horizontal, 16).padding(.top, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(titles[step].uppercased()).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(t.secondary)
                        content
                    }.padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                HStack(spacing: 12) {
                    if step > 0 { Button("Back") { step -= 1 }.buttonStyle(PrimaryButton(prominent: false)) }
                    if step < titles.count - 1 { Button("Next") { step += 1 }.buttonStyle(PrimaryButton()) }
                    else { Button("Create program") { create() }.buttonStyle(PrimaryButton()) }
                }.padding(16)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Build my program").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .keyboardDoneBar()
            .sheet(item: $picker) { kind in
                ExerciseMultiPicker(title: kind == .likes ? "Exercises you like" : "Exercises to avoid",
                                    selected: kind == .likes ? $likes : $dislikes)
            }
            .onAppear(perform: loadAnswers)
        }
    }

    // MARK: steps
    @ViewBuilder private var content: some View {
        switch step {
        case 0: goalStep
        case 1: scheduleStep
        case 2: experienceStep
        case 3: equipmentStep
        case 4: likesStep
        case 5: dislikesStep
        default: reviewStep
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            question("What are you training for?")
            ForEach(GoalKind.allCases) { g in
                Button { goal = g } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(g.title).font(.headline)
                            Text(g.blurb).font(.caption).foregroundStyle(t.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: goal == g ? "checkmark.circle.fill" : "circle").foregroundStyle(goal == g ? t.accent : t.secondary)
                    }.foregroundStyle(t.text).card()
                }
            }
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            question("How many days a week can you train?")
            Stepper("\(days) days", value: $days, in: 2...6).foregroundStyle(t.text).card()
            question("How long should each workout be?")
            FlowLayout(spacing: 8) {
                ForEach([30, 45, 60, 75, 90, 0], id: \.self) { m in
                    Button { minutes = m } label: { Chip(text: m == 0 ? "No limit" : "\(m) min", selected: minutes == m) }
                }
            }
            Text("Ferrum trims accessories and sets to fit. Main lifts always stay.").font(.caption).foregroundStyle(t.secondary)
        }
    }

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            question("How long have you been lifting seriously?")
            Picker("Experience", selection: $experience) { ForEach(Experience.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            Text(experience == .beginner ? "Under a year. Lighter starting loads, fewer sets."
                 : experience == .intermediate ? "1–3 years. Standard volume."
                 : "3+ years. Extra accessory volume.").font(.caption).foregroundStyle(t.secondary)
            question("Any muscles you want to bring up?")
            FlowChips(items: emphasisChoices, selected: emphasis, title: { store.library.muscle($0)?.name ?? $0 }) {
                if !emphasis.insert($0).inserted { emphasis.remove($0) }
            }
        }
    }

    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            question("What equipment do you have access to?")
            FlowLayout(spacing: 8) {
                ForEach(presets, id: \.id) { p in
                    Button { equipmentPreset = p.id; equipment = p.set } label: { Chip(text: p.title, selected: equipmentPreset == p.id) }
                }
            }
            Text("Or pick exactly what you have").font(.caption.weight(.bold)).foregroundStyle(t.secondary)
            FlowChips(items: ProgramGenerator.equipmentOptions.map(\.id), selected: equipment.isEmpty ? Set(ProgramGenerator.equipmentOptions.map(\.id)) : equipment,
                      title: { id in ProgramGenerator.equipmentOptions.first { $0.id == id }?.title ?? id }) { id in
                var current = equipment.isEmpty ? Set(ProgramGenerator.equipmentOptions.map(\.id)) : equipment
                current.remove("bodyweight")
                if !current.insert(id).inserted { current.remove(id) }
                equipment = current.isEmpty ? ["bodyweight"] : current
                equipmentPreset = "custom"
            }
            Text("Bodyweight exercises are always allowed. Missing gear is swapped for the closest alternative.")
                .font(.caption).foregroundStyle(t.secondary)
        }
    }

    private var likesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            question("Which exercises do you enjoy?")
            Text("Ferrum works these into your week and prefers them over similar options.").font(.callout).foregroundStyle(t.secondary)
            selectedList(likes) { likes.remove($0) }
            Button { picker = .likes } label: { Label(likes.isEmpty ? "Choose favourites" : "Edit favourites", systemImage: "heart") }
                .buttonStyle(PrimaryButton(prominent: false))
        }
    }

    private var dislikesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            question("Anything you hate or can't do?")
            Text("Excluded exercises never appear. Pick movements to skip entirely if something bothers a joint.").font(.callout).foregroundStyle(t.secondary)
            selectedList(dislikes) { dislikes.remove($0) }
            Button { picker = .dislikes } label: { Label(dislikes.isEmpty ? "Choose exercises to avoid" : "Edit avoided exercises", systemImage: "nosign") }
                .buttonStyle(PrimaryButton(prominent: false))
            Text("Skip whole movement types").font(.caption.weight(.bold)).foregroundStyle(t.secondary).padding(.top, 6)
            FlowChips(items: avoidChoices, selected: avoid, title: { $0 }) { if !avoid.insert($0).inserted { avoid.remove($0) } }
        }
    }

    private var reviewStep: some View {
        let result = generate()
        let plan = result.plan
        let first = plan.blocks.first
        let avg = first.map { b in b.days.isEmpty ? 0 : b.days.map(\.estimatedMinutes).reduce(0, +) / b.days.count } ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            question("Here's your plan")
            VStack(alignment: .leading, spacing: 6) {
                summaryRow("Goal", goal.title)
                summaryRow("Schedule", "\(days) days · \(minutes == 0 ? "no time limit" : "≤ \(minutes) min")")
                summaryRow("Length", "\(plan.totalWeeks) weeks · \(plan.totalSessions) sessions")
                summaryRow("Average session", "~\(avg) min")
                summaryRow("Equipment", equipmentPreset == "custom" ? "Custom" : (presets.first { $0.id == equipmentPreset }?.title ?? "Full gym"))
                if !likes.isEmpty { summaryRow("Favourites", "\(likes.count) exercises") }
                if !dislikes.isEmpty || !avoid.isEmpty { summaryRow("Avoiding", "\(dislikes.count) exercises, \(avoid.count) movement types") }
            }.card()
            if !result.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(text: "Adjusted for you")
                    ForEach(result.notes, id: \.self) { Text("• " + $0).font(.footnote).foregroundStyle(t.text) }
                }.frame(maxWidth: .infinity, alignment: .leading).card()
            }
            if let first {
                SectionHeader(text: "\(first.name) · week 1")
                ForEach(first.days) { d in
                    DisclosureGroup {
                        ForEach(d.exercises) { ex in
                            Text(store.library.name(for: ex.exerciseID)).font(.subheadline).foregroundStyle(t.text).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } label: {
                        HStack { Text(d.name).font(.headline).foregroundStyle(t.text); Spacer()
                            Text("~\(d.estimatedMinutes) min").font(.caption).foregroundStyle(t.secondary) }
                    }.card()
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundStyle(t.secondary)
                TextField(plan.name, text: $name).textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: helpers
    private func question(_ text: String) -> some View { Text(text).font(.title2.bold()).foregroundStyle(t.text) }

    private func summaryRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) { Text(k).foregroundStyle(t.secondary); Spacer(); Text(v).foregroundStyle(t.text).multilineTextAlignment(.trailing) }
            .font(.subheadline)
    }

    private func selectedList(_ ids: Set<String>, remove: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(ids.sorted(), id: \.self) { id in
                Button { remove(id) } label: {
                    HStack(spacing: 4) { Text(store.library.name(for: id)); Image(systemName: "xmark.circle.fill") }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(t.onAccent).background(t.accent, in: Capsule())
                }
            }
        }
    }

    private func input() -> GeneratorInput {
        GeneratorInput(goal: goal, daysPerWeek: days, experience: experience, emphasis: Array(emphasis),
                       name: name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name,
                       sessionMinutes: minutes == 0 ? nil : minutes, equipment: equipment,
                       favorites: likes, dislikes: dislikes, avoidPatterns: avoid)
    }

    private func generate() -> (plan: ProgramPlan, notes: [String]) {
        ProgramGenerator(library: store.library).generateWithNotes(input())
    }

    private func loadAnswers() {
        days = profile.daysPerWeek; experience = profile.experience
        minutes = profile.prefMinutes
        equipment = csv(profile.prefEquipment)
        equipmentPreset = equipment.isEmpty ? "full" : (presets.first { $0.set == equipment }?.id ?? "custom")
        likes = csv(profile.prefLikes); dislikes = csv(profile.prefDislikes); avoid = csv(profile.prefAvoid)
    }

    private func create() {
        profile.daysPerWeek = days; profile.experience = experience; profile.prefMinutes = minutes
        profile.prefEquipment = join(equipment); profile.prefLikes = join(likes)
        profile.prefDislikes = join(dislikes); profile.prefAvoid = join(avoid)
        let p = Program(plan: generate().plan)
        for other in programs { other.isActive = false }
        p.isActive = true
        context.insert(p)
        dismiss()
    }
}

/// Searchable multi-select over the whole exercise library.
struct ExerciseMultiPicker: View {
    let title: String
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var query = ""
    @State private var pattern: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button { pattern = nil } label: { Chip(text: "All", selected: pattern == nil) }
                            ForEach(store.library.patterns, id: \.self) { p in
                                Button { pattern = (pattern == p) ? nil : p } label: { Chip(text: p, selected: pattern == p) }
                            }
                        }
                    }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                ForEach(store.library.search(query, pattern: pattern)) { e in
                    Button {
                        if !selected.insert(e.id).inserted { selected.remove(e.id) }
                    } label: {
                        HStack(spacing: 12) {
                            ExerciseThumb(file: e.image, size: 44)
                            VStack(alignment: .leading) {
                                Text(e.name).foregroundStyle(t.text)
                                Text(e.equipment.capitalized).font(.caption).foregroundStyle(t.secondary)
                            }
                            Spacer()
                            Image(systemName: selected.contains(e.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(e.id) ? t.accent : t.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .searchable(text: $query)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done (\(selected.count))") { dismiss() } } }
        }
    }
}

struct FlowChips: View {
    let items: [String]
    let selected: Set<String>
    let title: (String) -> String
    let toggle: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { id in
                Button { toggle(id) } label: { Chip(text: title(id), selected: selected.contains(id)) }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 320, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(width: bounds.width, subviews: subviews)
        for (i, p) in r.points.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified) }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0
        var pts: [CGPoint] = []
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxW = max(maxW, x)
        }
        return (CGSize(width: maxW, height: y + rowH), pts)
    }
}

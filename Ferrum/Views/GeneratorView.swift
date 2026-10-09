import SwiftUI
import SwiftData
import FerrumCore

struct GeneratorView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query private var programs: [Program]
    @State private var goal: GoalKind = .powerbuilding
    @State private var days = 4
    @State private var experience: Experience = .intermediate
    @State private var emphasis: Set<String> = []

    private let emphasisChoices = ["chest-pectorals", "lats", "lateral-delts", "biceps", "triceps", "quadriceps", "hamstrings", "glutes", "calves"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(text: "Goal")
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
                    SectionHeader(text: "Training days per week")
                    Stepper("\(days) days", value: $days, in: 2...6).foregroundStyle(t.text).card()
                    SectionHeader(text: "Experience")
                    Picker("Experience", selection: $experience) {
                        ForEach(Experience.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    SectionHeader(text: "Emphasize (optional)")
                    FlowChips(items: emphasisChoices, selected: emphasis, title: { store.library.muscle($0)?.name ?? $0 }) {
                        if !emphasis.insert($0).inserted { emphasis.remove($0) }
                    }
                    let plan = generate()
                    Text("\(plan.totalWeeks) weeks · \(plan.totalSessions) sessions · \(plan.blocks.map(\.name).joined(separator: " → "))")
                        .font(.footnote).foregroundStyle(t.secondary)
                    Button("Create program") { create(plan) }.buttonStyle(PrimaryButton())
                }.padding(16)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Generate program")
            .keyboardDoneBar()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { days = profile.daysPerWeek; experience = profile.experience }
        }
    }

    private func generate() -> ProgramPlan {
        ProgramGenerator(library: store.library)
            .generate(GeneratorInput(goal: goal, daysPerWeek: days, experience: experience, emphasis: Array(emphasis)))
    }

    private func create(_ plan: ProgramPlan) {
        let p = Program(plan: plan)
        for other in programs { other.isActive = false }
        p.isActive = true
        context.insert(p)
        dismiss()
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

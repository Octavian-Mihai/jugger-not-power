import SwiftUI
import SwiftData
import FerrumCore

struct ProgramsView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var t
    @Query(sort: \Program.createdAt, order: .reverse) private var programs: [Program]
    @State private var showGenerator = false
    @State private var editing: Program?

    var body: some View {
        Screen(title: "Programs") {
            HStack(spacing: 12) {
                Button { showGenerator = true } label: { Label("Generate", systemImage: "wand.and.stars") }
                    .buttonStyle(PrimaryButton())
                Button { createCustom() } label: { Label("Build own", systemImage: "pencil.and.ruler") }
                    .buttonStyle(PrimaryButton(prominent: false))
            }
            if programs.isEmpty {
                Text("No programs yet. Generate one from your goals, or build one from scratch.")
                    .foregroundStyle(t.secondary).card()
            }
            ForEach(programs) { program in
                NavigationLink { ProgramDetailView(program: program, profile: profile) } label: { row(program) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Make active") { activate(program) }
                        Button("Duplicate as custom") { duplicate(program) }
                        Button("Delete", role: .destructive) { context.delete(program) }
                    }
            }
        }
        .sheet(isPresented: $showGenerator) { GeneratorView(profile: profile) }
        .sheet(item: $editing) { p in ProgramBuilderView(program: p) }
    }

    private func row(_ p: Program) -> some View {
        let plan = p.plan
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(p.name).font(.headline).foregroundStyle(t.text)
                    if p.isActive { Text("ACTIVE").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(t.accent, in: Capsule()).foregroundStyle(t.onAccent) }
                }
                Text("\(plan.isCustom ? "Custom" : plan.goal?.title ?? "") · \(plan.totalWeeks) weeks · \(p.completedSessions)/\(plan.totalSessions) sessions")
                    .font(.caption).foregroundStyle(t.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(t.secondary)
        }.card()
    }

    private func activate(_ p: Program) {
        for other in programs { other.isActive = (other === p) }
    }

    private func createCustom() {
        let plan = ProgramPlan(name: "My Program", blocks: [
            Block(name: "Block 1", phase: .general, weeks: 4, days: [PlannedDay(name: "Day 1")])
        ])
        let p = Program(plan: plan)
        context.insert(p)
        if programs.isEmpty { p.isActive = true }
        editing = p
    }

    private func duplicate(_ p: Program) {
        let copy = Program(plan: p.plan.forkedAsCustom(named: p.name + " (custom)"))
        context.insert(copy)
    }
}

struct ProgramDetailView: View {
    @Bindable var program: Program
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Query private var programs: [Program]
    @State private var editing = false

    var body: some View {
        let plan = program.plan
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(plan.isCustom ? "Custom program" : (plan.goal?.blurb ?? "")).foregroundStyle(t.secondary)
                HStack(spacing: 12) {
                    Button(program.isActive ? "Active" : "Make active") {
                        for other in programs { other.isActive = (other === program) }
                    }.buttonStyle(PrimaryButton(prominent: !program.isActive)).disabled(program.isActive)
                    if plan.isCustom {
                        Button("Edit") { editing = true }.buttonStyle(PrimaryButton(prominent: false))
                    } else {
                        Button("Fork & edit") {
                            let copy = Program(plan: plan.forkedAsCustom(named: plan.name + " (custom)"))
                            context.insert(copy); dismiss()
                        }.buttonStyle(PrimaryButton(prominent: false))
                    }
                }
                ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { bi, block in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(block.name).font(.title3.bold()).foregroundStyle(t.text)
                            Spacer()
                            Text("\(block.weeks) wks · \(block.phase.title)").font(.caption).foregroundStyle(t.secondary)
                        }
                        ForEach(block.days) { day in
                            DisclosureGroup {
                                ForEach(day.exercises) { ex in
                                    HStack {
                                        Text(store.library.name(for: ex.exerciseID)).foregroundStyle(t.text)
                                        Spacer()
                                        Text(describe(ex)).font(.caption).foregroundStyle(t.secondary)
                                    }.padding(.vertical, 2)
                                }
                            } label: { Text(day.name).font(.headline).foregroundStyle(t.text) }
                        }
                    }.card()
                }
            }.padding(16)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle(program.name)
        .sheet(isPresented: $editing) { ProgramBuilderView(program: program) }
    }

    private func describe(_ ex: PlannedExercise) -> String {
        ex.groups.map { g in
            switch g.target {
            case .percent(let p, let r): return "\(g.count)×\(r) @ \(Int((p * 100).rounded()))%"
            case .rir(let r, let rir): return "\(g.count)×\(r) @ RIR \(Int(rir))"
            case .repRange(let lo, let hi, let rir): return "\(g.count)×\(lo)-\(hi) @ RIR \(Int(rir))"
            case .fixed(let w, let r): return "\(g.count)×\(r) @ \(store.format(store.toKg(w)))"
            }
        }.joined(separator: ", ")
    }
}

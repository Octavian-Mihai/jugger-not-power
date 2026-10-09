import SwiftUI
import SwiftData
import FerrumCore
import UniformTypeIdentifiers

struct ProgramsView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var t
    @Query(sort: \Program.createdAt, order: .reverse) private var programs: [Program]
    @State private var showGenerator = false
    @State private var editing: Program?
    @State private var editingIsNew = false
    @State private var pendingEdit: Program?
    @State private var importing = false
    @State private var importError: String?
    @Environment(Store.self) private var store

    var body: some View {
        Screen(title: "Programs") {
            HStack(spacing: 12) {
                Button { showGenerator = true } label: { Label("Generate", systemImage: "wand.and.stars") }
                    .buttonStyle(PrimaryButton())
                Button { createCustom() } label: { Label("Build own", systemImage: "pencil.and.ruler") }
                    .buttonStyle(PrimaryButton(prominent: false))
            }
            Button { importing = true } label: { Label("Import from file", systemImage: "square.and.arrow.down") }
                .buttonStyle(PrimaryButton(prominent: false))
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
        .sheet(isPresented: $showGenerator, onDismiss: {
            if let p = pendingEdit { pendingEdit = nil; editingIsNew = false; editing = p }
        }) { GeneratorView(profile: profile, onCustomize: { pendingEdit = $0 }) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { result in
            importFile(result)
        }
        .alert("Couldn't import program", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
        .sheet(item: $editing) { p in ProgramBuilderView(program: p, isNew: editingIsNew) }
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

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let plan = try ProgramInterchange.importPlan(try Data(contentsOf: url), library: store.library)
            let p = Program(plan: plan)
            context.insert(p)
            if programs.isEmpty { p.isActive = true }
        } catch let e as ProgramInterchange.ImportError {
            importError = e.problems.joined(separator: "\n")
        } catch {
            importError = "That file couldn't be read."
        }
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
        editingIsNew = true
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
    @State private var exportURL: URL?

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
                if let exportURL {
                    ShareLink(item: exportURL) { Label("Share / export program file", systemImage: "square.and.arrow.up") }
                        .font(.subheadline.weight(.semibold))
                }
                ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { bi, block in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(block.name).font(.title3.bold()).foregroundStyle(t.text)
                            Spacer()
                            Text("\(block.weeks) wks · \(block.phase.title)").font(.caption).foregroundStyle(t.secondary)
                        }
                        ForEach(block.days) { day in
                            if day.isRest {
                                Label(day.name, systemImage: "bed.double.fill").font(.headline).foregroundStyle(t.secondary)
                            } else {
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
                        }
                    }.card()
                }
            }.padding(16)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle(program.name)
        .sheet(isPresented: $editing) { ProgramBuilderView(program: program) }
        .onAppear(perform: writeExport)
        .onChange(of: program.planData) { _, _ in writeExport() }
    }

    private func writeExport() {
        guard let data = try? ProgramInterchange.export(program.plan) else { return }
        let safe = program.name.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-")).lowercased()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent((safe.isEmpty ? "program" : safe) + ".ferrum.json")
        try? data.write(to: url)
        exportURL = url
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

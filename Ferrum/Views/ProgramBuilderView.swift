import SwiftUI
import FerrumCore

/// Edits a copy of the plan and saves on Done.
struct ProgramBuilderView: View {
    let program: Program
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    @State private var plan: ProgramPlan = ProgramPlan(name: "", blocks: [])
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Program name", text: $plan.name) }
                Section {
                    ForEach($plan.blocks) { $block in
                        NavigationLink {
                            BlockEditor(block: $block)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(block.name).font(.headline)
                                Text("\(block.weeks) weeks · \(block.days.count) days · \(block.phase.title)")
                                    .font(.caption).foregroundStyle(t.secondary)
                            }
                        }
                    }
                    .onDelete { plan.blocks.remove(atOffsets: $0) }
                    .onMove { plan.blocks.move(fromOffsets: $0, toOffset: $1) }
                    Button { plan.blocks.append(Block(name: "Block \(plan.blocks.count + 1)", phase: .general, weeks: 4,
                                                      days: [PlannedDay(name: "Day 1")])) } label: { Label("Add block", systemImage: "plus") }
                } header: { Text("Blocks") } footer: {
                    Text("A block is a phase of training. Each week of a block repeats its days, with loads shifting by the block's progression settings.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Program builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        plan.goal = nil
                        program.plan = plan
                        dismiss()
                    }.disabled(plan.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if !loaded { plan = program.plan; loaded = true } }
        }
    }
}

struct BlockEditor: View {
    @Binding var block: Block
    @Environment(\.theme) private var t

    var body: some View {
        Form {
            Section("Block") {
                TextField("Name", text: $block.name)
                Picker("Phase", selection: $block.phase) {
                    ForEach(PhaseKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Stepper("\(block.weeks) weeks", value: $block.weeks, in: 1...16)
                Toggle("Deload last week", isOn: $block.deloadLastWeek)
            }
            Section {
                Stepper(value: $block.rirShiftStart, in: -3...3, step: 0.5) {
                    Text("RIR shift, week 1: \(shift(block.rirShiftStart))")
                }
                Stepper(value: $block.rirShiftEnd, in: -3...3, step: 0.5) {
                    Text("RIR shift, last week: \(shift(block.rirShiftEnd))")
                }
                Stepper(value: $block.percentStep, in: 0...0.05, step: 0.0025) {
                    Text("% step per week: +\(String(format: "%.2f", block.percentStep * 100))%")
                }
            } header: { Text("Progression") } footer: {
                Text("RIR shifts adjust RPE/RIR and rep-range targets across the block (negative = harder). The % step raises percentage-based sets each week.")
            }
            Section("Days") {
                ForEach($block.days) { $day in
                    NavigationLink { DayEditor(day: $day) } label: {
                        VStack(alignment: .leading) {
                            Text(day.name)
                            Text("\(day.exercises.count) exercises").font(.caption).foregroundStyle(t.secondary)
                        }
                    }
                }
                .onDelete { block.days.remove(atOffsets: $0) }
                .onMove { block.days.move(fromOffsets: $0, toOffset: $1) }
                Button { block.days.append(PlannedDay(name: "Day \(block.days.count + 1)")) } label: { Label("Add day", systemImage: "plus") }
                Button { duplicateLast() } label: { Label("Duplicate last day", systemImage: "plus.square.on.square") }
                    .disabled(block.days.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .background(t.bg.ignoresSafeArea())
        .navigationTitle(block.name)
        .toolbar { EditButton() }
    }

    private func shift(_ v: Double) -> String { v == 0 ? "0" : String(format: "%+.1f", v) }

    private func duplicateLast() {
        guard var copy = block.days.last else { return }
        copy.id = UUID(); copy.name += " copy"
        copy.exercises = copy.exercises.map { var e = $0; e.id = UUID(); e.groups = e.groups.map { var g = $0; g.id = UUID(); return g }; return e }
        block.days.append(copy)
    }
}

struct DayEditor: View {
    @Binding var day: PlannedDay
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var picking = false

    var body: some View {
        Form {
            Section("Day") { TextField("Name", text: $day.name) }
            Section("Exercises") {
                ForEach($day.exercises) { $ex in
                    NavigationLink { ExerciseEditor(exercise: $ex) } label: {
                        HStack(spacing: 12) {
                            ExerciseThumb(file: store.library.exercise(ex.exerciseID)?.image, size: 40)
                            VStack(alignment: .leading) {
                                Text(store.library.name(for: ex.exerciseID))
                                Text(ex.groups.map { "\($0.count)× \($0.target.kindTitle)" }.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(t.secondary)
                            }
                        }
                    }
                }
                .onDelete { day.exercises.remove(atOffsets: $0) }
                .onMove { day.exercises.move(fromOffsets: $0, toOffset: $1) }
                Button { picking = true } label: { Label("Add exercise", systemImage: "plus") }
            }
        }
        .scrollContentBackground(.hidden)
        .background(t.bg.ignoresSafeArea())
        .navigationTitle(day.name)
        .toolbar { EditButton() }
        .sheet(isPresented: $picking) {
            ExercisePicker { info in
                let mainLift = MainLift.allCases.first { $0.exerciseID == info.id }
                let target: SetTarget = mainLift != nil ? .percent(pct: 0.75, reps: 5) : .repRange(low: 8, high: 12, rir: 2)
                day.exercises.append(PlannedExercise(exerciseID: info.id, groups: [SetGroup(count: 3, target: target)],
                                                     restSeconds: mainLift != nil ? 180 : 90))
            }
        }
    }
}

struct ExerciseEditor: View {
    @Binding var exercise: PlannedExercise
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        Form {
            Section {
                Stepper("Rest \(exercise.restSeconds)s", value: $exercise.restSeconds, in: 15...600, step: 15)
                TextField("Note", text: $exercise.note)
                Picker("% reference lift", selection: Binding(get: { exercise.reference }, set: { exercise.reference = $0 })) {
                    Text("Auto").tag(MainLift?.none)
                    ForEach(MainLift.allCases) { Text($0.title).tag(MainLift?.some($0)) }
                }
            } header: { Text(store.library.name(for: exercise.exerciseID)) }
            ForEach($exercise.groups) { $group in
                Section {
                    GroupEditor(group: $group)
                } header: { Text("Set group") }
            }
            .onDelete { exercise.groups.remove(atOffsets: $0) }
            Section {
                Button { exercise.groups.append(SetGroup(count: 3, target: .repRange(low: 8, high: 12, rir: 2))) } label: {
                    Label("Add set group", systemImage: "plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("Sets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum Kind: String, CaseIterable { case percent = "% of 1RM", rir = "RPE / RIR", range = "Rep range", fixed = "Fixed" }

struct GroupEditor: View {
    @Binding var group: SetGroup
    @Environment(Store.self) private var store

    private var kind: Binding<Kind> {
        Binding {
            switch group.target { case .percent: return .percent; case .rir: return .rir; case .repRange: return .range; case .fixed: return .fixed }
        } set: { k in
            switch k {
            case .percent: group.target = .percent(pct: 0.75, reps: 5)
            case .rir: group.target = .rir(reps: 5, rir: 2)
            case .range: group.target = .repRange(low: 8, high: 12, rir: 2)
            case .fixed: group.target = .fixed(weight: 0, reps: 8)
            }
        }
    }

    var body: some View {
        Stepper("\(group.count) sets", value: $group.count, in: 1...12)
        Picker("Prescription", selection: kind) {
            ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        switch group.target {
        case .percent(let pct, let reps):
            Stepper("\(Int((pct * 100).rounded()))% of 1RM", value: Binding(get: { pct }, set: { group.target = .percent(pct: $0, reps: reps) }), in: 0.4...1.0, step: 0.025)
            Stepper("\(reps) reps", value: Binding(get: { reps }, set: { group.target = .percent(pct: pct, reps: $0) }), in: 1...20)
        case .rir(let reps, let rir):
            Stepper("\(reps) reps", value: Binding(get: { reps }, set: { group.target = .rir(reps: $0, rir: rir) }), in: 1...30)
            Stepper("Target RIR \(Int(rir))", value: Binding(get: { rir }, set: { group.target = .rir(reps: reps, rir: $0) }), in: 0...6)
        case .repRange(let lo, let hi, let rir):
            Stepper("Low \(lo) reps", value: Binding(get: { lo }, set: { group.target = .repRange(low: min($0, hi), high: hi, rir: rir) }), in: 1...50)
            Stepper("High \(hi) reps", value: Binding(get: { hi }, set: { group.target = .repRange(low: lo, high: max($0, lo), rir: rir) }), in: 1...50)
            Stepper("Target RIR \(Int(rir))", value: Binding(get: { rir }, set: { group.target = .repRange(low: lo, high: hi, rir: $0) }), in: 0...6)
        case .fixed(let w, let reps):
            HStack {
                Text("Weight")
                Spacer()
                NumberField(value: Binding(get: { w }, set: { group.target = .fixed(weight: $0, reps: reps) }))
                    .multilineTextAlignment(.trailing).frame(width: 90)
                Text(store.unit.label)
            }
            Stepper("\(reps) reps", value: Binding(get: { reps }, set: { group.target = .fixed(weight: w, reps: $0) }), in: 1...50)
        }
    }
}

struct ExercisePicker: View {
    let onPick: (ExerciseInfo) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var query = ""
    @State private var pattern: String?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button { pattern = nil } label: { Chip(text: "All", selected: pattern == nil) }
                            ForEach(store.library.patterns, id: \.self) { p in
                                Button { pattern = p } label: { Chip(text: p, selected: pattern == p) }
                            }
                        }
                    }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                ForEach(store.library.search(query, pattern: pattern)) { e in
                    Button { onPick(e); dismiss() } label: {
                        HStack(spacing: 12) {
                            ExerciseThumb(file: e.image, size: 44)
                            VStack(alignment: .leading) {
                                Text(e.name).foregroundStyle(t.text)
                                Text(e.pattern).font(.caption).foregroundStyle(t.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .searchable(text: $query)
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { creating = true } label: { Image(systemName: "plus.circle") } }
            }
            .sheet(isPresented: $creating) { CustomExerciseSheet() }
        }
    }
}

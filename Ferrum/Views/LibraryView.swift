import SwiftUI
import SwiftData
import FerrumCore

struct LibraryView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var query = ""
    @State private var pattern: String?
    @State private var muscle: String?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button { pattern = nil } label: { Chip(text: "All patterns", selected: pattern == nil) }.buttonStyle(PressableStyle())
                            ForEach(store.library.patterns, id: \.self) { p in
                                Button { pattern = (pattern == p) ? nil : p } label: { Chip(text: p, selected: pattern == p) }.buttonStyle(PressableStyle())
                            }
                        }
                    }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    NavigationLink { MuscleGuideView() } label: { Label("Muscle guide", systemImage: "figure.arms.open") }
                    NavigationLink { RIRGuideView() } label: { Label("RIR guide", systemImage: "gauge.with.needle") }
                }
                Section("Exercises") {
                    ForEach(store.library.search(query, pattern: pattern, muscle: muscle)) { e in
                        NavigationLink { ExerciseDetailView(exercise: e) } label: {
                            HStack(spacing: 12) {
                                ExerciseThumb(file: e.image, size: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name).foregroundStyle(t.text)
                                    Text(e.primary.compactMap { store.library.muscle($0)?.name }.joined(separator: ", "))
                                        .font(.caption).foregroundStyle(t.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button { creating = true } label: { Image(systemName: "plus") } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All muscles") { muscle = nil }
                        ForEach(store.library.muscles) { m in Button(m.name) { muscle = m.id } }
                    } label: { Image(systemName: muscle == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") }
                }
            }
            .sheet(isPresented: $creating) { CustomExerciseSheet() }
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: ExerciseInfo
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Query private var sets: [LoggedSet]

    var body: some View {
        let best = Analytics.bestE1RM(sets.filter { $0.isDone && $0.exerciseID == exercise.id }.map(\.record), exerciseID: exercise.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ExerciseHero(file: exercise.image)
                Text(exercise.name).font(.largeTitle.bold()).foregroundStyle(t.text)
                HStack { Chip(text: exercise.pattern, selected: true); Chip(text: exercise.equipment.capitalized) }
                if !exercise.cue.isEmpty { Text(exercise.cue).foregroundStyle(t.text).card() }
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(text: "Primary muscles")
                    Text(names(exercise.primary)).foregroundStyle(t.text)
                    if !exercise.secondary.isEmpty {
                        SectionHeader(text: "Secondary")
                        Text(names(exercise.secondary)).foregroundStyle(t.text)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).card()
                if best > 0 {
                    VStack(alignment: .leading) {
                        SectionHeader(text: "Best estimated 1RM")
                        Text(store.format(best)).font(.title.bold()).foregroundStyle(t.accent)
                    }.frame(maxWidth: .infinity, alignment: .leading).card()
                }
            }.padding(16)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func names(_ ids: [String]) -> String { ids.compactMap { store.library.muscle($0)?.name }.joined(separator: ", ") }
}

struct MuscleGuideView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    var body: some View {
        List(store.library.muscles) { m in
            NavigationLink {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ExerciseHero(file: m.image.map { "guide-" + $0 })
                        Text(m.name).font(.largeTitle.bold()).foregroundStyle(t.text)
                        info("Role", m.role); info("Function", m.function)
                        info("Examples", m.examples.joined(separator: ", ")); info("Patterns", m.patterns.joined(separator: ", "))
                    }.padding(16)
                }.background(t.bg.ignoresSafeArea())
            } label: {
                HStack(spacing: 12) {
                    ExerciseThumb(file: m.image.map { "guide-" + $0 }, size: 48)
                    VStack(alignment: .leading) { Text(m.name).foregroundStyle(t.text); Text(m.region).font(.caption).foregroundStyle(t.secondary) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(t.bg.ignoresSafeArea())
        .navigationTitle("Muscle guide")
    }
    private func info(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { SectionHeader(text: title); Text(text).foregroundStyle(t.text) }
            .frame(maxWidth: .infinity, alignment: .leading).card()
    }
}

struct RIRGuideView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.library.rirGuide, id: \.title) { level in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(level.title).font(.headline).foregroundStyle(t.accent)
                        Text(level.body).foregroundStyle(t.text)
                    }.frame(maxWidth: .infinity, alignment: .leading).card()
                }
            }.padding(16)
        }.background(t.bg.ignoresSafeArea()).navigationTitle("RIR guide")
    }
}

struct CustomExerciseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @State private var name = ""
    @State private var pattern = "Accessory"
    @State private var muscle = "chest-pectorals"
    @State private var equipment = "dumbbell"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name).doneOnSubmit()
                Picker("Movement pattern", selection: $pattern) { ForEach(store.library.patterns, id: \.self) { Text($0).tag($0) } }
                Picker("Primary muscle", selection: $muscle) { ForEach(store.library.muscles) { Text($0.name).tag($0.id) } }
                Picker("Equipment", selection: $equipment) {
                    ForEach(["barbell", "dumbbell", "cable", "machine", "bodyweight", "kettlebell", "band", "other"], id: \.self) { Text($0.capitalized).tag($0) }
                }
            }
            .navigationTitle("New exercise")
            .keyboardDoneBar().navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(CustomExercise(name: name, pattern: pattern, primaryMuscle: muscle, equipment: equipment))
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

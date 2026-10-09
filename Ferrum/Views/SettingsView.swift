import SwiftUI
import SwiftData
import FerrumCore

struct SettingsView: View {
    @Bindable var profile: Profile
    @Environment(Store.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var t
    @State private var confirmReset = false
    @State private var showMaxes = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight unit", selection: $profile.unitRaw) {
                        ForEach(WeightUnit.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                    }.pickerStyle(.segmented)
                }
                Section("Your maxes (1RM)") {
                    ForEach(MainLift.allCases) { lift in
                        HStack {
                            Text(lift.title)
                            Spacer()
                            Text(profile.oneRepMaxKg(lift) > 0 ? store.format(profile.oneRepMaxKg(lift)) : "Not set").foregroundStyle(t.secondary)
                        }
                    }
                    Button("Edit maxes") { showMaxes = true }
                }
                Section("Training") {
                    Stepper("\(profile.daysPerWeek) days per week", value: $profile.daysPerWeek, in: 2...6)
                    Picker("Experience", selection: $profile.experienceRaw) {
                        ForEach(Experience.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
                Section("Theme") {
                    ForEach(ThemeKind.allCases) { kind in
                        Button { profile.theme = kind } label: {
                            HStack {
                                Circle().fill(kind.theme.accent).frame(width: 22, height: 22)
                                VStack(alignment: .leading) {
                                    Text(kind.title).foregroundStyle(t.text)
                                    Text(kind.blurb).font(.caption).foregroundStyle(t.secondary)
                                }
                                Spacer()
                                if profile.theme == kind { Image(systemName: "checkmark").foregroundStyle(t.accent) }
                            }
                        }
                    }
                }
                #if DEBUG
                Section("Debug") { Button("Load demo training history") { DemoData.load(context: context) } }
                #endif
                Section {
                    Button("Erase all data", role: .destructive) { confirmReset = true }
                } footer: { Text("Ferrum stores everything on this device only.") }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .keyboardDoneBar()
            .sheet(isPresented: $showMaxes) { MaxesSheet(profile: profile) }
            .confirmationDialog("Erase all programs, workouts and settings?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) { eraseAll() }
            }
        }
    }

    private func eraseAll() {
        try? context.delete(model: Program.self)
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: LoggedSet.self)
        try? context.delete(model: ReadinessEntry.self)
        try? context.delete(model: CustomExercise.self)
        profile.onboarded = false
    }
}

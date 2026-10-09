import SwiftUI
import SwiftData

@main
struct FerrumApp: App {
    @State private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(for: [Profile.self, Program.self, WorkoutSession.self, LoggedSet.self,
                              ReadinessEntry.self, CustomExercise.self, BodyWeightEntry.self])
    }
}

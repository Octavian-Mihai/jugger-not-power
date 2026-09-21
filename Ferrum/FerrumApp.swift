import SwiftUI
import SwiftData

@main
struct FerrumApp: App {
    var sharedModelContainer: ModelContainer = FerrumPersistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Query private var users: [User]

    var body: some View {
        Group {
            if let user = users.first(where: \.hasCompletedOnboarding) {
                MainTabView(user: user)
            } else {
                OnboardingView()
            }
        }
        .ferrumScreen()
    }
}

struct MainTabView: View {
    @Bindable var user: User
    @StateObject private var restTimer = RestTimer()
    @State private var selectedTab: FerrumTab = .today
    @State private var focusedDayID: PersistentIdentifier?

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(user: user, selectedTab: $selectedTab, focusedDayID: $focusedDayID)
                .tabItem { Label("Today", systemImage: "flame.fill") }
                .tag(FerrumTab.today)
            WorkoutLoggerView(user: user, focusedDayID: $focusedDayID)
                .tabItem { Label("Log", systemImage: "list.clipboard.fill") }
                .tag(FerrumTab.log)
            AnalyticsView(user: user)
                .tabItem { Label("Analytics", systemImage: "chart.xyaxis.line") }
                .tag(FerrumTab.analytics)
            SettingsView(user: user)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(FerrumTab.settings)
        }
        .environmentObject(restTimer)
        .safeAreaInset(edge: .bottom) {
            if restTimer.isRunning || restTimer.remainingSeconds > 0 {
                timerBanner
            }
        }
        .ferrumScreen()
        .keyboardDoneButton()
    }

    private var timerBanner: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Rest")
                    .font(.caption)
                    .foregroundStyle(FerrumTheme.textSecondary)
                Text(restTimer.display)
                    .font(.title.monospacedDigit())
                    .foregroundStyle(FerrumTheme.copper)
            }
            Spacer()
            ProgressView(value: restTimer.progress)
                .tint(FerrumTheme.copper)
                .frame(width: 80)
            Button("+30s") { restTimer.addThirtySeconds() }
                .foregroundStyle(FerrumTheme.copper)
            Button("Skip") { restTimer.skip() }
                .foregroundStyle(FerrumTheme.textSecondary)
        }
        .padding()
        .background(FerrumTheme.elevated)
    }
}

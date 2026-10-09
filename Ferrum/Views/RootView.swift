import SwiftUI
import SwiftData
import FerrumCore

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(Store.self) private var store
    @Query private var profiles: [Profile]
    @Query private var customExercises: [CustomExercise]

    private var profile: Profile? { profiles.first }

    var body: some View {
        let theme = (profile?.theme ?? .forge).theme
        Group {
            if let profile, profile.onboarded {
                MainTabs(profile: profile)
            } else if let profile {
                OnboardingView(profile: profile)
            } else {
                Color.clear
            }
        }
        .environment(\.theme, theme)
        .tint(theme.accent)
        .preferredColorScheme(theme.dark ? .dark : .light)
        .background(theme.bg.ignoresSafeArea())
        .onAppear {
            if profiles.isEmpty { context.insert(Profile()) }
            store.unit = profile?.unit ?? .kg
            Haptics.enabled = profile?.hapticsEnabled ?? true
            store.refreshCustom(customExercises)
        }
        .onChange(of: profile?.hapticsEnabled) { _, v in Haptics.enabled = v ?? true }
        .onChange(of: profile?.unitRaw) { _, _ in store.unit = profile?.unit ?? .kg }
        .onChange(of: customExercises.count) { _, _ in store.refreshCustom(customExercises) }
    }
}

struct MainTabs: View {
    let profile: Profile
    @Environment(\.theme) private var t
    var body: some View {
        TabView {
            TodayView(profile: profile).tabItem { Label("Today", systemImage: "bolt.fill") }
            ProgramsView(profile: profile).tabItem { Label("Programs", systemImage: "list.bullet.rectangle") }
            LibraryView().tabItem { Label("Library", systemImage: "figure.strengthtraining.traditional") }
            ProgressTab(profile: profile).tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView(profile: profile).tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

/// Common scroll screen with the themed background.
struct Screen<Content: View>: View {
    @Environment(\.theme) private var t
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(.horizontal, 16).padding(.bottom, 32)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle(title)
            .keyboardDoneBar()
        }
    }
}

struct SectionHeader: View {
    @Environment(\.theme) private var t
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(t.secondary)
    }
}

/// Exercise images sit on white so the ones without a background look consistent.
struct ExerciseThumb: View {
    let file: String?
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            Color.white
            if let img = ImageStore.image(file, maxDimension: size * 3) {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: "dumbbell.fill").foregroundStyle(Color.gray)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Full-width image on a white card.
struct ExerciseHero: View {
    let file: String?
    var body: some View {
        if let img = ImageStore.image(file, maxDimension: 1200) {
            Image(uiImage: img).resizable().scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct Chip: View {
    @Environment(\.theme) private var t
    let text: String
    var selected = false
    var body: some View {
        Text(text).font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(selected ? t.onAccent : t.text)
            .background(selected ? t.accent : t.card, in: Capsule())
    }
}

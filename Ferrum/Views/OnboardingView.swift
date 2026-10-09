import SwiftUI
import FerrumCore

struct OnboardingView: View {
    @Bindable var profile: Profile
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var step = 0

    var body: some View {
        NavigationStack { content.toolbar(.hidden, for: .navigationBar).keyboardDoneBar() }
    }

    private var content: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(step + 1), total: 4).tint(t.accent).padding(.top, 8)
            Group {
                switch step {
                case 0: welcome
                case 1: unitsAndExperience
                case 2: lifts
                default: themePick
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 { Button("Back") { step -= 1 }.buttonStyle(PrimaryButton(prominent: false)) }
                Button(step == 3 ? "Start training" : (step == 2 && !hasMaxes ? "Skip for now" : "Continue")) { next() }.buttonStyle(PrimaryButton())
            }
        }
        .padding(20)
        .background(t.bg.ignoresSafeArea())
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FERRUM").font(.system(size: 44, weight: .black)).tracking(4).foregroundStyle(t.accent)
            Text("Your strength coach.").font(.title.bold()).foregroundStyle(t.text)
            Text("Generate a program built around your lifts and schedule, or write your own from scratch. Ferrum adjusts loads from your readiness and how each set felt.")
                .foregroundStyle(t.secondary)
            VStack(alignment: .leading, spacing: 10) {
                feature("wand.and.stars", "Generated or fully custom programs")
                feature("heart.text.square", "Daily readiness check-in")
                feature("gauge.with.needle", "RIR-based load adjustment")
                feature("chart.xyaxis.line", "Strength and volume analytics")
            }.padding(.top, 8)
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        Label { Text(text).foregroundStyle(t.text) } icon: { Image(systemName: icon).foregroundStyle(t.accent) }
    }

    private var unitsAndExperience: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About you").font(.title.bold()).foregroundStyle(t.text)
            SectionHeader(text: "Units")
            Picker("Units", selection: $profile.unitRaw) {
                ForEach(WeightUnit.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
            }.pickerStyle(.segmented)
            SectionHeader(text: "Experience")
            Picker("Experience", selection: $profile.experienceRaw) {
                ForEach(Experience.allCases) { Text($0.title).tag($0.rawValue) }
            }.pickerStyle(.segmented)
            SectionHeader(text: "Days per week")
            Stepper(value: $profile.daysPerWeek, in: 2...6) {
                Text("\(profile.daysPerWeek) days").font(.title3.bold()).foregroundStyle(t.text)
            }
        }
    }

    private var lifts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your current maxes").font(.title.bold()).foregroundStyle(t.text)
                Text("Enter your one-rep max in \(profile.unit.label), or estimate it from a recent hard set. Ferrum needs these to show weights for your lifts.")
                    .foregroundStyle(t.secondary)
                MaxesEditor(profile: profile)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var hasMaxes: Bool { MainLift.allCases.contains { profile.oneRepMaxKg($0) > 0 } }

    private var themePick: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick a look").font(.title.bold()).foregroundStyle(t.text)
            ForEach(ThemeKind.allCases) { kind in
                Button { profile.theme = kind } label: {
                    HStack {
                        Circle().fill(kind.theme.accent).frame(width: 28, height: 28)
                        VStack(alignment: .leading) {
                            Text(kind.title).font(.headline)
                            Text(kind.blurb).font(.caption).foregroundStyle(t.secondary)
                        }
                        Spacer()
                        if profile.theme == kind { Image(systemName: "checkmark.circle.fill").foregroundStyle(t.accent) }
                    }
                    .foregroundStyle(t.text).card()
                }
            }
        }
    }

    private func next() {
        if step == 1 { store.unit = profile.unit }
        Keyboard.hide()
        if step == 3 { profile.onboarded = true } else { step += 1 }
    }
}

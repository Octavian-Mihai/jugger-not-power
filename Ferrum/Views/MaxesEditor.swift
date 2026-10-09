import SwiftUI
import FerrumCore

/// Edit squat / bench / deadlift maxes, with an estimator from a recent hard set.
struct MaxesEditor: View {
    @Bindable var profile: Profile
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var estimating: MainLift?
    @State private var estWeight: Double = 0
    @State private var estReps: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MainLift.allCases) { lift in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(lift.title).font(.headline).foregroundStyle(t.text)
                        Spacer()
                        NumberField(value: Binding(get: { store.display(profile.oneRepMaxKg(lift)) },
                                                   set: { profile.setOneRepMaxKg(lift, store.toKg($0)) }))
                            .multilineTextAlignment(.trailing).frame(width: 90).foregroundStyle(t.text)
                        Text(profile.unit.label).foregroundStyle(t.secondary)
                    }
                    Button(estimating == lift ? "Hide estimator" : "Don't know it? Estimate from a set") {
                        estimating = (estimating == lift) ? nil : lift; estWeight = 0; estReps = 0
                    }.font(.caption.weight(.semibold))
                    if estimating == lift {
                        HStack {
                            NumberField(value: $estWeight).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text(profile.unit.label).foregroundStyle(t.secondary)
                            Text("×").foregroundStyle(t.secondary)
                            NumberField(value: $estReps, decimals: false).textFieldStyle(.roundedBorder).frame(width: 60)
                            Text("reps").foregroundStyle(t.secondary)
                            Spacer()
                            Button("Use") {
                                let e = Estimation.e1RM(weight: estWeight, reps: Int(estReps), rir: 0)
                                if e > 0 { profile.setOneRepMaxKg(lift, store.toKg(profile.unit.round(e))); estimating = nil }
                            }.buttonStyle(.borderedProminent).disabled(estWeight <= 0 || estReps < 1)
                        }
                        Text("Use a set taken close to failure. Estimate rounds to the nearest plate jump.")
                            .font(.caption2).foregroundStyle(t.secondary)
                    }
                }.card()
            }
        }
    }
}

struct MaxesSheet: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ferrum uses these to turn percentages and RIR targets into real weights.").foregroundStyle(t.secondary)
                    MaxesEditor(profile: profile)
                }.padding(16)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Your maxes").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .keyboardDoneBar()
        }
    }
}

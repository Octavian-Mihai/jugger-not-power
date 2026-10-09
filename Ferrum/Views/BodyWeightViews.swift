import SwiftUI
import SwiftData
import Charts
import FerrumCore

struct BodyWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @State private var value: Double = 0
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weigh yourself first thing in the morning for the cleanest trend.").foregroundStyle(t.secondary)
                HStack {
                    NumberField(value: $value, placeholder: "0.0").font(.system(size: 44, weight: .bold))
                        .multilineTextAlignment(.trailing).foregroundStyle(t.text)
                    Text(store.unit.label).font(.title2).foregroundStyle(t.secondary)
                }.card()
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date).foregroundStyle(t.text).card()
                Button("Save") {
                    guard value > 0 else { return }
                    context.insert(BodyWeightEntry(kg: store.toKg(value), date: date)); dismiss()
                }.buttonStyle(PrimaryButton()).disabled(value <= 0)
                Spacer()
            }
            .padding(16)
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("Log body weight").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .keyboardDoneBar()
            .onAppear { if let last = entries.first { value = (store.display(last.kg) * 10).rounded() / 10 } }
        }
    }
}

struct BodyWeightCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query(sort: \BodyWeightEntry.date) private var entries: [BodyWeightEntry]
    @State private var showSheet = false
    @State private var range = 90

    var body: some View {
        let all = entries.map(\.point)
        let since = Calendar.current.date(byAdding: .day, value: -range, to: .now) ?? .now
        let shown = all.filter { $0.date >= since }
        let avg = BodyWeight.movingAverage(all).filter { $0.date >= since }
        let change = BodyWeight.change(all, overDays: 30)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(text: "Body weight")
                Spacer()
                Picker("Range", selection: $range) { Text("30d").tag(30); Text("90d").tag(90); Text("1y").tag(365) }
                    .pickerStyle(.segmented).frame(width: 150)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let last = entries.last {
                    Text(store.format(last.kg)).font(.title.bold()).foregroundStyle(t.text)
                }
                if let change {
                    let shownChange = store.display(change)
                    Label(String(format: "%+.1f %@ / 30d", shownChange, store.unit.label),
                          systemImage: shownChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(t.secondary)
                }
                Spacer()
                Button("Log") { showSheet = true }.font(.subheadline.weight(.semibold))
            }
            if shown.count < 2 {
                EmptyState(icon: "scalemass", title: entries.isEmpty ? "No weigh-ins yet" : "One more weigh-in",
                           message: entries.isEmpty ? "Log your weight to see the trend." : "Log again on another day to draw the trend.",
                           actionTitle: entries.isEmpty ? "Log weight" : nil, compact: true) { showSheet = true }
            } else {
                Chart {
                    ForEach(shown) { p in
                        PointMark(x: .value("Date", p.date), y: .value("Weight", store.display(p.kg)))
                            .foregroundStyle(t.secondary.opacity(0.6)).symbolSize(24)
                    }
                    ForEach(avg) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Trend", store.display(p.kg)))
                            .foregroundStyle(t.accent).interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                Text("Dots are daily weigh-ins; the line is a 7-day average.").font(.caption2).foregroundStyle(t.secondary)
            }
            if !entries.isEmpty {
                NavigationLink { BodyWeightHistory() } label: { Text("All entries").font(.subheadline.weight(.semibold)) }
            }
        }
        .card()
        .sheet(isPresented: $showSheet) { BodyWeightSheet() }
    }
}

struct BodyWeightHistory: View {
    @Environment(\.modelContext) private var context
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]

    var body: some View {
        List {
            ForEach(entries) { e in
                HStack {
                    Text(e.date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(t.text)
                    Spacer()
                    Text(store.format(e.kg)).font(.body.monospacedDigit()).foregroundStyle(t.text)
                }
            }
            .onDelete { for i in $0 { context.delete(entries[i]) } }
        }
        .scrollContentBackground(.hidden).background(t.bg.ignoresSafeArea())
        .navigationTitle("Body weight")
        .toolbar { EditButton() }
    }
}

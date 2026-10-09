import Foundation

public struct BodyWeightPoint: Identifiable, Hashable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let kg: Double
    public init(date: Date, kg: Double) { self.date = date; self.kg = kg }
}

public enum BodyWeight {
    /// One reading per calendar day (the latest of that day), oldest first.
    public static func daily(_ points: [BodyWeightPoint], calendar: Calendar = .current) -> [BodyWeightPoint] {
        let byDay = Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
        return byDay.compactMap { day, rows in rows.max(by: { $0.date < $1.date }).map { BodyWeightPoint(date: day, kg: $0.kg) } }
            .sorted { $0.date < $1.date }
    }

    /// Trailing moving average over `window` days; smooths day-to-day water swings.
    public static func movingAverage(_ points: [BodyWeightPoint], window: Int = 7, calendar: Calendar = .current) -> [BodyWeightPoint] {
        let d = daily(points, calendar: calendar)
        return d.map { p in
            let start = calendar.date(byAdding: .day, value: -(window - 1), to: p.date) ?? p.date
            let recent = d.filter { $0.date >= start && $0.date <= p.date }
            return BodyWeightPoint(date: p.date, kg: recent.map(\.kg).reduce(0, +) / Double(recent.count))
        }
    }

    /// Change in kg between the smoothed value `days` ago (or the first reading) and the latest. nil with fewer than 2 days of data.
    public static func change(_ points: [BodyWeightPoint], overDays days: Int, calendar: Calendar = .current) -> Double? {
        let avg = movingAverage(points, calendar: calendar)
        guard let last = avg.last, avg.count >= 2 else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -days, to: last.date) ?? last.date
        let base = avg.last(where: { $0.date <= cutoff }) ?? avg.first!
        guard base.date != last.date else { return nil }
        return last.kg - base.kg
    }
}

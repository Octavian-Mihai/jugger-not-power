import Foundation

public struct SetRecord: Hashable, Sendable {
    public let exerciseID: String
    public let weight: Double
    public let reps: Int
    public let rir: Double
    public let date: Date
    public init(exerciseID: String, weight: Double, reps: Int, rir: Double, date: Date) {
        self.exerciseID = exerciseID; self.weight = weight; self.reps = reps; self.rir = rir; self.date = date
    }
    public var e1RM: Double { Estimation.e1RM(weight: weight, reps: reps, rir: rir) }
    public var volume: Double { weight * Double(reps) }
}

public struct E1RMPoint: Identifiable, Hashable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let value: Double
}

public enum Analytics {
    /// Hard sets per muscle (primary = 1, secondary = 0.5). Sets with 5+ RIR don't count.
    public static func muscleSets(_ sets: [SetRecord], library: ExerciseLibrary) -> [String: Double] {
        var out: [String: Double] = [:]
        for s in sets where s.rir < 5 {
            guard let e = library.exercise(s.exerciseID) else { continue }
            for m in e.primary { out[m, default: 0] += 1 }
            for m in e.secondary { out[m, default: 0] += 0.5 }
        }
        return out
    }

    /// Best estimated 1RM per calendar day for an exercise.
    public static func e1RMHistory(_ sets: [SetRecord], exerciseID: String, calendar: Calendar = .current) -> [E1RMPoint] {
        let days = Dictionary(grouping: sets.filter { $0.exerciseID == exerciseID }) { calendar.startOfDay(for: $0.date) }
        return days.map { E1RMPoint(date: $0.key, value: $0.value.map(\.e1RM).max() ?? 0) }.sorted { $0.date < $1.date }
    }

    public static func bestE1RM(_ sets: [SetRecord], exerciseID: String) -> Double {
        sets.filter { $0.exerciseID == exerciseID }.map(\.e1RM).max() ?? 0
    }

    /// A set is a PR when its e1RM beats everything logged before it.
    public static func isPR(_ set: SetRecord, history: [SetRecord]) -> Bool {
        let prior = bestE1RM(history.filter { $0.date < set.date }, exerciseID: set.exerciseID)
        return set.e1RM > prior && set.e1RM > 0
    }

    public static func totalVolume(_ sets: [SetRecord]) -> Double { sets.reduce(0) { $0 + $1.volume } }
}

public struct WeekPoint: Identifiable, Hashable, Sendable {
    public var id: Date { weekStart }
    public let weekStart: Date
    public let volume: Double   // tonnage: weight x reps
    public let sets: Int
}

public struct Improvement: Hashable, Sendable {
    public let exerciseID: String
    public let first: Double
    public let latest: Double
    public var percent: Double { first > 0 ? (latest - first) / first * 100 : 0 }
}

public extension Analytics {
    /// Tonnage and set count per calendar week, oldest first, zero-filled for the last `weeks` weeks.
    static func weeklyTotals(_ sets: [SetRecord], weeks: Int, now: Date = .now, calendar: Calendar = .current) -> [WeekPoint] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let grouped = Dictionary(grouping: sets) { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date }
        return (0..<weeks).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek) else { return nil }
            let rows = grouped[start] ?? []
            return WeekPoint(weekStart: start, volume: totalVolume(rows), sets: rows.count)
        }
    }

    /// First vs. latest daily-best e1RM. nil until the exercise has been trained on two different days.
    static func improvement(_ sets: [SetRecord], exerciseID: String, calendar: Calendar = .current) -> Improvement? {
        let h = e1RMHistory(sets, exerciseID: exerciseID, calendar: calendar)
        guard h.count >= 2, let f = h.first, let l = h.last else { return nil }
        return Improvement(exerciseID: exerciseID, first: f.value, latest: l.value)
    }

    /// e1RM history as % change from the first session (0 = starting point).
    static func percentChangeHistory(_ sets: [SetRecord], exerciseID: String, calendar: Calendar = .current) -> [E1RMPoint] {
        let h = e1RMHistory(sets, exerciseID: exerciseID, calendar: calendar)
        guard let first = h.first?.value, first > 0 else { return [] }
        return h.map { E1RMPoint(date: $0.date, value: ($0.value - first) / first * 100) }
    }
}

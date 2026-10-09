import Foundation

public struct ProgressionSuggestion: Hashable, Sendable {
    public let weight: Double
    public let reps: Int
    public let increased: Bool
}

public enum Progression {
    /// Add weight once every set hit the top of the range with RIR at or inside the target,
    /// otherwise stay on the weight and aim for one more rep on the weakest set.
    public static func doubleProgression(last: [(weight: Double, reps: Int, rir: Double)], low: Int, high: Int,
                                         targetRIR: Double, unit: WeightUnit) -> ProgressionSuggestion {
        guard let top = last.map(\.weight).max() else {
            return ProgressionSuggestion(weight: 0, reps: low, increased: false)
        }
        let atTop = last.filter { $0.weight == top }
        let allAtHigh = atTop.allSatisfy { $0.reps >= high }
        let tooEasy = atTop.allSatisfy { $0.rir > targetRIR + 2 && $0.reps >= low }
        if allAtHigh || tooEasy {
            return ProgressionSuggestion(weight: unit.round(top + unit.step), reps: low, increased: true)
        }
        let weakest = atTop.map(\.reps).min() ?? low
        return ProgressionSuggestion(weight: top, reps: min(max(weakest + 1, low), high), increased: false)
    }
}

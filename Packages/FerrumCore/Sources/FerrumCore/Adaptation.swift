import Foundation

/// In-workout load adaptation: how the next set, and the rest of the session, react to how a set actually went.
public enum Adaptation {
    public struct Performed: Sendable {
        public let weight: Double
        public let reps: Int
        public let rir: Double
        public let targetRIR: Double
        public init(weight: Double, reps: Int, rir: Double, targetRIR: Double) {
            self.weight = weight; self.reps = reps; self.rir = rir; self.targetRIR = targetRIR
        }
        /// Positive = harder than planned (fewer reps in reserve than targeted).
        public var hardness: Double { targetRIR - rir }
    }

    /// Weight for the next set of the same exercise.
    ///
    /// Starts from the estimated 1RM implied by the set just done, then trims further when the set was
    /// harder than planned, when it was close to failure, and especially when the set coming up is the last one.
    public static func nextSetLoad(after previous: Performed, nextReps: Int, nextRIR: Double,
                                   isLastSet: Bool, unit: WeightUnit) -> Double {
        guard previous.weight > 0, previous.reps > 0 else { return 0 }
        let e1RM = Estimation.e1RM(weight: previous.weight, reps: previous.reps, rir: previous.rir)
        var load = Estimation.load(e1RM: e1RM, reps: nextReps, rir: nextRIR)
        var penalty = 0.02 * max(0, previous.hardness)
        if previous.rir <= 1 {
            penalty += 0.02
            if isLastSet { penalty += 0.03 }
        }
        load *= 1 - min(penalty, 0.12)
        load = min(max(load, previous.weight * 0.88), previous.weight * 1.10)
        return unit.round(load)
    }

    /// Multiplier for exercises still to come, from how the finished ones went.
    /// `hardness` holds one value per completed set (target RIR minus actual RIR).
    public static func sessionFactor(hardness: [Double]) -> Double {
        guard hardness.count >= 2 else { return 1 }
        let avg = hardness.reduce(0, +) / Double(hardness.count)
        if avg > 0.5 { return 1 - min(0.06, 0.03 * (avg - 0.5)) }
        if avg < -1.5 { return 1 + min(0.03, 0.015 * (-avg - 1)) }
        return 1
    }
}

public enum PlateMath {
    public enum Kind: Sendable { case enterWeight, belowBar, barOnly, plates }

    public struct Breakdown: Sendable {
        public let kind: Kind
        public let perSide: [Double]
        /// Weight (both sides combined) that can't be made with the plates available.
        public let remainder: Double

        public var headline: String {
            switch kind {
            case .enterWeight: return "Enter weight"
            case .belowBar: return "Below bar"
            case .barOnly: return "Bar only"
            case .plates:
                return "Per side " + perSide.map(PlateMath.format).joined(separator: " + ")
            }
        }
        public var remainderText: String? { remainder > 0.001 ? "rem \(PlateMath.format(remainder))" : nil }
    }

    public static func plates(for unit: WeightUnit) -> [Double] {
        unit == .kg ? [25, 20, 15, 10, 5, 2.5, 1.25] : [45, 35, 25, 10, 5, 2.5]
    }

    public static func defaultBar(for unit: WeightUnit) -> Double { unit == .kg ? 20 : 45 }

    public static func breakdown(total: Double, bar: Double, unit: WeightUnit) -> Breakdown {
        guard total > 0 else { return Breakdown(kind: .enterWeight, perSide: [], remainder: 0) }
        if total < bar - 0.001 { return Breakdown(kind: .belowBar, perSide: [], remainder: 0) }
        var left = (total - bar) / 2
        if left < 0.001 { return Breakdown(kind: .barOnly, perSide: [], remainder: 0) }
        var out: [Double] = []
        for p in plates(for: unit) {
            while left >= p - 0.0001 { out.append(p); left -= p }
        }
        return Breakdown(kind: .plates, perSide: out, remainder: left < 0.0001 ? 0 : left * 2)
    }

    public static func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%g", (v * 100).rounded() / 100)
    }
}

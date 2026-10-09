import Foundation

public enum Estimation {
    /// Reps that would have been possible to failure = reps done + reps in reserve.
    private static func total(_ reps: Int, _ rir: Double) -> Double {
        min(max(Double(reps) + max(rir, 0), 1), 20)
    }

    /// Epley estimate that counts reps left in the tank.
    public static func e1RM(weight: Double, reps: Int, rir: Double = 0) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        let t = total(reps, rir)
        return t <= 1 ? weight : weight * (1 + t / 30)
    }

    /// Load that should leave `rir` reps in reserve after `reps` reps.
    public static func load(e1RM: Double, reps: Int, rir: Double) -> Double {
        guard e1RM > 0, reps > 0 else { return 0 }
        let t = total(reps, rir)
        return t <= 1 ? e1RM : e1RM / (1 + t / 30)
    }

    /// Next-set suggestion after a logged set, damped to +/-10% of what was lifted.
    public static func nextLoad(afterWeight weight: Double, reps: Int, rir: Double,
                                nextReps: Int, nextRIR: Double, unit: WeightUnit) -> Double {
        let raw = load(e1RM: e1RM(weight: weight, reps: reps, rir: rir), reps: nextReps, rir: nextRIR)
        let clamped = min(max(raw, weight * 0.9), weight * 1.1)
        return unit.round(clamped)
    }

    public static func percentOfMax(weight: Double, max: Double) -> Double {
        max > 0 ? weight / max : 0
    }
}

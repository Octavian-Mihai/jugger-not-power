import Foundation

public struct ResolvedSet: Hashable, Identifiable, Sendable {
    public var id = UUID()
    public let index: Int
    public let reps: Int          // target reps (top of range for ranges)
    public let repsLow: Int
    public let targetRIR: Double
    public let weight: Double?    // nil = lifter picks (no history yet)
    public let percent: Double?
    public let isRange: Bool
}

public struct ResolvedExercise: Hashable, Identifiable, Sendable {
    public var id: UUID
    public let exerciseID: String
    public let restSeconds: Int
    public let note: String
    public let sets: [ResolvedSet]
}

/// What the resolver may need to know about the lifter.
public struct LoadContext: Sendable {
    public var unit: WeightUnit
    /// 1RM per main lift.
    public var oneRepMax: [MainLift: Double]
    /// Most recent working performance per exercise id.
    public var lastPerformance: [String: LastPerformance]
    public init(unit: WeightUnit = .kg, oneRepMax: [MainLift: Double] = [:], lastPerformance: [String: LastPerformance] = [:]) {
        self.unit = unit; self.oneRepMax = oneRepMax; self.lastPerformance = lastPerformance
    }
}

public struct LastPerformance: Hashable, Sendable {
    public let sets: [(weight: Double, reps: Int, rir: Double)]
    public init(sets: [(weight: Double, reps: Int, rir: Double)]) { self.sets = sets }
    public static func == (l: LastPerformance, r: LastPerformance) -> Bool {
        l.sets.count == r.sets.count && zip(l.sets, r.sets).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 && $0.2 == $1.2 }
    }
    public func hash(into h: inout Hasher) { for s in sets { h.combine(s.weight); h.combine(s.reps) } }
    /// Best e1RM across the sets.
    public var bestE1RM: Double { sets.map { Estimation.e1RM(weight: $0.weight, reps: $0.reps, rir: $0.rir) }.max() ?? 0 }
}

public enum Resolver {
    public static func rirShift(block: Block, weekInBlock: Int) -> Double {
        let working = max(block.weeks - (block.deloadLastWeek ? 1 : 0), 1)
        guard working > 1 else { return block.rirShiftStart }
        let t = min(Double(weekInBlock), Double(working - 1)) / Double(working - 1)
        return block.rirShiftStart + (block.rirShiftEnd - block.rirShiftStart) * t
    }

    public static func resolve(day: PlannedDay, block: Block, weekInBlock: Int, isDeload: Bool,
                               context: LoadContext, library: ExerciseLibrary,
                               readiness: ReadinessAdjustment = .neutral) -> [ResolvedExercise] {
        let shift = rirShift(block: block, weekInBlock: weekInBlock) + (isDeload ? 2 : 0) + readiness.rirOffset
        let pctShift = block.percentStep * Double(weekInBlock) - (isDeload ? 0.10 : 0)

        return day.exercises.map { planned in
            let ref = planned.reference ?? library.referenceLift(for: planned.exerciseID)
            let max1RM = ref.flatMap { context.oneRepMax[$0] }
            var sets: [ResolvedSet] = []

            for group in planned.groups {
                var count = group.count
                if isDeload { count = Swift.max(1, Int((Double(count) * 0.5).rounded(.up))) }
                count = Swift.max(1, count + readiness.setDelta)
                for _ in 0..<count {
                    sets.append(resolveSet(target: group.target, index: sets.count, shift: shift, pctShift: pctShift,
                                           max1RM: max1RM, planned: planned, context: context,
                                           loadMultiplier: readiness.loadMultiplier))
                }
            }
            return ResolvedExercise(id: planned.id, exerciseID: planned.exerciseID, restSeconds: planned.restSeconds,
                                    note: planned.note, sets: sets)
        }
    }

    private static func resolveSet(target: SetTarget, index: Int, shift: Double, pctShift: Double, max1RM: Double?,
                                   planned: PlannedExercise, context: LoadContext, loadMultiplier: Double) -> ResolvedSet {
        let unit = context.unit
        let last = context.lastPerformance[planned.exerciseID]
        func e1RM() -> Double? {
            if let last, last.bestE1RM > 0 { return last.bestE1RM }
            return nil
        }
        func rounded(_ w: Double) -> Double { unit.round(w * loadMultiplier) }

        switch target {
        case .percent(let pct, let reps):
            let p = Swift.max(0.3, Swift.min(pct + pctShift, 1.0))
            let w = max1RM.map { rounded($0 * p) }
            return ResolvedSet(index: index, reps: reps, repsLow: reps, targetRIR: 2, weight: w, percent: p, isRange: false)
        case .rir(let reps, let rir):
            let r = Swift.max(rir + shift, 0)
            let base = e1RM() ?? max1RM
            let w = base.map { rounded(Estimation.load(e1RM: $0, reps: reps, rir: r)) }
            return ResolvedSet(index: index, reps: reps, repsLow: reps, targetRIR: r, weight: w, percent: nil, isRange: false)
        case .repRange(let low, let high, let rir):
            let r = Swift.max(rir + shift, 0)
            var reps = high
            var w: Double?
            if let last, !last.sets.isEmpty {
                let s = Progression.doubleProgression(last: last.sets, low: low, high: high, targetRIR: r, unit: unit)
                reps = s.reps; w = s.weight * loadMultiplier
                w = w.map { unit.round($0) }
            } else if let base = max1RM {
                // No history: start a variation conservatively from the main lift.
                w = rounded(Estimation.load(e1RM: base * 0.6, reps: (low + high) / 2, rir: r))
                reps = (low + high) / 2
            }
            return ResolvedSet(index: index, reps: reps, repsLow: low, targetRIR: r, weight: w, percent: nil, isRange: true)
        case .fixed(let weight, let reps):
            return ResolvedSet(index: index, reps: reps, repsLow: reps, targetRIR: 2, weight: weight, percent: nil, isRange: false)
        }
    }
}

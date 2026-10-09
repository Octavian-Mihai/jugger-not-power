#if DEBUG
import Foundation
import SwiftData

/// Debug-only: fills the store with ~9 weeks of plausible finished sessions so charts can be inspected.
enum DemoData {
    static func load(context: ModelContext) {
        let cal = Calendar.current
        let plan: [(String, Double, Int)] = [("back-squat", 120, 5), ("barbell-bench-press", 85, 5), ("deadlift", 150, 4),
                                             ("romanian-deadlift", 90, 8), ("lat-pulldown", 60, 10), ("lateral-raise", 10, 12)]
        for week in 0..<9 {
            for day in 0..<3 {
                guard let date = cal.date(byAdding: .day, value: -((8 - week) * 7 + (2 - day) * 2), to: .now) else { continue }
                let s = WorkoutSession(programID: nil, dayName: ["Squat", "Bench", "Deadlift"][day], blockName: "Demo",
                                       weekLabel: "Week \(week + 1)", readinessScore: 70)
                s.date = date; s.isFinished = true; s.finishedAt = date.addingTimeInterval(3600)
                context.insert(s)
                for (order, ex) in plan.enumerated() where order % 3 == day || order >= 3 {
                    let w = ex.1 + Double(week) * (ex.1 > 100 ? 2.5 : 1.25)
                    for i in 0..<3 {
                        let set = LoggedSet(exerciseID: ex.0, exerciseOrder: order, setIndex: i, restSeconds: 120,
                                            targetReps: ex.2, targetRepsLow: ex.2, targetRIR: 2, targetWeightKg: w)
                        set.isDone = true; set.date = date; set.rir = 2; set.session = s
                        context.insert(set)
                    }
                }
            }
        }
    }
}
#endif

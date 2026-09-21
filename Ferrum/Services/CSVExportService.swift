import Foundation
import SwiftData
import TrainingLogic

enum CSVExportService {
    static func export(user: User) -> String {
        var lines: [String] = []
        lines.append("type,date,week,block,exercise,setIndex,isWarmup,targetReps,targetWeightKg,targetRPE,reps,weightKg,rpe,sleep,energy,motivation,soreness,stress,score")

        let days = user.programs
            .flatMap(\.weeks)
            .flatMap(\.days)
            .sorted { $0.scheduledDate < $1.scheduledDate }

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        for day in days {
            let weekNumber = day.week.map { String($0.weekNumber) } ?? ""
            let block = day.week?.block.rawValue ?? ""
            for exercise in day.orderedExercises {
                for set in exercise.orderedSets {
                    let date = formatter.string(from: set.completedAt ?? day.scheduledDate)
                    let reps = set.actualReps.map(String.init) ?? ""
                    let weight = set.actualWeightKg.map { String(format: "%.2f", $0) } ?? ""
                    let rpe = set.actualRPE.map { String(format: "%.1f", $0) } ?? ""
                    lines.append(
                        "workout,\(date),\(weekNumber),\(block),\(csv(exercise.name)),\(set.setIndex + 1),\(set.isWarmup ? "1" : "0"),\(set.targetReps),\(String(format: "%.2f", set.targetWeightKg)),\(String(format: "%.1f", set.targetRPE)),\(reps),\(weight),\(rpe),,,,,,"
                    )
                }
            }
        }

        for checkIn in user.checkIns.sorted(by: { $0.date < $1.date }) {
            let date = formatter.string(from: checkIn.date)
            lines.append(
                "readiness,\(date),,,,,,,,,,,\(checkIn.sleep),\(checkIn.energy),\(checkIn.motivation),\(checkIn.soreness),\(checkIn.stress),\(String(format: "%.1f", checkIn.score))"
            )
        }

        return lines.joined(separator: "\n")
    }

    private static func csv(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

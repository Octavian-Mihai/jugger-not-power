import Foundation

/// A plain-JSON program format that the Ferrum website writes and the app imports.
///
/// ```json
/// { "format": "ferrum-program", "version": 1, "name": "My Program",
///   "blocks": [ { "name": "Block 1", "phase": "strength", "weeks": 4, "deloadLastWeek": true,
///                 "rirShiftStart": 0, "rirShiftEnd": -1, "percentStep": 0.025,
///                 "days": [ { "name": "Squat day", "exercises": [
///                    { "exercise": "back-squat", "rest": 180, "note": "", "reference": "squat",
///                      "sets": [ { "count": 4, "type": "percent", "pct": 0.75, "reps": 5 } ] } ] } ] } ] }
/// ```
/// Set types: `percent` (pct, reps), `rir` (reps, rir), `range` (low, high, rir), `fixed` (weight in kg, reps).
public enum ProgramInterchange {
    public static let formatName = "ferrum-program"
    public static let version = 1

    public struct ImportError: Error, LocalizedError, Equatable {
        public let problems: [String]
        public var errorDescription: String? { problems.joined(separator: "\n") }
    }

    struct File: Codable {
        var format: String
        var version: Int
        var name: String
        var blocks: [FBlock]
    }
    struct FBlock: Codable {
        var name: String
        var phase: String?
        var weeks: Int
        var deloadLastWeek: Bool?
        var rirShiftStart: Double?
        var rirShiftEnd: Double?
        var percentStep: Double?
        var days: [FDay]
    }
    struct FDay: Codable { var name: String; var exercises: [FExercise] }
    struct FExercise: Codable {
        var exercise: String
        var rest: Int?
        var note: String?
        var reference: String?
        var sets: [FSet]
    }
    struct FSet: Codable {
        var count: Int
        var type: String
        var pct: Double?
        var reps: Int?
        var rir: Double?
        var low: Int?
        var high: Int?
        var weight: Double?
    }

    // MARK: Export

    public static func export(_ plan: ProgramPlan) throws -> Data {
        let file = File(format: formatName, version: version, name: plan.name, blocks: plan.blocks.map { b in
            FBlock(name: b.name, phase: b.phase.rawValue, weeks: b.weeks, deloadLastWeek: b.deloadLastWeek,
                   rirShiftStart: b.rirShiftStart, rirShiftEnd: b.rirShiftEnd, percentStep: b.percentStep,
                   days: b.days.map { d in
                FDay(name: d.name, exercises: d.exercises.map { e in
                    FExercise(exercise: e.exerciseID, rest: e.restSeconds, note: e.note, reference: e.reference?.rawValue,
                              sets: e.groups.map { g in
                        switch g.target {
                        case .percent(let p, let r): return FSet(count: g.count, type: "percent", pct: p, reps: r)
                        case .rir(let r, let rir): return FSet(count: g.count, type: "rir", reps: r, rir: rir)
                        case .repRange(let lo, let hi, let rir): return FSet(count: g.count, type: "range", rir: rir, low: lo, high: hi)
                        case .fixed(let w, let r): return FSet(count: g.count, type: "fixed", reps: r, weight: w)
                        }
                    })
                })
            })
        })
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(file)
    }

    // MARK: Import

    /// Decode and validate. Throws `ImportError` listing every problem found.
    public static func importPlan(_ data: Data, library: ExerciseLibrary) throws -> ProgramPlan {
        let file: File
        do { file = try JSONDecoder().decode(File.self, from: data) }
        catch { throw ImportError(problems: ["This isn't a valid Ferrum program file (\(describe(error)))."]) }

        var problems: [String] = []
        if file.format != formatName { problems.append("Unknown format \"\(file.format)\". Expected \"\(formatName)\".") }
        if file.version > version { problems.append("This file was made with a newer version (\(file.version)). Update Ferrum to import it.") }
        let name = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { problems.append("The program needs a name.") }
        if file.blocks.isEmpty { problems.append("The program has no blocks.") }

        var blocks: [Block] = []
        for (bi, fb) in file.blocks.enumerated() {
            let bl = "Block \(bi + 1)"
            if !(1...52).contains(fb.weeks) { problems.append("\(bl): weeks must be between 1 and 52.") }
            if fb.days.isEmpty { problems.append("\(bl): add at least one day.") }
            let phase = fb.phase.flatMap(PhaseKind.init(rawValue:)) ?? .general
            var days: [PlannedDay] = []
            for (di, fd) in fb.days.enumerated() {
                let dl = "\(bl), day \(di + 1)"
                if fd.exercises.isEmpty { problems.append("\(dl): add at least one exercise.") }
                var exercises: [PlannedExercise] = []
                for (ei, fe) in fd.exercises.enumerated() {
                    let el = "\(dl), exercise \(ei + 1)"
                    if library.exercise(fe.exercise) == nil { problems.append("\(el): unknown exercise \"\(fe.exercise)\".") }
                    if fe.sets.isEmpty { problems.append("\(el): add at least one set group.") }
                    var groups: [SetGroup] = []
                    for fs in fe.sets {
                        guard (1...20).contains(fs.count) else { problems.append("\(el): set count must be 1-20."); continue }
                        switch fs.type {
                        case "percent":
                            if let p = fs.pct, let r = fs.reps, (0.2...1.2).contains(p), (1...50).contains(r) {
                                groups.append(SetGroup(count: fs.count, target: .percent(pct: p, reps: r)))
                            } else { problems.append("\(el): percent sets need pct (0.2-1.2) and reps (1-50).") }
                        case "rir":
                            if let r = fs.reps, let rir = fs.rir, (1...50).contains(r), (0...10).contains(rir) {
                                groups.append(SetGroup(count: fs.count, target: .rir(reps: r, rir: rir)))
                            } else { problems.append("\(el): RIR sets need reps (1-50) and rir (0-10).") }
                        case "range":
                            if let lo = fs.low, let hi = fs.high, let rir = fs.rir, lo >= 1, hi >= lo, hi <= 100, (0...10).contains(rir) {
                                groups.append(SetGroup(count: fs.count, target: .repRange(low: lo, high: hi, rir: rir)))
                            } else { problems.append("\(el): range sets need low <= high and rir (0-10).") }
                        case "fixed":
                            if let w = fs.weight, let r = fs.reps, w >= 0, (1...50).contains(r) {
                                groups.append(SetGroup(count: fs.count, target: .fixed(weight: w, reps: r)))
                            } else { problems.append("\(el): fixed sets need weight and reps.") }
                        default: problems.append("\(el): unknown set type \"\(fs.type)\".")
                        }
                    }
                    var reference: MainLift?
                    if let r = fe.reference, !r.isEmpty {
                        reference = MainLift(rawValue: r)
                        if reference == nil { problems.append("\(el): reference must be squat, bench or deadlift.") }
                    }
                    exercises.append(PlannedExercise(exerciseID: fe.exercise, groups: groups,
                                                     restSeconds: min(max(fe.rest ?? 120, 0), 900),
                                                     note: fe.note ?? "", reference: reference))
                }
                days.append(PlannedDay(name: fd.name.isEmpty ? "Day \(di + 1)" : fd.name, exercises: exercises))
            }
            blocks.append(Block(name: fb.name.isEmpty ? bl : fb.name, phase: phase, weeks: min(max(fb.weeks, 1), 52), days: days,
                                rirShiftStart: fb.rirShiftStart ?? 0, rirShiftEnd: fb.rirShiftEnd ?? 0,
                                percentStep: fb.percentStep ?? 0, deloadLastWeek: fb.deloadLastWeek ?? false))
        }
        if !problems.isEmpty { throw ImportError(problems: Array(problems.prefix(12))) }
        return ProgramPlan(name: name, goal: nil, blocks: blocks)
    }

    private static func describe(_ error: Error) -> String {
        if let e = error as? DecodingError {
            switch e {
            case .keyNotFound(let k, _): return "missing \"\(k.stringValue)\""
            case .typeMismatch(_, let c), .valueNotFound(_, let c): return "bad value at \(c.codingPath.map(\.stringValue).joined(separator: "."))"
            case .dataCorrupted: return "not valid JSON"
            @unknown default: return "unreadable"
            }
        }
        return "unreadable"
    }
}

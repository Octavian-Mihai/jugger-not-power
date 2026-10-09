import Foundation
import SwiftUI
import SwiftData
import UIKit
import FerrumCore

/// Holds the bundled exercise library (plus the user's custom exercises) and unit helpers.
@Observable
final class Store {
    private(set) var library: ExerciseLibrary
    private let base: ExerciseLibrary
    var unit: WeightUnit = .kg

    init() {
        func data(_ name: String) -> Data {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let d = try? Data(contentsOf: url) else { fatalError("Missing \(name).json") }
            return d
        }
        let lib = (try? ExerciseLibrary.load(exercisesJSON: data("exercises"), musclesJSON: data("muscles"), rirJSON: data("rir")))
            ?? ExerciseLibrary(exercises: [])
        base = lib; library = lib
    }

    func refreshCustom(_ custom: [CustomExercise]) {
        library = ExerciseLibrary(exercises: base.exercises + custom.map(\.info), muscles: base.muscles, rirGuide: base.rirGuide)
    }

    // MARK: weights (stored kg)
    func display(_ kg: Double) -> Double { WeightUnit.kg.convert(kg, to: unit) }
    func toKg(_ shown: Double) -> Double { unit.convert(shown, to: .kg) }
    func format(_ kg: Double, withUnit: Bool = true) -> String {
        let v = display(kg)
        let s = v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
        return withUnit ? "\(s) \(unit.label)" : s
    }

    func loadContext(profile: Profile, sets: [LoggedSet]) -> LoadContext {
        var maxes: [MainLift: Double] = [:]
        for l in MainLift.allCases where profile.oneRepMaxKg(l) > 0 { maxes[l] = display(profile.oneRepMaxKg(l)) }
        // Most recent finished session's done sets per exercise
        var last: [String: (Date, [(weight: Double, reps: Int, rir: Double)])] = [:]
        let grouped = Dictionary(grouping: sets.filter { $0.isDone && $0.session?.isFinished == true }) { $0.exerciseID }
        for (id, group) in grouped {
            guard let newest = group.max(by: { $0.date < $1.date })?.session else { continue }
            let rows = group.filter { $0.session === newest }.map { (weight: display($0.weightKg), reps: $0.reps, rir: $0.rir) }
            last[id] = (newest.date, rows)
        }
        return LoadContext(unit: unit, oneRepMax: maxes, lastPerformance: last.mapValues { LastPerformance(sets: $0.1) })
    }
}

enum ImageStore {
    private static let cache = NSCache<NSString, UIImage>()
    static func image(_ file: String?, maxDimension: CGFloat = 700) -> UIImage? {
        guard let file else { return nil }
        if let hit = cache.object(forKey: file as NSString) { return hit }
        let ns = file as NSString
        guard let path = Bundle.main.path(forResource: ns.deletingPathExtension, ofType: ns.pathExtension),
              let img = UIImage(contentsOfFile: path) else { return nil }
        let scale = min(1, maxDimension / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let thumb = img.preparingThumbnail(of: size) ?? img
        cache.setObject(thumb, forKey: file as NSString)
        return thumb
    }
}

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
}

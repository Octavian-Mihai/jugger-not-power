import Foundation

public struct ReadinessInput: Codable, Hashable, Sendable {
    /// Each 1 (worst) ... 5 (best); soreness is 1 (none) ... 5 (very sore).
    public var sleep: Int
    public var energy: Int
    public var mood: Int
    public var soreness: Int
    public init(sleep: Int = 3, energy: Int = 3, mood: Int = 3, soreness: Int = 2) {
        self.sleep = sleep; self.energy = energy; self.mood = mood; self.soreness = soreness
    }
}

public enum ReadinessBand: String, Codable, Sendable {
    case great, good, moderate, low
    public var title: String {
        switch self {
        case .great: return "Primed"
        case .good: return "Ready"
        case .moderate: return "Reduced"
        case .low: return "Recover"
        }
    }
}

public struct ReadinessAdjustment: Codable, Hashable, Sendable {
    public var score: Int
    public var band: ReadinessBand
    public var loadMultiplier: Double
    public var setDelta: Int
    public var rirOffset: Double
    public var summary: String

    public static let neutral = ReadinessAdjustment(score: 75, band: .good, loadMultiplier: 1, setDelta: 0,
                                                    rirOffset: 0, summary: "Train as planned.")
}

public enum Readiness {
    public static func score(_ i: ReadinessInput) -> Int {
        func norm(_ v: Int) -> Double { (Double(min(max(v, 1), 5)) - 1) / 4 }
        let s = norm(i.sleep) * 0.30 + norm(i.energy) * 0.30 + norm(i.mood) * 0.15 + (1 - norm(i.soreness)) * 0.25
        return Int((s * 100).rounded())
    }

    public static func adjustment(for input: ReadinessInput) -> ReadinessAdjustment {
        let score = score(input)
        switch score {
        case 75...:
            return .init(score: score, band: .great, loadMultiplier: 1, setDelta: 0, rirOffset: 0,
                         summary: "You're primed. Train as planned and push the top sets.")
        case 55..<75:
            return .init(score: score, band: .good, loadMultiplier: 1, setDelta: 0, rirOffset: 0,
                         summary: "Solid. Train as planned.")
        case 35..<55:
            return .init(score: score, band: .moderate, loadMultiplier: 0.95, setDelta: -1, rirOffset: 1,
                         summary: "A bit run down. Loads trimmed 5%, one fewer set, and an extra rep in reserve.")
        default:
            return .init(score: score, band: .low, loadMultiplier: 0.90, setDelta: -1, rirOffset: 2,
                         summary: "Recovery is low. Loads cut 10%, fewer sets, and stay well short of failure.")
        }
    }
}

import Foundation

public struct Landmark: Equatable, Sendable {
    public var mev: Int
    public var mav: Int
    public var mrv: Int

    public init(mev: Int, mav: Int, mrv: Int) {
        self.mev = mev
        self.mav = mav
        self.mrv = mrv
    }
}

public enum VolumeLandmarks {
    public static let floorMuscles: [MuscleGroup] = [.upperBack, .lats, .rearDelts, .hamstrings, .core]

    public static func base(for muscle: MuscleGroup) -> Landmark {
        switch muscle {
        case .chest: return Landmark(mev: 8, mav: 12, mrv: 18)
        case .frontDelts: return Landmark(mev: 6, mav: 8, mrv: 14)
        case .sideDelts: return Landmark(mev: 8, mav: 16, mrv: 22)
        case .rearDelts: return Landmark(mev: 8, mav: 12, mrv: 18)
        case .upperBack: return Landmark(mev: 8, mav: 14, mrv: 20)
        case .lats: return Landmark(mev: 8, mav: 14, mrv: 20)
        case .biceps: return Landmark(mev: 6, mav: 14, mrv: 20)
        case .triceps: return Landmark(mev: 6, mav: 12, mrv: 18)
        case .quads: return Landmark(mev: 8, mav: 14, mrv: 20)
        case .hamstrings: return Landmark(mev: 6, mav: 10, mrv: 16)
        case .glutes: return Landmark(mev: 4, mav: 8, mrv: 16)
        case .calves: return Landmark(mev: 6, mav: 12, mrv: 16)
        case .core: return Landmark(mev: 4, mav: 8, mrv: 16)
        }
    }

    public static func scaled(for muscle: MuscleGroup, profile: AthleteProfile) -> Landmark {
        var landmark = base(for: muscle)
        applyExperience(&landmark, profile.experienceLevel)
        applyMode(&landmark, muscle: muscle, mode: profile.trainingMode)
        applyBodyweight(&landmark, bodyweightKg: profile.bodyweightKg)
        landmark.mev = max(VolumeLandmarks.floorMuscles.contains(muscle) ? 1 : 0, landmark.mev)
        landmark.mav = max(landmark.mev, landmark.mav)
        landmark.mrv = max(landmark.mav, landmark.mrv)
        return landmark
    }

    public static func targetSets(for muscle: MuscleGroup, profile: AthleteProfile, weekNumber: Int) -> Int {
        let landmark = scaled(for: muscle, profile: profile)
        let progress = weeklyVolumeProgress(weekNumber: weekNumber, mode: profile.trainingMode)
        let raw = Double(landmark.mev) + (Double(landmark.mav - landmark.mev) * progress)
        return max(landmark.mev, Int(raw.rounded()))
    }

    /// 0 at MEV, 1 at MAV. Hypertrophy ramps, strength holds near MAV, peaking tapers toward MEV.
    public static func weeklyVolumeProgress(weekNumber: Int, mode: TrainingMode) -> Double {
        if mode == .bodybuilding && weekNumber >= 9 {
            switch weekNumber {
            case 9: return 0.85
            case 10: return 0.75
            case 11: return 0.65
            default: return 0.55
            }
        }
        switch weekNumber {
        case 1: return 0.00
        case 2: return 0.35
        case 3: return 0.70
        case 4: return 1.00
        case 5: return 0.95
        case 6: return 1.00
        case 7: return 0.90
        case 8: return 0.80
        case 9: return 0.50
        case 10: return 0.35
        case 11: return 0.20
        default: return 0.05
        }
    }

    private static func applyExperience(_ landmark: inout Landmark, _ experience: ExperienceLevel) {
        switch experience {
        case .novice:
            let span = landmark.mav - landmark.mev
            landmark.mav = landmark.mev + Int((Double(span) * 0.40).rounded())
            landmark.mrv = max(landmark.mav, landmark.mev + Int((Double(span) * 0.70).rounded()))
        case .intermediate:
            break
        case .advanced:
            let up = landmark.mrv - landmark.mav
            landmark.mev = landmark.mev + Int((Double(landmark.mav - landmark.mev) * 0.25).rounded())
            landmark.mav = landmark.mav + Int((Double(up) * 0.45).rounded())
        }
    }

    private static func applyMode(_ landmark: inout Landmark, muscle: MuscleGroup, mode: TrainingMode) {
        let isolation: Set<MuscleGroup> = [.sideDelts, .biceps, .calves, .rearDelts]
        let compounds: Set<MuscleGroup> = [.quads, .chest, .hamstrings, .glutes, .upperBack, .lats]
        let factor: Double
        switch mode {
        case .powerlifting:
            if isolation.contains(muscle) { factor = 0.80 }
            else if compounds.contains(muscle) { factor = 1.10 }
            else { factor = 1.0 }
        case .bodybuilding:
            if isolation.contains(muscle) { factor = 1.15 }
            else { factor = 0.95 }
        case .powerbuilding:
            factor = 1.0
        case .hybrid:
            if isolation.contains(muscle) { factor = 1.05 }
            else if compounds.contains(muscle) { factor = 1.05 }
            else { factor = 1.0 }
        }
        landmark.mev = max(1, Int((Double(landmark.mev) * factor).rounded()))
        landmark.mav = max(landmark.mev, Int((Double(landmark.mav) * factor).rounded()))
        landmark.mrv = max(landmark.mav, Int((Double(landmark.mrv) * factor).rounded()))
    }

    private static func applyBodyweight(_ landmark: inout Landmark, bodyweightKg: Double) {
        let factor = max(0.85, 1.0 - max(0, bodyweightKg - 80.0) * 0.002)
        landmark.mev = max(1, Int((Double(landmark.mev) * factor).rounded()))
        landmark.mav = max(landmark.mev, Int((Double(landmark.mav) * factor).rounded()))
        landmark.mrv = max(landmark.mav, Int((Double(landmark.mrv) * factor).rounded()))
    }
}

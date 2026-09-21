import Foundation
import TrainingLogic

enum UnitConverter {
    static let poundsPerKilogram = 2.2046226218

    static func kilograms(fromDisplay value: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kilogram: return value
        case .pound: return value / poundsPerKilogram
        }
    }

    static func display(fromKilograms kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kilogram: return kg
        case .pound: return kg * poundsPerKilogram
        }
    }

    static func formatted(_ kg: Double, unit: WeightUnit) -> String {
        let value = display(fromKilograms: kg, unit: unit)
        let suffix = unit == .kilogram ? "kg" : "lb"
        if unit == .pound {
            return String(format: "%.0f %@", value.rounded(), suffix)
        }
        if value == value.rounded() {
            return String(format: "%.0f %@", value, suffix)
        }
        return String(format: "%.1f %@", value, suffix)
    }

    static func compact(_ kg: Double, unit: WeightUnit) -> String {
        let value = display(fromKilograms: kg, unit: unit)
        if unit == .pound {
            return String(format: "%.0f", value.rounded())
        }
        if abs(value - value.rounded()) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

enum FerrumDates {
    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}

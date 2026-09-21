import Foundation

public enum ProgramEngine {
    public static func generate(profile: AthleteProfile) -> [TrainingWeek] {
        generateProgram(profile: profile).weeks
    }

    public static func generateProgram(profile: AthleteProfile, durationWeeks: Int = Periodization.defaultDurationWeeks) -> GeneratedProgram {
        let templates = dayTemplates(for: profile.trainingMode)
        let offsets = trainingDayOffsets(count: templates.count)
        let weeks: [TrainingWeek] = (1...durationWeeks).map { weekNumber in
            let block = Periodization.block(forWeek: weekNumber)
            var days: [PlannedWorkout] = (0..<7).map { PlannedWorkout.rest(dayIndex: $0) }
            for (templateIndex, offset) in offsets.enumerated() {
                days[offset] = buildDay(
                    template: templates[templateIndex],
                    dayIndex: offset,
                    weekNumber: weekNumber,
                    block: block,
                    profile: profile
                )
            }
            let raw = TrainingWeek(weekNumber: weekNumber, block: block, days: days)
            return VolumeBalancer.rebalance(raw, profile: profile)
        }
        return GeneratedProgram(mode: profile.trainingMode, durationWeeks: durationWeeks, weeks: weeks)
    }

    /// Spread training sessions through the week instead of stacking them on consecutive calendar days.
    public static func trainingDayOffsets(count: Int) -> [Int] {
        switch count {
        case 3: return [0, 2, 4]
        case 4: return [0, 2, 4, 5]
        case 5: return [0, 1, 3, 4, 5]
        case 6: return [0, 1, 2, 4, 5, 6]
        default: return Array(0..<min(count, 7))
        }
    }

    private struct Slot {
        var catalogID: String
        var role: ExerciseRole
    }

    private struct DayTemplate {
        var title: String
        var slots: [Slot]
    }

    private static func dayTemplates(for mode: TrainingMode) -> [DayTemplate] {
        switch mode {
        case .powerlifting:
            return [
                DayTemplate(title: "Squat", slots: [
                    Slot(catalogID: "back_squat", role: .main),
                    Slot(catalogID: "pause_squat", role: .secondary),
                    Slot(catalogID: "romanian_deadlift", role: .secondary),
                    Slot(catalogID: "lying_leg_curl", role: .accessory),
                    Slot(catalogID: "hanging_leg_raise", role: .accessory)
                ]),
                DayTemplate(title: "Bench", slots: [
                    Slot(catalogID: "barbell_bench_press", role: .main),
                    Slot(catalogID: "incline_dumbbell_press", role: .secondary),
                    Slot(catalogID: "close_grip_bench", role: .secondary),
                    Slot(catalogID: "tricep_pushdown", role: .accessory),
                    Slot(catalogID: "face_pull", role: .accessory),
                    Slot(catalogID: "rear_delt_fly", role: .accessory)
                ]),
                DayTemplate(title: "Deadlift", slots: [
                    Slot(catalogID: "conventional_deadlift", role: .main),
                    Slot(catalogID: "barbell_row", role: .secondary),
                    Slot(catalogID: "lat_pulldown", role: .secondary),
                    Slot(catalogID: "seated_cable_row", role: .accessory),
                    Slot(catalogID: "hanging_leg_raise", role: .accessory)
                ]),
                DayTemplate(title: "Press + Back", slots: [
                    Slot(catalogID: "overhead_press", role: .main),
                    Slot(catalogID: "pull_up", role: .secondary),
                    Slot(catalogID: "chest_supported_row", role: .secondary),
                    Slot(catalogID: "face_pull", role: .accessory),
                    Slot(catalogID: "lateral_raise", role: .accessory),
                    Slot(catalogID: "barbell_curl", role: .accessory),
                    Slot(catalogID: "plank", role: .accessory)
                ])
            ]
        case .powerbuilding:
            return [
                DayTemplate(title: "Upper A", slots: [
                    Slot(catalogID: "barbell_bench_press", role: .main),
                    Slot(catalogID: "barbell_row", role: .main),
                    Slot(catalogID: "overhead_press", role: .secondary),
                    Slot(catalogID: "lat_pulldown", role: .secondary),
                    Slot(catalogID: "lateral_raise", role: .accessory),
                    Slot(catalogID: "face_pull", role: .accessory),
                    Slot(catalogID: "tricep_pushdown", role: .accessory),
                    Slot(catalogID: "barbell_curl", role: .accessory)
                ]),
                DayTemplate(title: "Lower A", slots: [
                    Slot(catalogID: "back_squat", role: .main),
                    Slot(catalogID: "romanian_deadlift", role: .main),
                    Slot(catalogID: "leg_press", role: .secondary),
                    Slot(catalogID: "lying_leg_curl", role: .accessory),
                    Slot(catalogID: "standing_calf_raise", role: .accessory),
                    Slot(catalogID: "hanging_leg_raise", role: .accessory)
                ]),
                DayTemplate(title: "Upper B", slots: [
                    Slot(catalogID: "incline_dumbbell_press", role: .main),
                    Slot(catalogID: "pull_up", role: .main),
                    Slot(catalogID: "dips", role: .secondary),
                    Slot(catalogID: "chest_supported_row", role: .secondary),
                    Slot(catalogID: "rear_delt_fly", role: .accessory),
                    Slot(catalogID: "skull_crusher", role: .accessory),
                    Slot(catalogID: "hammer_curl", role: .accessory)
                ]),
                DayTemplate(title: "Lower B", slots: [
                    Slot(catalogID: "conventional_deadlift", role: .main),
                    Slot(catalogID: "front_squat", role: .secondary),
                    Slot(catalogID: "walking_lunge", role: .secondary),
                    Slot(catalogID: "seated_leg_curl", role: .accessory),
                    Slot(catalogID: "seated_calf_raise", role: .accessory),
                    Slot(catalogID: "ab_wheel", role: .accessory)
                ])
            ]
        case .bodybuilding:
            return [
                DayTemplate(title: "Push A", slots: [
                    Slot(catalogID: "barbell_bench_press", role: .main),
                    Slot(catalogID: "incline_dumbbell_press", role: .secondary),
                    Slot(catalogID: "seated_dumbbell_press", role: .secondary),
                    Slot(catalogID: "cable_fly", role: .accessory),
                    Slot(catalogID: "lateral_raise", role: .accessory),
                    Slot(catalogID: "tricep_pushdown", role: .accessory),
                    Slot(catalogID: "overhead_tricep_extension", role: .accessory)
                ]),
                DayTemplate(title: "Pull A", slots: [
                    Slot(catalogID: "barbell_row", role: .main),
                    Slot(catalogID: "lat_pulldown", role: .secondary),
                    Slot(catalogID: "seated_cable_row", role: .secondary),
                    Slot(catalogID: "face_pull", role: .accessory),
                    Slot(catalogID: "rear_delt_fly", role: .accessory),
                    Slot(catalogID: "barbell_curl", role: .accessory),
                    Slot(catalogID: "hammer_curl", role: .accessory)
                ]),
                DayTemplate(title: "Legs", slots: [
                    Slot(catalogID: "back_squat", role: .main),
                    Slot(catalogID: "romanian_deadlift", role: .main),
                    Slot(catalogID: "leg_press", role: .secondary),
                    Slot(catalogID: "lying_leg_curl", role: .accessory),
                    Slot(catalogID: "walking_lunge", role: .accessory),
                    Slot(catalogID: "standing_calf_raise", role: .accessory),
                    Slot(catalogID: "hanging_leg_raise", role: .accessory)
                ]),
                DayTemplate(title: "Push B", slots: [
                    Slot(catalogID: "overhead_press", role: .main),
                    Slot(catalogID: "incline_barbell_press", role: .secondary),
                    Slot(catalogID: "dips", role: .secondary),
                    Slot(catalogID: "cable_lateral_raise", role: .accessory),
                    Slot(catalogID: "pec_deck", role: .accessory),
                    Slot(catalogID: "skull_crusher", role: .accessory)
                ]),
                DayTemplate(title: "Pull B", slots: [
                    Slot(catalogID: "conventional_deadlift", role: .secondary),
                    Slot(catalogID: "pull_up", role: .main),
                    Slot(catalogID: "chest_supported_row", role: .secondary),
                    Slot(catalogID: "reverse_pec_deck", role: .accessory),
                    Slot(catalogID: "face_pull", role: .accessory),
                    Slot(catalogID: "preacher_curl", role: .accessory),
                    Slot(catalogID: "cable_crunch", role: .accessory)
                ])
            ]
        case .hybrid:
            return [
                DayTemplate(title: "Upper Strength", slots: [
                    Slot(catalogID: "barbell_bench_press", role: .main),
                    Slot(catalogID: "barbell_row", role: .main),
                    Slot(catalogID: "overhead_press", role: .secondary),
                    Slot(catalogID: "close_grip_bench", role: .accessory),
                    Slot(catalogID: "face_pull", role: .accessory),
                    Slot(catalogID: "plank", role: .accessory)
                ]),
                DayTemplate(title: "Lower Hypertrophy", slots: [
                    Slot(catalogID: "back_squat", role: .main),
                    Slot(catalogID: "romanian_deadlift", role: .secondary),
                    Slot(catalogID: "leg_press", role: .secondary),
                    Slot(catalogID: "walking_lunge", role: .accessory),
                    Slot(catalogID: "lying_leg_curl", role: .accessory),
                    Slot(catalogID: "standing_calf_raise", role: .accessory),
                    Slot(catalogID: "hanging_leg_raise", role: .accessory)
                ]),
                DayTemplate(title: "Upper Hypertrophy", slots: [
                    Slot(catalogID: "incline_dumbbell_press", role: .main),
                    Slot(catalogID: "pull_up", role: .main),
                    Slot(catalogID: "chest_supported_row", role: .secondary),
                    Slot(catalogID: "lateral_raise", role: .accessory),
                    Slot(catalogID: "rear_delt_fly", role: .accessory),
                    Slot(catalogID: "tricep_pushdown", role: .accessory),
                    Slot(catalogID: "hammer_curl", role: .accessory)
                ]),
                DayTemplate(title: "Lower Strength", slots: [
                    Slot(catalogID: "conventional_deadlift", role: .main),
                    Slot(catalogID: "front_squat", role: .secondary),
                    Slot(catalogID: "bulgarian_split_squat", role: .accessory),
                    Slot(catalogID: "seated_leg_curl", role: .accessory),
                    Slot(catalogID: "seated_calf_raise", role: .accessory),
                    Slot(catalogID: "ab_wheel", role: .accessory)
                ])
            ]
        }
    }

    private static func buildDay(
        template: DayTemplate,
        dayIndex: Int,
        weekNumber: Int,
        block: TrainingBlock,
        profile: AthleteProfile
    ) -> PlannedWorkout {
        let exercises = template.slots.map { slot in
            buildExercise(slot: slot, weekNumber: weekNumber, block: block, profile: profile)
        }
        return PlannedWorkout(dayIndex: dayIndex, title: template.title, exercises: exercises, isRestDay: false)
    }

    private static func buildExercise(
        slot: Slot,
        weekNumber: Int,
        block: TrainingBlock,
        profile: AthleteProfile
    ) -> PlannedExercise {
        let definition = ExerciseLibrary.require(slot.catalogID)
        let scheme = LoadPrescription.scheme(role: slot.role, block: block, mode: profile.trainingMode)
        let setCount = LoadPrescription.setCount(role: slot.role, weekNumber: weekNumber, block: block, mode: profile.trainingMode)
        var sets: [PlannedSet] = []
        if slot.role == .main {
            sets.append(contentsOf: warmupSets(for: definition, scheme: scheme, profile: profile))
        }
        sets.append(contentsOf: workingSets(count: setCount, scheme: scheme, definition: definition, profile: profile))
        return PlannedExercise(
            catalogID: definition.id,
            name: definition.name,
            movementPattern: definition.movementPattern,
            primaryMuscles: definition.primaryMuscles,
            role: slot.role,
            sets: sets
        )
    }

    private static func warmupSets(
        for definition: ExerciseDefinition,
        scheme: LoadPrescription.Scheme,
        profile: AthleteProfile
    ) -> [PlannedSet] {
        if definition.isBodyweight && definition.loadFraction == 0 {
            return []
        }
        let ramps: [(fraction: Double, reps: Int, rpe: Double)] = [
            (0.40, 8, 5.0),
            (0.60, 5, 5.0),
            (0.80, 3, 6.0)
        ]
        return ramps.map { ramp in
            let percent = scheme.percent1RM * ramp.fraction
            return PlannedSet(
                targetReps: ramp.reps,
                targetWeightKg: OneRepMax.workingLoadKg(for: definition, profile: profile, percent1RM: percent),
                targetRPE: ramp.rpe,
                percent1RM: percent,
                isWarmup: true
            )
        }
    }

    private static func workingSets(
        count: Int,
        scheme: LoadPrescription.Scheme,
        definition: ExerciseDefinition,
        profile: AthleteProfile
    ) -> [PlannedSet] {
        (0..<count).map { index in
            let percent = index == 0 ? scheme.percent1RM : scheme.percent1RM * 0.90
            return PlannedSet(
                targetReps: scheme.reps,
                targetWeightKg: OneRepMax.workingLoadKg(for: definition, profile: profile, percent1RM: percent),
                targetRPE: index == 0 ? scheme.rpe : max(6.0, scheme.rpe - 0.5),
                percent1RM: percent,
                isWarmup: false
            )
        }
    }
}

import Foundation

// Shapes of the bundled fixture files. These are storage formats for the fake
// back-end only; screens never see them. The repository resolves them into the
// API models (`WorkoutSession`, `WeekSchedule`, ...).

struct ProgramFixture: Codable {
    struct Block: Codable {
        var blockNumber: Int
        var startDate: LocalDate
        var weeksInBlock: Int
        var phase: String
    }

    struct ProteinTarget: Codable {
        var min: Int
        var max: Int
    }

    /// The fixture's "today". Fixture data is anchored to this date.
    var today: LocalDate
    var block: Block
    /// First week the schedule can show.
    var firstWeek: LocalDate
    /// How many weeks past the current one the schedule can show.
    var weeksAhead: Int
    var weekTemplate: [SessionTemplate]
    var defaultTrainingDays: [Weekday]
    var proteinTarget: ProteinTarget
}

struct PlannedExerciseDefinition: Codable {
    var id: String
    /// Id of an exercise in `exercises.json`.
    var exercise: String
    var prescription: Prescription
    var progression: ProgressionHint?
    var history: ExerciseHistory?
    var setup: [EquipmentSetup]?
    var sideNote: String?
}

struct ExerciseGroupDefinition: Codable {
    var id: String
    var title: String
    var format: GroupFormat
    var estimatedMinutes: Int
    var isWarmup: Bool?
    var rounds: Int?
    var transitionSeconds: Int?
    var roundRestSeconds: Int?
    var items: [PlannedExerciseDefinition]
}

/// A session template; the repository stamps a date on it to make a session.
struct SessionDefinition: Codable {
    var id: String
    var kind: SessionKind
    var title: String
    var estimatedMinutes: Int
    var progressionNote: String?
    var equipment: [String]
    var groups: [ExerciseGroupDefinition]
}

struct HistoryEntry: Codable {
    var date: LocalDate
    var templateId: String
    var status: SessionStatus
    var actualMinutes: Int?
}

struct ProgressFixture: Codable {
    struct Lift: Codable {
        var id: String
        var name: String
        var points: [LiftPoint]
    }

    var targetWeeklyGainMin: Double
    var targetWeeklyGainMax: Double
    var bodyweight: [BodyweightPoint]
    var lifts: [Lift]
    var volumeWindowWeeks: Int
    var volume: [VolumeEntry]
    var consistency: Consistency
}

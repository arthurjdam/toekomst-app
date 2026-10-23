import Foundation

// Models for planned training. These mirror the JSON the back-end is expected
// to return, so the fixtures in `Fixtures/` double as an API contract draft.

/// The three session types the program is built from.
public enum SessionKind: String, Codable, CaseIterable, Sendable {
    /// Full-body circuits: work capacity, a real sweat by the end.
    case conditioning
    /// Hypertrophy-focused straight sets for the upper body.
    case upperMass
    /// Hypertrophy-focused straight sets for the lower body.
    case lowerMass

    public var displayName: String {
        switch self {
        case .conditioning: return "Conditioning"
        case .upperMass: return "Upper mass"
        case .lowerMass: return "Lower mass"
        }
    }

    /// Two-letter code used in compact week strips.
    public var code: String {
        switch self {
        case .conditioning: return "CD"
        case .upperMass: return "UP"
        case .lowerMass: return "LO"
        }
    }
}

/// The major muscle groups weekly volume is tracked against.
public enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, quads, hamsGlutes, calves, arms, core

    public var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .quads: return "Quads"
        case .hamsGlutes: return "Hams/glutes"
        case .calves: return "Calves"
        case .arms: return "Arms"
        case .core: return "Core"
        }
    }

    /// Whether the display name takes a plural verb ("Calves are", "Core is").
    public var isPlural: Bool {
        switch self {
        case .shoulders, .quads, .hamsGlutes, .calves, .arms: return true
        case .chest, .back, .core: return false
        }
    }
}

/// How an exercise is loaded; drives plate maths and volume counting.
public enum LoadKind: String, Codable, Sendable {
    case barbell
    /// One dumbbell held in both hands (goblet squat).
    case dumbbell
    /// A dumbbell in each hand; the load is per hand.
    case dumbbellPair
    case kettlebell
    case machine
    case cable
    case bodyweight
    case cardio
}

/// Where a session sits in the program.
public struct BlockPosition: Codable, Hashable, Sendable {
    public var blockNumber: Int
    public var week: Int
    public var weeksInBlock: Int
    public var phase: String

    public init(blockNumber: Int, week: Int, weeksInBlock: Int, phase: String) {
        self.blockNumber = blockNumber
        self.week = week
        self.weeksInBlock = weeksInBlock
        self.phase = phase
    }
}

/// An exercise from the library, independent of how it is prescribed today.
public struct Exercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    /// A shorter name for tight spaces ("Romanian DL").
    public var shortName: String?
    /// Two-letter movement code shown in list thumbnails ("SQ", "HG").
    public var code: String
    public var loadKind: LoadKind
    /// Core lifts are the tracked compound lifts that stay fixed within a block.
    public var isCoreLift: Bool
    /// Primary muscles; each working set counts once for each of them.
    public var muscles: [MuscleGroup]
    public var cues: [String]
    /// Identifier of the demo media for this exercise; the app draws known
    /// figures and shows a placeholder for the rest.
    public var demo: String?
    /// Camera angles the demo media is available in ("side", "front").
    public var demoAngles: [String]?

    public init(
        id: String, name: String, shortName: String? = nil, code: String, loadKind: LoadKind,
        isCoreLift: Bool = false, muscles: [MuscleGroup], cues: [String] = [],
        demo: String? = nil, demoAngles: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.code = code
        self.loadKind = loadKind
        self.isCoreLift = isCoreLift
        self.muscles = muscles
        self.cues = cues
        self.demo = demo
        self.demoAngles = demoAngles
    }

    public var displayShortName: String { shortName ?? name }
}

/// A rep target: a range ("6-8"), a single number ("12"), optionally per side.
public struct RepTarget: Codable, Hashable, Sendable {
    public var min: Int
    public var max: Int
    public var perSide: Bool?

    public init(min: Int, max: Int, perSide: Bool = false) {
        self.min = min
        self.max = max
        self.perSide = perSide
    }

    public init(exactly reps: Int) {
        self.init(min: reps, max: reps)
    }

    public var isPerSide: Bool { perSide ?? false }

    /// "6-8", "12", "10-12/side".
    public var display: String {
        (min == max ? "\(min)" : "\(min)-\(max)") + (isPerSide ? "/side" : "")
    }

    /// "6-8" without the per-side suffix.
    public var rangeDisplay: String {
        min == max ? "\(min)" : "\(min)-\(max)"
    }
}

/// How a planned exercise should be performed.
public struct Prescription: Codable, Hashable, Sendable {
    public var sets: Int
    /// Rep target; nil for timed work.
    public var reps: RepTarget?
    /// Work duration for timed sets and circuit moves.
    public var durationSeconds: Int?
    /// Load in pounds; nil for bodyweight or unloaded work. Per hand for `dumbbellPair`.
    public var load: Double?
    /// Short qualifier shown after the target ("conversational pace").
    public var note: String?
    /// Rest after each set, for straight sets.
    public var restSeconds: Int?

    public init(
        sets: Int, reps: RepTarget? = nil, durationSeconds: Int? = nil,
        load: Double? = nil, note: String? = nil, restSeconds: Int? = nil
    ) {
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.load = load
        self.note = note
        self.restSeconds = restSeconds
    }

    public var isTimed: Bool { reps == nil && durationSeconds != nil }
}

/// Whether the load goes up, stays, or comes down compared to last time.
public enum ProgressionDirection: String, Codable, Sendable {
    case increase, same, hold, decrease
}

/// The back-end's progression decision for a planned exercise.
public struct ProgressionHint: Codable, Hashable, Sendable {
    public var direction: ProgressionDirection
    /// Load change in pounds compared to last session (positive for increases).
    public var loadChange: Double?
    /// One sentence on why ("8 reps on every set, two sessions running.").
    public var reason: String?

    public init(direction: ProgressionDirection, loadChange: Double? = nil, reason: String? = nil) {
        self.direction = direction
        self.loadChange = loadChange
        self.reason = reason
    }
}

/// What happened the last time this exercise was done, plus the best effort.
public struct ExerciseHistory: Codable, Hashable, Sendable {
    public var lastLoad: Double?
    public var lastReps: [Int]
    /// Best estimated one-rep max on record, for PR detection.
    public var bestEstimatedMax: Double?

    public init(lastLoad: Double?, lastReps: [Int], bestEstimatedMax: Double? = nil) {
        self.lastLoad = lastLoad
        self.lastReps = lastReps
        self.bestEstimatedMax = bestEstimatedMax
    }
}

/// Equipment to grab before an exercise, and where it is.
public struct EquipmentSetup: Codable, Hashable, Sendable {
    public var item: String
    public var location: String?

    public init(item: String, location: String? = nil) {
        self.item = item
        self.location = location
    }
}

/// One exercise as prescribed in a session.
public struct PlannedExercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var exercise: Exercise
    public var prescription: Prescription
    public var progression: ProgressionHint?
    public var history: ExerciseHistory?
    public var setup: [EquipmentSetup]?
    /// A note shown on the up-next card ("Left side first").
    public var sideNote: String?

    public init(
        id: String, exercise: Exercise, prescription: Prescription, progression: ProgressionHint? = nil,
        history: ExerciseHistory? = nil, setup: [EquipmentSetup]? = nil, sideNote: String? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.prescription = prescription
        self.progression = progression
        self.history = history
        self.setup = setup
        self.sideNote = sideNote
    }

    public var isGoingUp: Bool { progression?.direction == .increase }
}

public enum GroupFormat: String, Codable, Sendable {
    /// All sets of one exercise, resting between sets, before moving on.
    case straightSets
    /// One set of each exercise in turn, repeated for a number of rounds.
    case circuit
}

/// A block of a session: warm-up, main lifts, accessories, a circuit.
public struct ExerciseGroup: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var format: GroupFormat
    public var estimatedMinutes: Int
    /// Warm-up work is excluded from hard-set counts and session stats.
    public var isWarmup: Bool?
    /// Circuit only: number of rounds.
    public var rounds: Int?
    /// Circuit only: rest between moves.
    public var transitionSeconds: Int?
    /// Circuit only: rest after the last move of a round.
    public var roundRestSeconds: Int?
    public var items: [PlannedExercise]

    public init(
        id: String, title: String, format: GroupFormat, estimatedMinutes: Int, isWarmup: Bool = false,
        rounds: Int? = nil, transitionSeconds: Int? = nil, roundRestSeconds: Int? = nil, items: [PlannedExercise]
    ) {
        self.id = id
        self.title = title
        self.format = format
        self.estimatedMinutes = estimatedMinutes
        self.isWarmup = isWarmup
        self.rounds = rounds
        self.transitionSeconds = transitionSeconds
        self.roundRestSeconds = roundRestSeconds
        self.items = items
    }

    public var warmup: Bool { isWarmup ?? false }
}

public enum SessionStatus: String, Codable, Sendable {
    case planned, completed, missed
}

/// A full session as returned by `GET /sessions/{id}`.
public struct WorkoutSession: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var date: LocalDate
    public var kind: SessionKind
    public var title: String
    public var estimatedMinutes: Int
    public var block: BlockPosition
    public var status: SessionStatus
    /// One sentence summarising today's load changes.
    public var progressionNote: String?
    /// The day of the previous session, used for the soreness question.
    public var previousSessionDate: LocalDate?
    public var equipment: [String]
    public var groups: [ExerciseGroup]

    public init(
        id: String, date: LocalDate, kind: SessionKind, title: String, estimatedMinutes: Int,
        block: BlockPosition, status: SessionStatus = .planned, progressionNote: String? = nil,
        previousSessionDate: LocalDate? = nil, equipment: [String] = [], groups: [ExerciseGroup]
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.block = block
        self.status = status
        self.progressionNote = progressionNote
        self.previousSessionDate = previousSessionDate
        self.equipment = equipment
        self.groups = groups
    }

    public var allExercises: [PlannedExercise] { groups.flatMap(\.items) }

    public var exerciseCount: Int { allExercises.count }

    public var coreLifts: [PlannedExercise] { allExercises.filter(\.exercise.isCoreLift) }

    /// Exercises whose load goes up today.
    public var liftsGoingUp: [PlannedExercise] { allExercises.filter(\.isGoingUp) }

    public var overview: SessionOverview {
        SessionOverview(id: id, kind: kind, title: title, estimatedMinutes: estimatedMinutes, status: status)
    }
}

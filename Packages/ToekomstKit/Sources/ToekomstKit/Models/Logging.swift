import Foundation

public enum Soreness: String, Codable, CaseIterable, Sendable {
    case gone, aBit, stillSore
}

public enum Energy: String, Codable, CaseIterable, Sendable {
    case good, okay, drained
}

/// Answers to the two-question ready check before a session.
public struct ReadinessAnswers: Codable, Hashable, Sendable {
    public var soreness: Soreness
    public var energy: Energy

    public init(soreness: Soreness, energy: Energy) {
        self.soreness = soreness
        self.energy = energy
    }

    /// Recovery limits progression: if soreness hasn't cleared or energy is
    /// low, run last week's loads instead of today's increases.
    public var holdsLoads: Bool {
        soreness == .stillSore || energy == .drained
    }
}

/// One logged set or circuit move.
public struct SetLog: Codable, Hashable, Sendable {
    public var plannedExerciseID: String
    public var exerciseID: String
    public var groupID: String
    /// Set number, or round number in a circuit (1-based).
    public var setNumber: Int
    public var load: Double?
    public var reps: Int?
    public var durationSeconds: Int?
    /// How many more reps were left in the tank; 4 means "4 or more".
    public var repsInReserve: Int?
    public var completedAt: Date

    public init(
        plannedExerciseID: String, exerciseID: String, groupID: String, setNumber: Int, load: Double?,
        reps: Int?, durationSeconds: Int?, repsInReserve: Int?, completedAt: Date
    ) {
        self.plannedExerciseID = plannedExerciseID
        self.exerciseID = exerciseID
        self.groupID = groupID
        self.setNumber = setNumber
        self.load = load
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.repsInReserve = repsInReserve
        self.completedAt = completedAt
    }
}

/// A finished (or ended early) session, sent with `POST /sessions/{id}/log`.
public struct SessionLog: Codable, Hashable, Sendable {
    public var sessionID: String
    public var startedAt: Date
    public var endedAt: Date
    public var readiness: ReadinessAnswers?
    public var sets: [SetLog]
    /// Rest actually taken between sets, in seconds.
    public var restDurations: [Int]
    public var skippedSteps: Int

    public init(
        sessionID: String, startedAt: Date, endedAt: Date, readiness: ReadinessAnswers?,
        sets: [SetLog], restDurations: [Int], skippedSteps: Int
    ) {
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.readiness = readiness
        self.sets = sets
        self.restDurations = restDurations
        self.skippedSteps = skippedSteps
    }
}

public struct SessionHighlight: Codable, Hashable, Sendable {
    public var exerciseName: String
    public var detail: String
    public var isPersonalRecord: Bool

    public init(exerciseName: String, detail: String, isPersonalRecord: Bool) {
        self.exerciseName = exerciseName
        self.detail = detail
        self.isPersonalRecord = isPersonalRecord
    }
}

/// What the next session will ask for on one exercise.
public struct NextTarget: Codable, Hashable, Sendable {
    public var exerciseName: String
    public var direction: ProgressionDirection
    public var load: Double
    /// Extra context ("1 set light").
    public var note: String?

    public init(exerciseName: String, direction: ProgressionDirection, load: Double, note: String? = nil) {
        self.exerciseName = exerciseName
        self.direction = direction
        self.load = load
        self.note = note
    }
}

/// The session summary returned after logging.
public struct SessionResult: Codable, Hashable, Sendable {
    public var sessionID: String
    public var startedAt: Date
    public var endedAt: Date
    public var durationSeconds: Int
    /// Total pounds moved in working sets.
    public var volume: Double
    public var setsCompleted: Int
    public var setsPlanned: Int
    /// Working sets ended 0-3 reps short of failure, out of sets with an effort rating.
    public var effortOnTarget: Int
    public var effortRated: Int
    public var averageRestSeconds: Int?
    public var highlights: [SessionHighlight]
    public var nextTargets: [NextTarget]

    public init(
        sessionID: String, startedAt: Date, endedAt: Date, durationSeconds: Int, volume: Double,
        setsCompleted: Int, setsPlanned: Int, effortOnTarget: Int, effortRated: Int,
        averageRestSeconds: Int?, highlights: [SessionHighlight], nextTargets: [NextTarget]
    ) {
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.volume = volume
        self.setsCompleted = setsCompleted
        self.setsPlanned = setsPlanned
        self.effortOnTarget = effortOnTarget
        self.effortRated = effortRated
        self.averageRestSeconds = averageRestSeconds
        self.highlights = highlights
        self.nextTargets = nextTargets
    }
}

/// How hard the whole session felt, sent with `POST /sessions/{id}/feedback`.
public struct SessionFeedback: Codable, Hashable, Sendable {
    public var sessionID: String
    /// 1 (easy) to 5 (all out).
    public var difficulty: Int
    public var note: String?

    public init(sessionID: String, difficulty: Int, note: String?) {
        self.sessionID = sessionID
        self.difficulty = difficulty
        self.note = note
    }
}

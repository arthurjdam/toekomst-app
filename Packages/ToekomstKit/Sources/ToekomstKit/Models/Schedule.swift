import Foundation

/// The short form of a session used in calendars and lists.
public struct SessionOverview: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: SessionKind
    public var title: String
    public var estimatedMinutes: Int
    public var status: SessionStatus
    /// How long it actually took, once completed.
    public var actualMinutes: Int?

    public init(
        id: String, kind: SessionKind, title: String, estimatedMinutes: Int,
        status: SessionStatus, actualMinutes: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.status = status
        self.actualMinutes = actualMinutes
    }
}

public struct ScheduledDay: Codable, Hashable, Identifiable, Sendable {
    public var date: LocalDate
    /// Nil on rest days.
    public var session: SessionOverview?

    public init(date: LocalDate, session: SessionOverview?) {
        self.date = date
        self.session = session
    }

    public var id: LocalDate { date }
    public var isRestDay: Bool { session == nil }
}

/// Hard sets and number of sessions hitting one muscle group in a week.
public struct MuscleCoverage: Codable, Hashable, Identifiable, Sendable {
    public var muscle: MuscleGroup
    public var hardSets: Int
    /// Number of sessions that train this muscle.
    public var hits: Int

    public init(muscle: MuscleGroup, hardSets: Int, hits: Int) {
        self.muscle = muscle
        self.hardSets = hardSets
        self.hits = hits
    }

    public var id: MuscleGroup { muscle }
}

/// A week of the plan, as returned by `GET /weeks/{weekStart}`.
public struct WeekSchedule: Codable, Hashable, Sendable {
    /// Always a Monday.
    public var weekStart: LocalDate
    public var block: BlockPosition
    /// Seven days, Monday first.
    public var days: [ScheduledDay]
    public var coverage: [MuscleCoverage]
    /// The back-end's one-line read on this week's coverage.
    public var coverageNote: String?
    /// Whether the training days can still be changed.
    public var isEditable: Bool

    public init(
        weekStart: LocalDate, block: BlockPosition, days: [ScheduledDay], coverage: [MuscleCoverage],
        coverageNote: String?, isEditable: Bool
    ) {
        self.weekStart = weekStart
        self.block = block
        self.days = days
        self.coverage = coverage
        self.coverageNote = coverageNote
        self.isEditable = isEditable
    }

    public var weekEnd: LocalDate { weekStart.adding(days: 6) }

    public var trainingDays: [Weekday] {
        days.filter { !$0.isRestDay }.map(\.date.weekday)
    }

    public var sessions: [SessionOverview] { days.compactMap(\.session) }

    public var completedCount: Int { sessions.filter { $0.status == .completed }.count }
}

/// A request to set the training days for a week (`PUT /weeks/{weekStart}/plan`).
public struct WeekPlanRequest: Codable, Hashable, Sendable {
    public var weekStart: LocalDate
    public var trainingDays: [Weekday]
    /// Session template ids in the order chosen by the planner, one per training day.
    public var sessionOrder: [String]
    /// Use these days for every following week too.
    public var repeatEveryWeek: Bool

    public init(weekStart: LocalDate, trainingDays: [Weekday], sessionOrder: [String], repeatEveryWeek: Bool) {
        self.weekStart = weekStart
        self.trainingDays = trainingDays
        self.sessionOrder = sessionOrder
        self.repeatEveryWeek = repeatEveryWeek
    }
}

/// A session slot in the weekly template ("Full-body circuit A" is a conditioning slot).
public struct SessionTemplate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: SessionKind
    public var title: String

    public init(id: String, kind: SessionKind, title: String) {
        self.id = id
        self.kind = kind
        self.title = title
    }
}

/// Everything needed to plan a week: what must be scheduled and the current days.
public struct WeekPlanDraft: Codable, Hashable, Sendable {
    public var weekStart: LocalDate
    public var templates: [SessionTemplate]
    public var selectedDays: [Weekday]
    public var repeatEveryWeek: Bool

    public init(weekStart: LocalDate, templates: [SessionTemplate], selectedDays: [Weekday], repeatEveryWeek: Bool) {
        self.weekStart = weekStart
        self.templates = templates
        self.selectedDays = selectedDays
        self.repeatEveryWeek = repeatEveryWeek
    }
}

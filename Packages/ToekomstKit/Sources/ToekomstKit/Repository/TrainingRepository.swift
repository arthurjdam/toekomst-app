import Foundation

/// Everything the app reads from and writes to the back-end.
///
/// The app only talks to this protocol. `FixtureTrainingRepository` implements
/// it from bundled JSON today; an HTTP implementation can replace it without
/// touching any screen. Each method notes the endpoint it is expected to map to.
public protocol TrainingRepository: Sendable {
    /// `GET /today`: today's session, the week strip, check-in and what's next.
    func today() async throws -> TodayOverview

    /// `GET /weeks/{weekStart}`: one week of the plan with muscle coverage.
    func week(starting weekStart: LocalDate) async throws -> WeekSchedule

    /// The weeks the schedule can page through.
    func scheduleBounds() async throws -> ClosedRange<LocalDate>

    /// `GET /weeks/{weekStart}/plan`: the sessions to place and the current days.
    func weekPlanDraft(for weekStart: LocalDate) async throws -> WeekPlanDraft

    /// `PUT /weeks/{weekStart}/plan`
    func saveWeekPlan(_ request: WeekPlanRequest) async throws -> WeekSchedule

    /// `GET /sessions/{id}`
    func session(id: String) async throws -> WorkoutSession

    /// `POST /sessions/{id}/move`: move a planned session to a rest day in the same week.
    func moveSession(id: String, to date: LocalDate) async throws -> WeekSchedule

    /// `PUT /check-ins/{date}`
    func saveCheckIn(_ checkIn: DailyCheckIn) async throws -> DailyCheckIn

    /// `GET /progress?range=`
    func progress(range: ProgressRange) async throws -> ProgressOverview

    /// `POST /sessions/{id}/log`: returns the summary and next-session targets.
    func logSession(_ log: SessionLog) async throws -> SessionResult

    /// `POST /sessions/{id}/feedback`
    func submitFeedback(_ feedback: SessionFeedback) async throws
}

public enum RepositoryError: Error, Equatable, LocalizedError {
    case notFound(String)
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let what): return "Couldn't find \(what)."
        case .invalidRequest(let reason): return reason
        }
    }
}

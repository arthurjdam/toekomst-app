import XCTest
@testable import ToekomstKit

final class FixtureRepositoryTests: XCTestCase {
    var repository: FixtureTrainingRepository!

    override func setUp() async throws {
        repository = try FixtureTrainingRepository()
    }

    func testTodayMatchesTheDesign() async throws {
        let today = try await repository.today()
        XCTAssertEqual(today.date, LocalDate(year: 2026, month: 10, day: 22))
        XCTAssertEqual(today.week.block, BlockPosition(blockNumber: 2, week: 2, weeksInBlock: 3, phase: "Rebuild phase"))

        let session = try XCTUnwrap(today.session)
        XCTAssertEqual(session.kind, .lowerMass)
        XCTAssertEqual(session.title, "Squat + hinge")
        XCTAssertEqual(session.exerciseCount, 8)
        XCTAssertEqual(session.coreLifts.map(\.exercise.name), ["Back squat", "Romanian deadlift"])
        XCTAssertEqual(session.previousSessionDate?.weekday, .tuesday)

        let kinds = today.week.days.map { $0.session?.kind }
        XCTAssertEqual(kinds, [.conditioning, .upperMass, nil, .lowerMass, nil, .conditioning, nil])
        XCTAssertEqual(today.week.completedCount, 2)
        XCTAssertEqual(today.week.days[0].session?.actualMinutes, 34)

        XCTAssertEqual(today.upNext?.date.weekday, .saturday)
        XCTAssertEqual(today.upNext?.session.title, "Full-body circuit B")
        XCTAssertEqual(today.checkIn.bodyweight, 182.4)
        XCTAssertNil(today.checkIn.proteinGrams)
    }

    func testCoverageFlagsShortMuscles() async throws {
        let week = try await repository.week(starting: LocalDate(year: 2026, month: 10, day: 19))
        let calves = try XCTUnwrap(week.coverage.first { $0.muscle == .calves })
        XCTAssertEqual(CoverageStatus(calves), .under)
        XCTAssertEqual(week.coverageNote, "Calves are under 10 hard sets this week.")
        XCTAssertEqual(week.coverage.count, MuscleGroup.allCases.count)
    }

    func testSavingAWeekPlanReordersSessions() async throws {
        let nextWeek = LocalDate(year: 2026, month: 10, day: 26)
        let draft = try await repository.weekPlanDraft(for: nextWeek)
        XCTAssertEqual(draft.selectedDays, [.monday, .tuesday, .thursday, .saturday])

        let days: [Weekday] = [.tuesday, .thursday, .friday, .sunday]
        let plan = WeekPlanner.plan(days: days, sessions: draft.templates, kind: \.kind)
        let week = try await repository.saveWeekPlan(WeekPlanRequest(
            weekStart: nextWeek, trainingDays: plan.days, sessionOrder: plan.sessions.map(\.id), repeatEveryWeek: false
        ))
        XCTAssertEqual(week.trainingDays, days)
        XCTAssertEqual(week.block.week, 3)

        let following = try await repository.week(starting: nextWeek.adding(days: 7))
        XCTAssertEqual(following.trainingDays, [.monday, .tuesday, .thursday, .saturday])
        XCTAssertEqual(following.block.blockNumber, 3)
        XCTAssertEqual(following.block.week, 1)
    }

    func testRepeatingDaysApplyToLaterWeeks() async throws {
        let nextWeek = LocalDate(year: 2026, month: 10, day: 26)
        let days: [Weekday] = [.monday, .wednesday, .friday, .sunday]
        let draft = try await repository.weekPlanDraft(for: nextWeek)
        let plan = WeekPlanner.plan(days: days, sessions: draft.templates, kind: \.kind)
        _ = try await repository.saveWeekPlan(WeekPlanRequest(
            weekStart: nextWeek, trainingDays: plan.days, sessionOrder: plan.sessions.map(\.id), repeatEveryWeek: true
        ))
        let later = try await repository.week(starting: nextWeek.adding(days: 14))
        XCTAssertEqual(later.trainingDays, days)
        let current = try await repository.week(starting: nextWeek.adding(days: -7))
        XCTAssertEqual(current.trainingDays, [.monday, .tuesday, .thursday, .saturday])
    }

    func testPastWeeksCannotBeReplanned() async throws {
        let request = WeekPlanRequest(
            weekStart: LocalDate(year: 2026, month: 10, day: 12), trainingDays: [.monday, .tuesday, .thursday, .saturday],
            sessionOrder: ["conditioning-a", "upper-mass", "lower-mass", "conditioning-b"], repeatEveryWeek: false
        )
        do {
            _ = try await repository.saveWeekPlan(request)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalidRequest("Past weeks can't be changed."))
        }
    }

    func testMovingASession() async throws {
        let week = try await repository.moveSession(id: "lower-mass@2026-10-22", to: LocalDate(year: 2026, month: 10, day: 23))
        XCTAssertNil(week.days[3].session)
        XCTAssertEqual(week.days[4].session?.id, "lower-mass@2026-10-23")

        let today = try await repository.today()
        XCTAssertNil(today.session)
        XCTAssertEqual(today.upNext?.session.kind, .lowerMass)

        // Moving it again updates the original move instead of chaining.
        let back = try await repository.moveSession(id: "lower-mass@2026-10-23", to: LocalDate(year: 2026, month: 10, day: 22))
        XCTAssertEqual(back.days[3].session?.id, "lower-mass@2026-10-22")
    }

    func testMovingOntoATrainingDayFails() async throws {
        do {
            _ = try await repository.moveSession(id: "lower-mass@2026-10-22", to: LocalDate(year: 2026, month: 10, day: 24))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalidRequest("Saturday already has a session."))
        }
    }

    func testProgressRanges() async throws {
        let twelve = try await repository.progress(range: .twelveWeeks)
        XCTAssertEqual(twelve.bodyweight.points.count, 13)
        XCTAssertEqual(twelve.bodyweight.current, 182.4)
        XCTAssertEqual(twelve.bodyweight.weeklyChange, 0.37, accuracy: 0.02)
        XCTAssertEqual(twelve.bodyweight.pace, .onPace)
        XCTAssertEqual(twelve.lifts.first?.estimatedMax, 232)
        XCTAssertEqual(twelve.lifts.first?.change ?? 0, 0.06, accuracy: 0.005)
        XCTAssertEqual(twelve.consistency.completedSessions, 26)
        XCTAssertEqual(twelve.consistency.plannedSessions, 28)

        let four = try await repository.progress(range: .fourWeeks)
        XCTAssertEqual(four.bodyweight.points.count, 5)
        let all = try await repository.progress(range: .all)
        XCTAssertEqual(all.bodyweight.points.count, 25)
    }

    func testCheckInUpdatesBodyweightTrend() async throws {
        let today = try await repository.today()
        var checkIn = today.checkIn
        checkIn.bodyweight = 183.0
        checkIn.proteinGrams = 170
        _ = try await repository.saveCheckIn(checkIn)

        let updated = try await repository.today()
        XCTAssertEqual(updated.checkIn.proteinGrams, 170)
        XCTAssertTrue(updated.checkIn.proteinTargetMet)
        let progress = try await repository.progress(range: .fourWeeks)
        XCTAssertEqual(progress.bodyweight.current, 183.0)
    }

    func testEveryWeekInBoundsLoads() async throws {
        let bounds = try await repository.scheduleBounds()
        var week = bounds.lowerBound
        while week <= bounds.upperBound {
            let schedule = try await repository.week(starting: week)
            XCTAssertEqual(schedule.days.count, 7)
            XCTAssertEqual(schedule.sessions.count, 4)
            for session in schedule.sessions {
                _ = try await repository.session(id: session.id)
            }
            week = week.adding(days: 7)
        }
    }

    func testFeedbackValidation() async throws {
        try await repository.submitFeedback(SessionFeedback(sessionID: "lower-mass@2026-10-22", difficulty: 4, note: nil))
        do {
            try await repository.submitFeedback(SessionFeedback(sessionID: "lower-mass@2026-10-22", difficulty: 7, note: nil))
            XCTFail("expected an error")
        } catch {}
    }
}

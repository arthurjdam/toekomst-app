import XCTest
@testable import ToekomstKit

final class WorkoutEngineTests: XCTestCase {
    var repository: FixtureTrainingRepository!
    let start = Date(timeIntervalSince1970: 1_792_700_000)

    override func setUp() async throws {
        repository = try FixtureTrainingRepository()
    }

    func lowerMass() async throws -> WorkoutSession {
        try await repository.session(id: "lower-mass@2026-10-22")
    }

    func testStepsMatchThePlannedSets() async throws {
        let engine = WorkoutEngine(session: try await lowerMass(), startedAt: start)
        // 1 bike + 2 goblet + 4 squat + 3 RDL + 3 split squat + 3 curl + 4 calf + 3 knee raise.
        XCTAssertEqual(engine.steps.count, 23)
        XCTAssertEqual(engine.exerciseCount, 8)
        XCTAssertEqual(engine.currentStep, WorkoutStep(groupIndex: 0, itemIndex: 0, setNumber: 1))
    }

    func testCircuitStepsInterleaveMoves() async throws {
        let session = try await repository.session(id: "conditioning-b@2026-10-24")
        let engine = WorkoutEngine(session: session, startedAt: start)
        // Warm-up 1 + circuit 3 rounds x 5 + finisher 3 rounds x 2.
        XCTAssertEqual(engine.steps.count, 1 + 15 + 6)
        XCTAssertEqual(engine.steps[1], WorkoutStep(groupIndex: 1, itemIndex: 0, setNumber: 1))
        XCTAssertEqual(engine.steps[2], WorkoutStep(groupIndex: 1, itemIndex: 1, setNumber: 1))
        XCTAssertEqual(engine.steps[6], WorkoutStep(groupIndex: 1, itemIndex: 0, setNumber: 2))
        XCTAssertEqual(engine.restSeconds(after: engine.steps[1]), 15)
        XCTAssertEqual(engine.restSeconds(after: engine.steps[5]), 90)
    }

    func testReadinessHoldRemovesTodaysIncrease() async throws {
        var engine = WorkoutEngine(session: try await lowerMass(), startedAt: start)
        let squatSet = WorkoutStep(groupIndex: 1, itemIndex: 0, setNumber: 1)
        let rdlSet = WorkoutStep(groupIndex: 1, itemIndex: 1, setNumber: 1)
        XCTAssertEqual(engine.targetLoad(for: squatSet), 185)

        engine.setReadiness(ReadinessAnswers(soreness: .stillSore, energy: .good))
        XCTAssertEqual(engine.targetLoad(for: squatSet), 180)
        XCTAssertEqual(engine.targetLoad(for: rdlSet), 155)
    }

    func testChangedLoadCarriesToLaterSets() async throws {
        var engine = WorkoutEngine(session: try await lowerMass(), startedAt: start)
        for _ in 0..<3 { engine.completeCurrentAsPlanned(at: start) }
        XCTAssertEqual(engine.currentStep, WorkoutStep(groupIndex: 1, itemIndex: 0, setNumber: 1))

        engine.logCurrent(load: 190, reps: 7, repsInReserve: 1, at: start)
        XCTAssertEqual(engine.targetLoad(for: engine.currentStep!), 190)
    }

    func testProgressStates() async throws {
        var engine = WorkoutEngine(session: try await lowerMass(), startedAt: start)
        for _ in 0..<4 { engine.completeCurrentAsPlanned(at: start) }
        // Exercise 3 of 8, set 2 of 4: the design's in-workout state.
        XCTAssertEqual(engine.exerciseNumber(of: engine.currentStep!), 3)
        XCTAssertEqual(engine.currentStep?.setNumber, 2)
        let progress = engine.progress()
        XCTAssertEqual(progress[0], [.done, .done])
        XCTAssertEqual(progress[1][0], .current(sets: [.done, .current, .upcoming, .upcoming]))
        XCTAssertEqual(progress[1][1], .upcoming)
    }

    func testFinishingAGroupAndTheSession() async throws {
        var engine = WorkoutEngine(session: try await lowerMass(), startedAt: start)
        XCTAssertFalse(engine.finishesGroup(engine.steps[0]))
        XCTAssertTrue(engine.finishesGroup(engine.steps[2]))
        while !engine.isFinished { engine.completeCurrentAsPlanned(at: start) }
        XCTAssertNil(engine.currentStep)
        XCTAssertEqual(engine.estimatedSecondsRemaining(), 0)
        XCTAssertEqual(engine.makeLog(endedAt: start).skippedSteps, 0)
    }

    func testSkippingCountsTowardTheLog() async throws {
        var engine = WorkoutEngine(session: try await lowerMass(), startedAt: start)
        engine.skipCurrent()
        engine.completeCurrentAsPlanned(at: start)
        let log = engine.makeLog(endedAt: start)
        XCTAssertEqual(log.sets.count, 1)
        XCTAssertEqual(log.skippedSteps, 1 + 21)
    }
}

final class SessionResultTests: XCTestCase {
    func testSummaryFromAFullSession() async throws {
        let repository = try FixtureTrainingRepository()
        let session = try await repository.session(id: "lower-mass@2026-10-22")
        let start = Date(timeIntervalSince1970: 1_792_700_000)
        var engine = WorkoutEngine(session: session, startedAt: start)
        var clock = start

        // Reps per exercise id, chosen to mirror the design's summary.
        let reps: [String: [Int]] = [
            "lm-back-squat": [8, 8, 8, 8],
            "lm-rdl": [10, 9, 9],
            "lm-split-squat": [12, 12, 12],
            "lm-leg-curl": [11, 10, 9],
            "lm-calf-raise": [14, 13, 13, 12],
            "lm-knee-raise": [12, 12, 12]
        ]
        while let step = engine.currentStep {
            let item = engine.item(of: step)
            clock += 150
            if let planned = reps[item.id] {
                engine.logCurrent(load: engine.targetLoad(for: step), reps: planned[step.setNumber - 1], repsInReserve: 2, at: clock)
                engine.recordRest(seconds: 110)
            } else {
                engine.completeCurrentAsPlanned(at: clock)
            }
        }

        let result = try await repository.logSession(engine.makeLog(endedAt: clock))
        XCTAssertEqual(result.setsCompleted, 23)
        XCTAssertEqual(result.setsPlanned, 23)
        XCTAssertEqual(result.durationSeconds, 23 * 150)
        XCTAssertEqual(result.effortOnTarget, 20)
        XCTAssertEqual(result.averageRestSeconds, 110)

        XCTAssertEqual(result.highlights.first?.exerciseName, "Romanian deadlift")
        XCTAssertEqual(result.highlights.first?.isPersonalRecord, true)
        XCTAssertEqual(result.highlights.first?.detail, "155 × 10")
        XCTAssertTrue(result.highlights.contains { $0.exerciseName == "Back squat" && $0.detail == "8,8,8,8 · top of range" })

        XCTAssertEqual(result.nextTargets.map(\.exerciseName), ["Back squat", "Bulgarian split squat", "Lying leg curl"])
        XCTAssertEqual(result.nextTargets[0].load, 190)
        XCTAssertEqual(result.nextTargets[1].load, 35)
        XCTAssertEqual(result.nextTargets[2].direction, .hold)
        XCTAssertEqual(result.nextTargets[2].note, "1 set light")

        let today = try await repository.today()
        XCTAssertEqual(today.week.days[3].session?.status, .completed)
    }
}

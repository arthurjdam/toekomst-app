import XCTest
@testable import ToekomstKit

@MainActor
final class WorkoutPlayerModelTests: XCTestCase {
    func makeModel(_ id: String, autoStart: Bool = true) async throws -> WorkoutPlayerModel {
        let repository = try FixtureTrainingRepository()
        let session = try await repository.session(id: id)
        return WorkoutPlayerModel(session: session, repository: repository, autoStartAfterRest: autoStart)
    }

    func testStraightSetFlow() async throws {
        let model = try await makeModel("lower-mass@2026-10-22")
        XCTAssertFalse(model.hasBegun)
        model.begin(with: ReadinessAnswers(soreness: .stillSore, energy: .good))
        XCTAssertEqual(model.screen, .exercise)

        // Warm-up bike is timed: start, then finish early.
        XCTAssertTrue(model.currentItem!.prescription.isTimed)
        model.startTimedSet()
        XCTAssertTrue(model.timedSetRunning)
        model.doneSet()
        XCTAssertEqual(model.screen, .transition, "bike -> goblet squat is a new exercise")
        model.endRest()
        XCTAssertEqual(model.screen, .exercise)

        // Goblet squat: rep based, opens the log sheet.
        model.doneSet()
        XCTAssertTrue(model.showLogSheet)
        model.logSet(load: 35, reps: 10, repsInReserve: 3)
        XCTAssertFalse(model.showLogSheet)
        XCTAssertEqual(model.screen, .rest, "set 2 of the same exercise")
        XCTAssertEqual(model.phaseDuration, 45)
        model.adjustRest(by: 15)
        XCTAssertEqual(model.phaseDuration, 60)
        model.endRest()
        model.doneSet()
        model.logSet(load: 35, reps: 10, repsInReserve: 3)
        XCTAssertEqual(model.screen, .transition, "warm-up done, main lifts next")
        model.endRest()

        // Ready check said hold: squat runs at last week's 180.
        XCTAssertEqual(model.currentItem?.exercise.name, "Back squat")
        XCTAssertEqual(model.engine.targetLoad(for: model.currentStep!), 180)

        // Log everything else as planned, then the session finishes.
        while let step = model.currentStep {
            let item = model.engine.item(of: step)
            if model.screen == .rest || model.screen == .transition { model.endRest(); continue }
            if item.prescription.isTimed { model.completeAsPlanned(); continue }
            model.doneSet()
            model.logSet(load: model.engine.targetLoad(for: step), reps: item.prescription.reps!.max, repsInReserve: 2)
        }
        XCTAssertEqual(model.screen, .finishing)
        for _ in 0..<50 where model.screen != .summary {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.screen, .summary)
        XCTAssertEqual(model.result?.setsCompleted, 23)
        // Held loads: no increases suggested.
        XCTAssertFalse(model.result!.nextTargets.contains { $0.direction == .increase })
        model.stop()
    }

    func testSkippingSetDetailsLogsAsPlanned() async throws {
        let repository = try FixtureTrainingRepository()
        let session = try await repository.session(id: "lower-mass@2026-10-22")
        let model = WorkoutPlayerModel(session: session, repository: repository, autoStartAfterRest: true, logsSetDetails: false)
        model.begin(with: nil)
        model.completeAsPlanned() // warm-up bike
        model.endRest()
        model.doneSet()
        XCTAssertFalse(model.showLogSheet, "no sheet when set details are off")
        XCTAssertEqual(model.screen, .rest)
        XCTAssertEqual(model.lastLogged?.reps, 10)
        XCTAssertEqual(model.lastLogged?.load, 35)
        XCTAssertNil(model.lastLogged?.repsInReserve)

        // Finish the session without rating any set: no load increases.
        while model.currentStep != nil {
            if model.screen == .rest || model.screen == .transition { model.endRest(); continue }
            model.doneSet()
        }
        for _ in 0..<50 where model.screen != .summary {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.result?.setsCompleted, 23)
        XCTAssertFalse(model.result!.nextTargets.contains { $0.direction == .increase })
        model.stop()
    }

    func testCircuitFlow() async throws {
        let model = try await makeModel("conditioning-b@2026-10-24")
        model.begin(with: nil)
        model.startTimedSet()
        model.doneSet()
        XCTAssertEqual(model.screen, .transition, "warm-up -> circuit")
        model.endRest()
        XCTAssertEqual(model.screen, .circuit)
        XCTAssertEqual(model.circuitPhase, .work)
        XCTAssertEqual(model.phaseDuration, 40)

        model.skipCurrent()
        XCTAssertEqual(model.screen, .circuit)
        XCTAssertEqual(model.circuitPhase, .rest)
        XCTAssertEqual(model.phaseDuration, 15)
        model.endRest()
        XCTAssertEqual(model.circuitPhase, .work)
        XCTAssertEqual(model.currentItem?.exercise.name, "Single-leg RDL")
        model.stop()
    }

    func testPauseFreezesTheCountdown() async throws {
        let model = try await makeModel("lower-mass@2026-10-22", autoStart: false)
        model.begin(with: nil)
        model.startTimedSet()
        model.pause()
        XCTAssertTrue(model.isPaused)
        XCTAssertTrue(model.showPauseMenu)
        let frozen = model.remainingSeconds
        try await Task.sleep(nanoseconds: 1_100_000_000)
        XCTAssertEqual(model.remainingSeconds, frozen)
        model.resume()
        XCTAssertFalse(model.isPaused)
        model.stop()
    }

    func testCountdownExpiryAdvancesCircuit() async throws {
        let model = try await makeModel("conditioning-b@2026-10-24")
        model.begin(with: nil)
        model.startTimedSet()
        model.doneSet()
        model.endRest()
        XCTAssertEqual(model.circuitPhase, .work)
        model.adjustRest(by: -40) // Not a rest, but shortens the work countdown to now.
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(model.circuitPhase, .rest, "work timer ran out and the move was logged")
        XCTAssertEqual(model.engine.logs.last?.exerciseID, "db-thruster")
        model.stop()
    }
}

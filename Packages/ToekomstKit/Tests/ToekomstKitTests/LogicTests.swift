import XCTest
@testable import ToekomstKit

final class LocalDateTests: XCTestCase {
    func testParsesAndFormats() {
        let date = LocalDate("2026-10-22")
        XCTAssertEqual(date, LocalDate(year: 2026, month: 10, day: 22))
        XCTAssertEqual(date?.isoString, "2026-10-22")
        XCTAssertNil(LocalDate("2026-02-31"))
        XCTAssertNil(LocalDate("22-10"))
    }

    func testWeekdayAndWeekStart() {
        let thursday = LocalDate(year: 2026, month: 10, day: 22)
        XCTAssertEqual(thursday.weekday, .thursday)
        XCTAssertEqual(thursday.startOfWeek, LocalDate(year: 2026, month: 10, day: 19))
        XCTAssertEqual(LocalDate(year: 2026, month: 10, day: 25).weekday, .sunday)
        XCTAssertEqual(LocalDate(year: 2026, month: 10, day: 25).startOfWeek, LocalDate(year: 2026, month: 10, day: 19))
    }

    func testArithmeticAcrossMonths() {
        let start = LocalDate(year: 2026, month: 10, day: 26)
        XCTAssertEqual(start.adding(days: 6), LocalDate(year: 2026, month: 11, day: 1))
        XCTAssertEqual(start.days(until: LocalDate(year: 2026, month: 11, day: 1)), 6)
        XCTAssertEqual(LocalDate(year: 2026, month: 11, day: 1).days(until: start), -6)
    }

    func testCodableRoundTrip() throws {
        let date = LocalDate(year: 2026, month: 1, day: 5)
        let data = try JSONEncoder().encode([date])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-01-05\"]")
        XCTAssertEqual(try JSONDecoder().decode([LocalDate].self, from: data), [date])
    }
}

final class FormatTests: XCTestCase {
    func testClockAndWeights() {
        XCTAssertEqual(Format.clock(120), "2:00")
        XCTAssertEqual(Format.clock(45), "0:45")
        XCTAssertEqual(Format.clock(-7), "0:07")
        XCTAssertEqual(Format.clock(3372), "56:12")
        XCTAssertEqual(Format.weight(185), "185")
        XCTAssertEqual(Format.weight(182.4), "182.4")
        XCTAssertEqual(Format.signedWeight(5), "+5")
        XCTAssertEqual(Format.grouped(14820), "14,820")
    }

    func testDates() {
        XCTAssertEqual(Format.dayHeader(LocalDate(year: 2026, month: 10, day: 22)), "Thu 22 Oct")
        XCTAssertEqual(Format.weekRange(LocalDate(year: 2026, month: 10, day: 19)), "Oct 19-25")
        XCTAssertEqual(Format.weekRange(LocalDate(year: 2026, month: 10, day: 26)), "Oct 26-Nov 1")
    }

    func testPrescriptionLines() {
        let squat = Prescription(sets: 4, reps: RepTarget(min: 6, max: 8), load: 185, restSeconds: 120)
        XCTAssertEqual(Format.prescription(squat, loadKind: .barbell, includeRest: true), "4 × 6-8 · 185 lb · 2:00")
        XCTAssertEqual(Format.prescription(squat, loadKind: .barbell, includeRest: false), "4 × 6-8 · 185 lb")

        let bike = Prescription(sets: 1, durationSeconds: 300, note: "conversational pace", restSeconds: 30)
        XCTAssertEqual(Format.prescription(bike, loadKind: .cardio, includeRest: false), "5:00 · conversational pace")

        let raise = Prescription(sets: 3, reps: RepTarget(exactly: 12), restSeconds: 45)
        XCTAssertEqual(Format.prescription(raise, loadKind: .bodyweight, includeRest: true), "3 × 12 · bodyweight · 0:45")

        let split = Prescription(sets: 3, reps: RepTarget(min: 10, max: 12, perSide: true), load: 30, restSeconds: 90)
        XCTAssertEqual(Format.prescription(split, loadKind: .dumbbellPair, includeRest: true), "3 × 10-12/side · 30 lb · 1:30")
    }
}

final class WeekPlannerTests: XCTestCase {
    let week: [SessionKind] = [.conditioning, .upperMass, .lowerMass, .conditioning]

    func testKeepsTemplateOrderWhenItWorks() {
        let plan = WeekPlanner.plan(days: [.monday, .tuesday, .thursday, .saturday], sessions: week) { $0 }
        XCTAssertEqual(plan.sessions, [.conditioning, .upperMass, .lowerMass, .conditioning])
        XCTAssertEqual(plan.status, .good)
        XCTAssertTrue(plan.clashes.isEmpty)
    }

    func testReordersToAvoidLegsBackToBack() {
        // Thu + Fri are consecutive: lower mass must not sit next to a circuit.
        let plan = WeekPlanner.plan(days: [.tuesday, .thursday, .friday, .sunday], sessions: week) { $0 }
        XCTAssertTrue(plan.clashes.isEmpty)
        let thursday = plan.sessions[1]
        let friday = plan.sessions[2]
        XCTAssertFalse(WeekPlanner.clashes(thursday, friday))
    }

    func testFlagsUnavoidableClash() {
        let plan = WeekPlanner.plan(days: [.monday, .tuesday, .wednesday, .thursday], sessions: week) { $0 }
        XCTAssertFalse(plan.clashes.isEmpty)
        if case .tight = plan.status {} else { XCTFail("expected tight, got \(plan.status)") }
    }

    func testCountsLongRuns() {
        let plan = WeekPlanner.plan(days: [.monday, .tuesday, .wednesday, .saturday], sessions: week) { $0 }
        XCTAssertTrue(plan.clashes.isEmpty)
        XCTAssertEqual(plan.status, .longRun(3))
    }

    func testEvaluatesAHandArrangedOrder() {
        let days: [Weekday] = [.thursday, .friday, .monday, .saturday]
        let manual: [SessionKind] = [.conditioning, .upperMass, .lowerMass, .conditioning]
        let plan = WeekPlanner.evaluate(days: days, sessions: manual) { $0 }
        XCTAssertEqual(plan.days, [.monday, .thursday, .friday, .saturday])
        XCTAssertEqual(plan.sessions, manual)
        // Fri lower mass next to Sat circuit.
        XCTAssertEqual(plan.status, .tight(.friday, .saturday))
    }

    func testWrongDayCount() {
        XCTAssertEqual(WeekPlanner.plan(days: [.monday, .friday], sessions: week) { $0 }.status, .needMore(2))
        let tooMany = WeekPlanner.plan(days: [.monday, .tuesday, .wednesday, .thursday, .friday], sessions: week) { $0 }
        XCTAssertEqual(tooMany.status, .tooMany(1))
        XCTAssertTrue(tooMany.sessions.isEmpty)
    }
}

final class RulesTests: XCTestCase {
    func testReadinessHoldsOnSorenessOrLowEnergy() {
        XCTAssertFalse(ReadinessAnswers(soreness: .gone, energy: .good).holdsLoads)
        XCTAssertFalse(ReadinessAnswers(soreness: .aBit, energy: .okay).holdsLoads)
        XCTAssertTrue(ReadinessAnswers(soreness: .stillSore, energy: .good).holdsLoads)
        XCTAssertTrue(ReadinessAnswers(soreness: .gone, energy: .drained).holdsLoads)
    }

    func testSetOutcome() {
        let target = RepTarget(min: 6, max: 8)
        XCTAssertEqual(SetOutcome(reps: 9, target: target), .aboveRange)
        XCTAssertEqual(SetOutcome(reps: 8, target: target), .topOfRange)
        XCTAssertEqual(SetOutcome(reps: 6, target: target), .inRange)
        XCTAssertEqual(SetOutcome(reps: 5, target: target), .belowRange)
    }

    func testPlates() {
        XCTAssertEqual(PlateCalculator.platesPerSide(for: 185), [45, 25])
        XCTAssertEqual(PlateCalculator.platesPerSide(for: 45), [])
        XCTAssertEqual(PlateCalculator.platesPerSide(for: 190), [45, 25, 2.5])
        XCTAssertNil(PlateCalculator.platesPerSide(for: 30))
        XCTAssertNil(PlateCalculator.platesPerSide(for: 186))
    }

    func testCoverageStatus() {
        XCTAssertEqual(CoverageStatus(MuscleCoverage(muscle: .calves, hardSets: 7, hits: 2)), .under)
        XCTAssertEqual(CoverageStatus(MuscleCoverage(muscle: .chest, hardSets: 12, hits: 1)), .under)
        XCTAssertEqual(CoverageStatus(MuscleCoverage(muscle: .chest, hardSets: 12, hits: 2)), .onTarget)
        XCTAssertEqual(CoverageStatus(MuscleCoverage(muscle: .back, hardSets: 22, hits: 3)), .over)
    }

    func testWeeklyRate() {
        let start = LocalDate(year: 2026, month: 1, day: 1)
        let points = (0..<5).map { BodyweightPoint(date: start.adding(days: 7 * $0), weight: 180 + 0.5 * Double($0)) }
        XCTAssertEqual(Estimate.weeklyRate(points), 0.5, accuracy: 0.0001)
    }

    func testOneRepMax() {
        XCTAssertEqual(Estimate.oneRepMax(load: 155, reps: 10), 206.67, accuracy: 0.01)
        XCTAssertEqual(Estimate.oneRepMax(load: 200, reps: 1), 200)
    }
}

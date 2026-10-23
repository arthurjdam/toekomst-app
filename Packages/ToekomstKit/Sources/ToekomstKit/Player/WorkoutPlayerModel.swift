import Foundation
import Observation

/// Drives the in-workout screens: which screen shows, the countdowns, and
/// logging into the `WorkoutEngine`.
///
/// Screens follow the design's flow: ready check → exercise → log set →
/// rest (same exercise) or up next (new exercise) → ... → summary. Circuit
/// moves run on their own work/rest timers.
@Observable
@MainActor
public final class WorkoutPlayerModel: Identifiable {
    public enum Screen: Equatable, Sendable {
        case exercise, rest, transition, circuit, finishing, summary
    }

    public enum CircuitPhase: Sendable {
        case work, rest
    }

    public let repository: any TrainingRepository
    /// Open the next set automatically when rest reaches 0:00; otherwise rest runs into overtime.
    public let autoStartAfterRest: Bool
    public private(set) var engine: WorkoutEngine
    public private(set) var screen: Screen = .exercise
    public private(set) var circuitPhase: CircuitPhase = .work

    /// The ready check is presented once the player is on screen.
    public var showReadiness = false
    public private(set) var hasBegun = false
    public var showLogSheet = false
    public var showPauseMenu = false
    public var showInfo = false
    /// The time chip toggles between time left and time elapsed.
    public var showElapsed = false

    /// Updated once a second while the workout runs; views read it for countdowns.
    public private(set) var now = Date()
    public private(set) var isPaused = false
    /// When the current countdown (rest, circuit work or rest, timed set) ends.
    public private(set) var phaseEndsAt: Date?
    /// Length of the current countdown, for rings and tick bars.
    public private(set) var phaseDuration = 0
    /// A timed straight set (warm-up bike) is counting down.
    public private(set) var timedSetRunning = false
    public private(set) var lastLogged: SetLog?
    public private(set) var result: SessionResult?
    public private(set) var finishError: String?

    /// Haptic triggers.
    public private(set) var setsLogged = 0
    public private(set) var phasesEnded = 0

    @ObservationIgnored private var restStartedAt: Date?
    private var pausedRemaining: TimeInterval?
    @ObservationIgnored private var overtimeSignalled = false
    @ObservationIgnored private var ticker: Task<Void, Never>?

    public init(session: WorkoutSession, repository: any TrainingRepository, autoStartAfterRest: Bool) {
        self.repository = repository
        self.autoStartAfterRest = autoStartAfterRest
        self.engine = WorkoutEngine(session: session, startedAt: Date())
        startTicker()
    }

    public var session: WorkoutSession { engine.session }

    // MARK: - Derived state

    public var currentStep: WorkoutStep? { engine.currentStep }

    public var currentItem: PlannedExercise? { currentStep.map { engine.item(of: $0) } }

    public var currentGroup: ExerciseGroup? { currentStep.map { engine.group(of: $0) } }

    /// Seconds left on the current countdown; negative in overtime.
    public var remainingSeconds: Int {
        if isPaused, let pausedRemaining { return Int(pausedRemaining.rounded(.up)) }
        guard let phaseEndsAt else { return 0 }
        let remaining = phaseEndsAt.timeIntervalSince(now)
        return Int(remaining >= 0 ? remaining.rounded(.up) : remaining.rounded(.down))
    }

    public var isOvertime: Bool { phaseEndsAt != nil && remainingSeconds < 0 }

    public var elapsedSeconds: Int { max(0, Int(now.timeIntervalSince(engine.startedAt))) }

    public var minutesLeft: Int {
        let countdown = max(0, remainingSeconds)
        return Int((Double(engine.estimatedSecondsRemaining() + countdown) / 60).rounded(.up))
    }

    public var timeChipText: String {
        showElapsed ? "\(Format.clock(elapsedSeconds)) in" : "~\(minutesLeft) min left"
    }

    // MARK: - Flow

    public func begin(with readiness: ReadinessAnswers?) {
        engine = WorkoutEngine(session: session, startedAt: Date())
        engine.setReadiness(readiness)
        hasBegun = true
        showReadiness = false
        enterCurrentStep()
    }

    /// Shows the screen for the current step and starts its timer if it has one.
    private func enterCurrentStep() {
        phaseEndsAt = nil
        timedSetRunning = false
        overtimeSignalled = false
        guard let step = engine.currentStep else {
            finish()
            return
        }
        if engine.group(of: step).format == .circuit {
            screen = .circuit
            circuitPhase = .work
            if let duration = engine.item(of: step).prescription.durationSeconds {
                startCountdown(seconds: duration)
            }
        } else {
            screen = .exercise
        }
    }

    /// Starts a timed straight set (e.g. the warm-up bike).
    public func startTimedSet() {
        guard let duration = currentItem?.prescription.durationSeconds else { return }
        timedSetRunning = true
        startCountdown(seconds: duration)
    }

    /// "Done set": timed work logs straight away, rep work opens the log sheet.
    public func doneSet() {
        guard let item = currentItem else { return }
        if item.prescription.isTimed || item.prescription.reps == nil {
            completeAsPlanned()
        } else {
            showLogSheet = true
        }
    }

    public func logSet(load: Double?, reps: Int, repsInReserve: Int) {
        engine.logCurrent(load: load, reps: reps, repsInReserve: repsInReserve, at: Date())
        lastLogged = engine.logs.last
        showLogSheet = false
        setsLogged += 1
        afterStep()
    }

    /// Logs the current step as prescribed (timed sets, circuit moves).
    public func completeAsPlanned() {
        engine.completeCurrentAsPlanned(at: Date())
        lastLogged = engine.logs.last
        setsLogged += 1
        afterStep()
    }

    public func skipCurrent() {
        engine.skipCurrent()
        afterStep()
    }

    /// After a step: finish, or start the rest that leads to the next step.
    private func afterStep() {
        timedSetRunning = false
        guard let finished = engine.previousStep, let next = engine.currentStep else {
            finish()
            return
        }
        restStartedAt = Date()
        overtimeSignalled = false
        startCountdown(seconds: engine.restSeconds(after: finished))
        if engine.group(of: finished).format == .circuit, next.groupIndex == finished.groupIndex {
            screen = .circuit
            circuitPhase = .rest
        } else if next.isSameExercise(as: finished) {
            screen = .rest
        } else {
            screen = .transition
        }
    }

    /// Ends the rest (timer ran out, "skip rest" or "I'm ready").
    public func endRest() {
        if let restStartedAt {
            engine.recordRest(seconds: Int(Date().timeIntervalSince(restStartedAt)))
        }
        restStartedAt = nil
        enterCurrentStep()
    }

    public func adjustRest(by seconds: Int) {
        guard let phaseEndsAt else { return }
        let earliest = Date()
        let adjusted = max(earliest, phaseEndsAt.addingTimeInterval(TimeInterval(seconds)))
        self.phaseEndsAt = adjusted
        phaseDuration = max(phaseDuration, Int(adjusted.timeIntervalSince(earliest).rounded(.up)))
        overtimeSignalled = false
        now = Date()
    }

    private func startCountdown(seconds: Int) {
        let start = Date()
        now = start
        phaseDuration = seconds
        phaseEndsAt = start.addingTimeInterval(TimeInterval(seconds))
    }

    // MARK: - Pause

    public func pause() {
        guard !isPaused else { return }
        isPaused = true
        pausedRemaining = phaseEndsAt?.timeIntervalSince(Date())
        showPauseMenu = true
    }

    public func resume() {
        guard isPaused else { return }
        if let pausedRemaining {
            phaseEndsAt = Date().addingTimeInterval(pausedRemaining)
        }
        pausedRemaining = nil
        isPaused = false
        now = Date()
    }

    // MARK: - Finishing

    public func finish() {
        guard screen != .finishing, screen != .summary else { return }
        screen = .finishing
        phaseEndsAt = nil
        isPaused = false
        Task { await submitLog() }
    }

    public func submitLog() async {
        finishError = nil
        do {
            result = try await repository.logSession(engine.makeLog(endedAt: Date()))
            screen = .summary
        } catch {
            finishError = error.localizedDescription
        }
    }

    public func submitFeedback(difficulty: Int, note: String?) async {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await repository.submitFeedback(SessionFeedback(
            sessionID: session.id,
            difficulty: difficulty,
            note: trimmed?.isEmpty == false ? trimmed : nil
        ))
    }

    public func stop() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: - Clock

    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        let current = Date()
        if Int(current.timeIntervalSince1970) != Int(now.timeIntervalSince1970) {
            now = current
        }
        guard hasBegun, !isPaused, !showLogSheet, let end = phaseEndsAt, current >= end else { return }

        switch screen {
        case .circuit where circuitPhase == .work:
            phasesEnded += 1
            completeAsPlanned()
        case .circuit:
            phasesEnded += 1
            endRest()
        case .exercise where timedSetRunning:
            phasesEnded += 1
            completeAsPlanned()
        case .rest, .transition:
            if autoStartAfterRest {
                phasesEnded += 1
                endRest()
            } else if !overtimeSignalled {
                overtimeSignalled = true
                phasesEnded += 1
            }
        default:
            break
        }
    }
}

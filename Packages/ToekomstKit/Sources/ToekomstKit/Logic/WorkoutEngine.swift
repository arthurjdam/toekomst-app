import Foundation

/// One thing to do in a session: a set of a straight-set exercise, or one
/// move of one circuit round.
public struct WorkoutStep: Hashable, Sendable {
    public let groupIndex: Int
    public let itemIndex: Int
    /// Set number for straight sets, round number for circuits (1-based).
    public let setNumber: Int

    public init(groupIndex: Int, itemIndex: Int, setNumber: Int) {
        self.groupIndex = groupIndex
        self.itemIndex = itemIndex
        self.setNumber = setNumber
    }

    public func isSameExercise(as other: WorkoutStep) -> Bool {
        groupIndex == other.groupIndex && itemIndex == other.itemIndex
    }
}

/// State of one exercise in the session progress bar.
public enum ExerciseProgress: Hashable, Sendable {
    case done
    case current(sets: [SetProgress])
    case upcoming
}

public enum SetProgress: Hashable, Sendable {
    case done, current, upcoming
}

/// Walks through a session step by step and records what was done.
///
/// A value type with no clock and no timers: the caller passes in dates, which
/// keeps every rule here testable. The app wraps it in an observable model that
/// owns the timers and screens.
public struct WorkoutEngine: Sendable {
    public let session: WorkoutSession
    public let steps: [WorkoutStep]
    public let startedAt: Date
    public private(set) var currentIndex = 0
    public private(set) var logs: [SetLog] = []
    public private(set) var skippedSteps = 0
    public private(set) var readiness: ReadinessAnswers?
    public private(set) var restDurations: [Int] = []
    /// Loads the person changed while logging, carried into later sets.
    private var loadOverrides: [String: Double] = [:]

    public init(session: WorkoutSession, startedAt: Date) {
        self.session = session
        self.startedAt = startedAt
        self.steps = Self.makeSteps(for: session)
    }

    static func makeSteps(for session: WorkoutSession) -> [WorkoutStep] {
        var steps: [WorkoutStep] = []
        for (groupIndex, group) in session.groups.enumerated() {
            switch group.format {
            case .straightSets:
                for (itemIndex, item) in group.items.enumerated() {
                    for set in 1...max(1, item.prescription.sets) {
                        steps.append(WorkoutStep(groupIndex: groupIndex, itemIndex: itemIndex, setNumber: set))
                    }
                }
            case .circuit:
                for round in 1...max(1, group.rounds ?? 1) {
                    for itemIndex in group.items.indices {
                        steps.append(WorkoutStep(groupIndex: groupIndex, itemIndex: itemIndex, setNumber: round))
                    }
                }
            }
        }
        return steps
    }

    // MARK: - Where we are

    public var currentStep: WorkoutStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    public var nextStep: WorkoutStep? {
        steps.indices.contains(currentIndex + 1) ? steps[currentIndex + 1] : nil
    }

    /// The step just finished, if any.
    public var previousStep: WorkoutStep? {
        steps.indices.contains(currentIndex - 1) ? steps[currentIndex - 1] : nil
    }

    public var isFinished: Bool { currentIndex >= steps.count }

    public func group(of step: WorkoutStep) -> ExerciseGroup {
        session.groups[step.groupIndex]
    }

    public func item(of step: WorkoutStep) -> PlannedExercise {
        session.groups[step.groupIndex].items[step.itemIndex]
    }

    /// Total sets (or rounds) for the exercise at `step`.
    public func setCount(for step: WorkoutStep) -> Int {
        let group = group(of: step)
        return group.format == .circuit ? max(1, group.rounds ?? 1) : max(1, item(of: step).prescription.sets)
    }

    /// 1-based position of the step's exercise among all exercises in the session.
    public func exerciseNumber(of step: WorkoutStep) -> Int {
        let before = session.groups.prefix(step.groupIndex).reduce(0) { $0 + $1.items.count }
        return before + step.itemIndex + 1
    }

    public var exerciseCount: Int { session.exerciseCount }

    /// Whether the move after `step` starts a new exercise group (warm-up done, main lifts done...).
    public func finishesGroup(_ step: WorkoutStep) -> Bool {
        guard let index = steps.firstIndex(of: step) else { return false }
        let following = steps.indices.contains(index + 1) ? steps[index + 1] : nil
        return following?.groupIndex != step.groupIndex
    }

    // MARK: - Targets

    /// Load to put on the bar for `step`: the planned load, minus today's
    /// increase if the ready check said to hold, or the load the person chose
    /// on an earlier set of the same exercise.
    public func targetLoad(for step: WorkoutStep) -> Double? {
        let item = item(of: step)
        guard let planned = item.prescription.load else { return nil }
        if let override = loadOverrides[item.id] {
            return override
        }
        if readiness?.holdsLoads == true, item.progression?.direction == .increase, let change = item.progression?.loadChange {
            return planned - change
        }
        return planned
    }

    /// Rest after finishing `step`.
    public func restSeconds(after step: WorkoutStep) -> Int {
        let group = group(of: step)
        switch group.format {
        case .straightSets:
            return item(of: step).prescription.restSeconds ?? 90
        case .circuit:
            let lastMoveOfRound = step.itemIndex == group.items.count - 1
            return lastMoveOfRound ? (group.roundRestSeconds ?? 60) : (group.transitionSeconds ?? 15)
        }
    }

    /// Rough time left: work plus planned rest for every remaining step.
    public func estimatedSecondsRemaining(secondsPerSet: Int = 45) -> Int {
        guard !isFinished else { return 0 }
        var total = 0
        for index in currentIndex..<steps.count {
            let step = steps[index]
            total += item(of: step).prescription.durationSeconds ?? secondsPerSet
            if index < steps.count - 1 {
                total += restSeconds(after: step)
            }
        }
        return total
    }

    // MARK: - Progress

    /// Per group, per exercise: done, current (with per-set state) or upcoming.
    public func progress() -> [[ExerciseProgress]] {
        session.groups.enumerated().map { groupIndex, group in
            group.items.indices.map { itemIndex in
                let indices = steps.indices.filter { steps[$0].groupIndex == groupIndex && steps[$0].itemIndex == itemIndex }
                guard let first = indices.first, let last = indices.last else { return .upcoming }
                if last < currentIndex { return .done }
                if first > currentIndex { return .upcoming }
                return .current(sets: indices.map { index in
                    index < currentIndex ? .done : (index == currentIndex ? .current : .upcoming)
                })
            }
        }
    }

    public var completedStepCount: Int { currentIndex }

    // MARK: - Recording

    public mutating func setReadiness(_ answers: ReadinessAnswers?) {
        readiness = answers
    }

    /// Logs the current step with what was actually done and moves on.
    public mutating func logCurrent(load: Double?, reps: Int?, repsInReserve: Int?, at date: Date) {
        guard let step = currentStep else { return }
        let item = item(of: step)
        if let load, let target = targetLoad(for: step), load != target {
            loadOverrides[item.id] = load
        }
        logs.append(SetLog(
            plannedExerciseID: item.id,
            exerciseID: item.exercise.id,
            groupID: group(of: step).id,
            setNumber: step.setNumber,
            load: load,
            reps: reps,
            durationSeconds: item.prescription.durationSeconds,
            repsInReserve: repsInReserve,
            completedAt: date
        ))
        currentIndex += 1
    }

    /// Logs the current step exactly as prescribed (timed work, circuit moves).
    public mutating func completeCurrentAsPlanned(at date: Date) {
        guard let step = currentStep else { return }
        let reps = item(of: step).prescription.reps?.max
        logCurrent(load: targetLoad(for: step), reps: reps, repsInReserve: nil, at: date)
    }

    public mutating func skipCurrent() {
        guard !isFinished else { return }
        skippedSteps += 1
        currentIndex += 1
    }

    public mutating func recordRest(seconds: Int) {
        guard seconds > 0 else { return }
        restDurations.append(seconds)
    }

    public func makeLog(endedAt: Date) -> SessionLog {
        SessionLog(
            sessionID: session.id,
            startedAt: startedAt,
            endedAt: endedAt,
            readiness: readiness,
            sets: logs,
            restDurations: restDurations,
            skippedSteps: skippedSteps + (steps.count - currentIndex)
        )
    }
}

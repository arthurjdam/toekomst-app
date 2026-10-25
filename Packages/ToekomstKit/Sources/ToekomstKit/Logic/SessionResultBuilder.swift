import Foundation

/// Turns a session log into the summary shown after a workout.
///
/// The real back-end owns progression decisions; this is the stand-in the
/// fixture repository uses, following the program rules: go up in load once
/// the top of the rep range is hit on every set two sessions running, and
/// flag sets that fell short. Only sets the person confirmed (with a reps in
/// reserve rating) can earn an increase; sets logged "as planned" can't.
public enum SessionResultBuilder {
    public static func build(session: WorkoutSession, log: SessionLog) -> SessionResult {
        let warmupGroups = Set(session.groups.filter(\.warmup).map(\.id))
        let working = log.sets.filter { !warmupGroups.contains($0.groupID) }
        let itemsByID = Dictionary(uniqueKeysWithValues: session.allExercises.map { ($0.id, $0) })

        let volume = working.reduce(0.0) { total, set in
            guard let load = set.load, let reps = set.reps, let item = itemsByID[set.plannedExerciseID] else { return total }
            let hands = item.exercise.loadKind == .dumbbellPair ? 2.0 : 1.0
            let sides = item.prescription.reps?.isPerSide == true ? 2.0 : 1.0
            return total + load * Double(reps) * hands * sides
        }
        let rated = working.compactMap(\.repsInReserve)
        let onTarget = rated.filter { $0 <= TrainingRules.effortTargetMaxReserve }.count
        let averageRest = log.restDurations.isEmpty
            ? nil
            : Int((Double(log.restDurations.reduce(0, +)) / Double(log.restDurations.count)).rounded())
        let planned = WorkoutEngine.makeSteps(for: session).count

        return SessionResult(
            sessionID: session.id,
            startedAt: log.startedAt,
            endedAt: log.endedAt,
            durationSeconds: max(0, Int(log.endedAt.timeIntervalSince(log.startedAt))),
            volume: volume,
            setsCompleted: log.sets.count,
            setsPlanned: planned,
            effortOnTarget: onTarget,
            effortRated: rated.count,
            averageRestSeconds: averageRest,
            highlights: highlights(session: session, sets: working),
            nextTargets: nextTargets(session: session, sets: working, readiness: log.readiness)
        )
    }

    static func setsByExercise(_ sets: [SetLog], in session: WorkoutSession) -> [(PlannedExercise, [SetLog])] {
        session.allExercises.compactMap { item in
            let logged = sets.filter { $0.plannedExerciseID == item.id }
            return logged.isEmpty ? nil : (item, logged)
        }
    }

    static func highlights(session: WorkoutSession, sets: [SetLog]) -> [SessionHighlight] {
        var records: [SessionHighlight] = []
        var others: [SessionHighlight] = []
        for (item, logged) in setsByExercise(sets, in: session) {
            guard let target = item.prescription.reps, item.prescription.load != nil else { continue }
            let reps = logged.compactMap(\.reps)
            let best = logged.compactMap { set -> (Double, Int, Double)? in
                guard let load = set.load, let reps = set.reps else { return nil }
                return (load, reps, Estimate.oneRepMax(load: load, reps: reps))
            }.max { $0.2 < $1.2 }

            if let best, let record = item.history?.bestEstimatedMax, best.2 > record {
                records.append(SessionHighlight(
                    exerciseName: item.exercise.name,
                    detail: "\(Format.weight(best.0)) × \(best.1)",
                    isPersonalRecord: true
                ))
            } else if item.exercise.isCoreLift, reps.count == item.prescription.sets, reps.allSatisfy({ $0 >= target.max }) {
                others.append(SessionHighlight(
                    exerciseName: item.exercise.name,
                    detail: reps.map(String.init).joined(separator: ",") + " · top of range",
                    isPersonalRecord: false
                ))
            }
        }
        return Array((records + others).prefix(3))
    }

    static func nextTargets(session: WorkoutSession, sets: [SetLog], readiness: ReadinessAnswers?) -> [NextTarget] {
        var increases: [NextTarget] = []
        var flagged: [NextTarget] = []
        for (item, logged) in setsByExercise(sets, in: session) {
            guard let target = item.prescription.reps, item.exercise.loadKind != .bodyweight,
                  let load = logged.compactMap(\.load).last
            else { continue }
            let reps = logged.compactMap(\.reps)
            let confirmed = logged.allSatisfy { $0.repsInReserve != nil }
            let hitTopEverySet = confirmed && reps.count >= item.prescription.sets && reps.allSatisfy { $0 >= target.max }
            let hitTopLastTime = item.history.map { !$0.lastReps.isEmpty && $0.lastReps.allSatisfy { $0 >= target.max } } ?? false
            let lightSets = reps.filter { $0 < target.min }.count

            if hitTopEverySet && hitTopLastTime && readiness?.holdsLoads != true {
                increases.append(NextTarget(
                    exerciseName: item.exercise.name,
                    direction: .increase,
                    load: load + TrainingRules.loadIncrement
                ))
            } else if lightSets > 0 {
                flagged.append(NextTarget(
                    exerciseName: item.exercise.name,
                    direction: .hold,
                    load: load,
                    note: lightSets == 1 ? "1 set light" : "\(lightSets) sets light"
                ))
            }
        }
        return increases + flagged
    }
}

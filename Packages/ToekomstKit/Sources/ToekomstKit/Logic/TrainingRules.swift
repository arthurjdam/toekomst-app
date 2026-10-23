import Foundation

/// Numbers from the program design rules, in one place.
public enum TrainingRules {
    /// Weekly hard sets per major muscle group.
    public static let weeklySetRange = 10...20
    /// Each muscle group should be trained in at least this many sessions a week.
    public static let minimumWeeklyHits = 2
    /// A working set counts as on target when it ends this many reps short of failure or closer.
    public static let effortTargetMaxReserve = 3
    /// Target bodyweight gain per week, in pounds.
    public static let weeklyGainRange = 0.25...0.5
    /// Sessions per week.
    public static let sessionsPerWeek = 4
    /// Default load step in pounds.
    public static let loadIncrement = 5.0
}

/// How a logged rep count compares to the target range.
public enum SetOutcome: Equatable, Sendable {
    case aboveRange, topOfRange, inRange, belowRange

    public init(reps: Int, target: RepTarget) {
        if reps > target.max {
            self = .aboveRange
        } else if reps == target.max {
            self = .topOfRange
        } else if reps >= target.min {
            self = .inRange
        } else {
            self = .belowRange
        }
    }
}

/// Evaluates a week's hard-set count for one muscle group.
public enum CoverageStatus: Equatable, Sendable {
    case under, onTarget, over

    public init(_ coverage: MuscleCoverage) {
        if coverage.hardSets < TrainingRules.weeklySetRange.lowerBound || coverage.hits < TrainingRules.minimumWeeklyHits {
            self = .under
        } else if coverage.hardSets > TrainingRules.weeklySetRange.upperBound {
            self = .over
        } else {
            self = .onTarget
        }
    }
}

public enum CoverageCalculator {
    /// Hard sets and hits per muscle group across the given sessions. Warm-up
    /// groups don't count; each circuit round counts as one set per move.
    public static func coverage(for sessions: [WorkoutSession]) -> [MuscleCoverage] {
        var sets: [MuscleGroup: Int] = [:]
        var hits: [MuscleGroup: Int] = [:]
        for session in sessions {
            var trained = Set<MuscleGroup>()
            for group in session.groups where !group.warmup {
                let multiplier = group.format == .circuit ? (group.rounds ?? 1) : 1
                for item in group.items {
                    let count = group.format == .circuit ? multiplier : item.prescription.sets
                    for muscle in item.exercise.muscles {
                        sets[muscle, default: 0] += count
                        trained.insert(muscle)
                    }
                }
            }
            for muscle in trained {
                hits[muscle, default: 0] += 1
            }
        }
        return MuscleGroup.allCases.map {
            MuscleCoverage(muscle: $0, hardSets: sets[$0] ?? 0, hits: hits[$0] ?? 0)
        }
    }
}

/// Plates to load on each side of a barbell.
public enum PlateCalculator {
    public static let standardBar = 45.0
    public static let availablePlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Plates per side, heaviest first. Nil if the load is below the bar or
    /// cannot be made exactly with the available plates.
    public static func platesPerSide(for total: Double, bar: Double = standardBar) -> [Double]? {
        guard total >= bar else { return nil }
        var remaining = (total - bar) / 2
        var plates: [Double] = []
        for plate in availablePlates {
            while remaining >= plate - 0.0001 {
                plates.append(plate)
                remaining -= plate
            }
        }
        return abs(remaining) < 0.0001 ? plates : nil
    }
}

public enum Estimate {
    /// Epley estimated one-rep max.
    public static func oneRepMax(load: Double, reps: Int) -> Double {
        guard reps > 1 else { return load }
        return load * (1 + Double(reps) / 30)
    }

    /// Least-squares slope of the points in pounds per week.
    public static func weeklyRate(_ points: [BodyweightPoint]) -> Double {
        guard points.count > 1, let first = points.first?.date else { return 0 }
        let xs = points.map { Double(first.days(until: $0.date)) / 7 }
        let ys = points.map(\.weight)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, ys) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        return denominator == 0 ? 0 : numerator / denominator
    }
}

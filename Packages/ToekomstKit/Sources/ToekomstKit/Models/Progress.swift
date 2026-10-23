import Foundation

public enum ProgressRange: String, Codable, CaseIterable, Sendable {
    case fourWeeks = "4w"
    case twelveWeeks = "12w"
    case all

    public var label: String {
        switch self {
        case .fourWeeks: return "4 wks"
        case .twelveWeeks: return "12 wks"
        case .all: return "All"
        }
    }

    /// Number of weeks covered, nil for everything on record.
    public var weeks: Int? {
        switch self {
        case .fourWeeks: return 4
        case .twelveWeeks: return 12
        case .all: return nil
        }
    }
}

public struct BodyweightPoint: Codable, Hashable, Sendable {
    public var date: LocalDate
    /// Weekly average bodyweight in pounds.
    public var weight: Double

    public init(date: LocalDate, weight: Double) {
        self.date = date
        self.weight = weight
    }
}

public struct BodyweightTrend: Codable, Hashable, Sendable {
    public var current: Double
    /// Trend in pounds per week over the selected range.
    public var weeklyChange: Double
    /// Target gain per week, from the program rules (+0.25 to +0.5 lb).
    public var targetWeeklyMin: Double
    public var targetWeeklyMax: Double
    public var points: [BodyweightPoint]

    public init(current: Double, weeklyChange: Double, targetWeeklyMin: Double, targetWeeklyMax: Double, points: [BodyweightPoint]) {
        self.current = current
        self.weeklyChange = weeklyChange
        self.targetWeeklyMin = targetWeeklyMin
        self.targetWeeklyMax = targetWeeklyMax
        self.points = points
    }

    public enum Pace: Equatable, Sendable {
        case belowTarget, onPace, aboveTarget
    }

    public var pace: Pace {
        if weeklyChange < targetWeeklyMin { return .belowTarget }
        if weeklyChange > targetWeeklyMax { return .aboveTarget }
        return .onPace
    }
}

public struct LiftPoint: Codable, Hashable, Sendable {
    public var date: LocalDate
    public var estimatedMax: Double
    public var blockNumber: Int

    public init(date: LocalDate, estimatedMax: Double, blockNumber: Int) {
        self.date = date
        self.estimatedMax = estimatedMax
        self.blockNumber = blockNumber
    }
}

/// Estimated one-rep max over time for one core lift.
public struct LiftTrend: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var points: [LiftPoint]

    public init(id: String, name: String, points: [LiftPoint]) {
        self.id = id
        self.name = name
        self.points = points
    }

    public var estimatedMax: Double { points.last?.estimatedMax ?? 0 }

    /// Change from the first to the last point, as a fraction (0.06 = +6%).
    public var change: Double {
        guard let first = points.first?.estimatedMax, first > 0, let last = points.last?.estimatedMax else { return 0 }
        return last / first - 1
    }

    /// Index of the first point of the latest block, for the block divider.
    public var latestBlockStartIndex: Int? {
        guard let latest = points.last?.blockNumber,
              let index = points.firstIndex(where: { $0.blockNumber == latest }), index > 0
        else { return nil }
        return index
    }
}

public struct VolumeEntry: Codable, Hashable, Identifiable, Sendable {
    public var muscle: MuscleGroup
    public var averageHardSets: Double

    public init(muscle: MuscleGroup, averageHardSets: Double) {
        self.muscle = muscle
        self.averageHardSets = averageHardSets
    }

    public var id: MuscleGroup { muscle }
}

public struct WeekCount: Codable, Hashable, Sendable {
    public var weekStart: LocalDate
    public var sessions: Int

    public init(weekStart: LocalDate, sessions: Int) {
        self.weekStart = weekStart
        self.sessions = sessions
    }
}

public struct Consistency: Codable, Hashable, Sendable {
    public var goalPerWeek: Int
    /// Oldest first; the last entry is the current, unfinished week.
    public var weeks: [WeekCount]

    public init(goalPerWeek: Int, weeks: [WeekCount]) {
        self.goalPerWeek = goalPerWeek
        self.weeks = weeks
    }

    /// Completed weeks only (the current week is still in progress).
    public var completedWeeks: [WeekCount] { Array(weeks.dropLast()) }

    public var completedSessions: Int { completedWeeks.reduce(0) { $0 + $1.sessions } }

    public var plannedSessions: Int { completedWeeks.count * goalPerWeek }
}

/// The Progress tab (`GET /progress?range=`).
public struct ProgressOverview: Codable, Hashable, Sendable {
    public var range: ProgressRange
    public var bodyweight: BodyweightTrend
    public var lifts: [LiftTrend]
    public var volume: [VolumeEntry]
    public var volumeWindowWeeks: Int
    public var consistency: Consistency

    public init(
        range: ProgressRange, bodyweight: BodyweightTrend, lifts: [LiftTrend], volume: [VolumeEntry],
        volumeWindowWeeks: Int, consistency: Consistency
    ) {
        self.range = range
        self.bodyweight = bodyweight
        self.lifts = lifts
        self.volume = volume
        self.volumeWindowWeeks = volumeWindowWeeks
        self.consistency = consistency
    }
}

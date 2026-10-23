import Foundation

/// The daily check-in: morning bodyweight and protein for the day.
public struct DailyCheckIn: Codable, Hashable, Sendable {
    public var date: LocalDate
    /// Bodyweight in pounds, nil until logged.
    public var bodyweight: Double?
    /// Protein eaten so far in grams, nil until logged.
    public var proteinGrams: Int?
    /// Daily protein target range in grams (0.8-1 g per lb of bodyweight).
    public var proteinTargetMin: Int
    public var proteinTargetMax: Int

    public init(date: LocalDate, bodyweight: Double?, proteinGrams: Int?, proteinTargetMin: Int, proteinTargetMax: Int) {
        self.date = date
        self.bodyweight = bodyweight
        self.proteinGrams = proteinGrams
        self.proteinTargetMin = proteinTargetMin
        self.proteinTargetMax = proteinTargetMax
    }

    public var proteinTargetMet: Bool {
        guard let proteinGrams else { return false }
        return proteinGrams >= proteinTargetMin
    }
}

/// Everything the Today screen needs in one call (`GET /today`).
public struct TodayOverview: Codable, Hashable, Sendable {
    public var date: LocalDate
    public var week: WeekSchedule
    /// Today's session, or nil on a rest day.
    public var session: WorkoutSession?
    /// The next session after today.
    public var upNext: UpcomingSession?
    public var checkIn: DailyCheckIn

    public init(date: LocalDate, week: WeekSchedule, session: WorkoutSession?, upNext: UpcomingSession?, checkIn: DailyCheckIn) {
        self.date = date
        self.week = week
        self.session = session
        self.upNext = upNext
        self.checkIn = checkIn
    }
}

public struct UpcomingSession: Codable, Hashable, Sendable {
    public var date: LocalDate
    public var session: SessionOverview

    public init(date: LocalDate, session: SessionOverview) {
        self.date = date
        self.session = session
    }
}

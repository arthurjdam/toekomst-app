import Foundation

/// A calendar day without a time or time zone, encoded as `"yyyy-MM-dd"`.
///
/// Training is planned per day, so the app never needs to reason about the
/// exact instant a session belongs to. Keeping days as plain values avoids the
/// usual off-by-one bugs when a `Date` crosses a time zone boundary.
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `"yyyy-MM-dd"`. Returns nil for malformed or impossible dates.
    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = Self.calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        // Reject dates the calendar silently rolled over, such as 2026-02-31.
        let check = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public static func today(in timeZone: TimeZone = .current) -> LocalDate {
        LocalDate(Date(), in: timeZone)
    }

    // All arithmetic happens at midnight UTC, where days are always 24 hours.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var midnightUTC: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> LocalDate {
        LocalDate(Self.calendar.date(byAdding: .day, value: days, to: midnightUTC)!, in: Self.calendar.timeZone)
    }

    /// Whole days from `self` to `other`; negative when `other` is earlier.
    public func days(until other: LocalDate) -> Int {
        Self.calendar.dateComponents([.day], from: midnightUTC, to: other.midnightUTC).day!
    }

    public var weekday: Weekday {
        // Calendar weekdays run Sunday = 1 ... Saturday = 7; ISO runs Monday = 1 ... Sunday = 7.
        let sundayFirst = Self.calendar.component(.weekday, from: midnightUTC)
        return Weekday(rawValue: (sundayFirst + 5) % 7 + 1)!
    }

    /// The Monday of the week this day belongs to.
    public var startOfWeek: LocalDate {
        adding(days: -(weekday.rawValue - 1))
    }

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var shortMonthName: String {
        Self.monthNames[month - 1]
    }

    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension LocalDate: CustomStringConvertible {
    public var description: String { isoString }
}

extension LocalDate: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = LocalDate(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected yyyy-MM-dd, got \(string)")
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

/// ISO weekday: Monday = 1 ... Sunday = 7.
public enum Weekday: Int, CaseIterable, Codable, Comparable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public var shortName: String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][rawValue - 1]
    }

    public var fullName: String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][rawValue - 1]
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

import Foundation

/// Display formatting shared by every screen. Kept here, rather than in the
/// views, so the exact strings are covered by tests.
public enum Format {
    /// "2:00", "0:45", "56:12". Negative values format as their magnitude.
    public static func clock(_ seconds: Int) -> String {
        let value = abs(seconds)
        return "\(value / 60):" + String(format: "%02d", value % 60)
    }

    /// "185", "182.4", "2.5": no trailing ".0".
    public static func weight(_ pounds: Double) -> String {
        let rounded = (pounds * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    /// "+5", "-10", "+2.5".
    public static func signedWeight(_ pounds: Double) -> String {
        (pounds >= 0 ? "+" : "-") + weight(abs(pounds))
    }

    /// "14,820".
    public static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? String(Int(value.rounded()))
    }

    /// "Thu 22 Oct".
    public static func dayHeader(_ date: LocalDate) -> String {
        "\(date.weekday.shortName) \(date.day) \(date.shortMonthName)"
    }

    /// "Oct 19-25" or "Oct 26-Nov 1" across a month boundary.
    public static func weekRange(_ weekStart: LocalDate) -> String {
        let end = weekStart.adding(days: 6)
        if end.month == weekStart.month {
            return "\(weekStart.shortMonthName) \(weekStart.day)-\(end.day)"
        }
        return "\(weekStart.shortMonthName) \(weekStart.day)-\(end.shortMonthName) \(end.day)"
    }

    /// "4 × 6-8 · 185 lb · 2:00", "5:00 · conversational pace", "3 × 12 · bodyweight · 0:45".
    public static func prescription(_ prescription: Prescription, loadKind: LoadKind, includeRest: Bool) -> String {
        var parts: [String] = []
        if let reps = prescription.reps {
            parts.append("\(prescription.sets) × \(reps.display)")
        } else if let duration = prescription.durationSeconds {
            parts.append(prescription.sets > 1 ? "\(prescription.sets) × \(clock(duration))" : clock(duration))
        }
        if let load = prescription.load {
            parts.append("\(weight(load)) lb")
        } else if loadKind == .bodyweight {
            parts.append("bodyweight")
        }
        if let note = prescription.note {
            parts.append(note)
        }
        if includeRest, let rest = prescription.restSeconds {
            parts.append(clock(rest))
        }
        return parts.joined(separator: " · ")
    }

    /// "180 × 8,8,8,8".
    public static func lastPerformance(_ history: ExerciseHistory) -> String? {
        guard !history.lastReps.isEmpty else { return nil }
        let reps = history.lastReps.map(String.init).joined(separator: ",")
        if let load = history.lastLoad {
            return "\(weight(load)) × \(reps)"
        }
        return reps
    }
}

import Foundation

/// Orders a week's sessions over the chosen training days so the same muscles
/// get a rest day between hard sessions.
///
/// The person picks the days; the planner picks which session lands on which
/// day. Back-to-back days are only a problem when both sessions load the same
/// muscles: lower mass next to a full-body circuit, two circuits, or two
/// sessions of the same kind.
public enum WeekPlanner {
    public struct Plan<Session> {
        /// Selected days, Monday first.
        public var days: [Weekday]
        /// The session for each of `days`, in the same order. Empty unless `status` is ready.
        public var sessions: [Session]
        /// Indices `i` where `days[i]` and `days[i + 1]` are consecutive and clash.
        public var clashes: [Int]
        public var status: Status
    }

    public enum Status: Equatable, Sendable {
        /// Fewer days picked than sessions to place.
        case needMore(Int)
        /// More days picked than sessions to place.
        case tooMany(Int)
        /// No clashes and no long runs of consecutive days.
        case good
        /// No clashes, but `run` consecutive training days (3 or more).
        case longRun(Int)
        /// Two sessions that load the same muscles fall on consecutive days.
        case tight(Weekday, Weekday)

        public var isReady: Bool {
            switch self {
            case .needMore, .tooMany: return false
            case .good, .longRun, .tight: return true
            }
        }
    }

    /// Whether two sessions on consecutive days leave a muscle group without rest.
    public static func clashes(_ first: SessionKind, _ second: SessionKind) -> Bool {
        switch (first, second) {
        case (.lowerMass, .conditioning), (.conditioning, .lowerMass): return true
        case (.conditioning, .conditioning), (.lowerMass, .lowerMass), (.upperMass, .upperMass): return true
        default: return false
        }
    }

    /// Plans `sessions` over `days`. Among the orderings with the fewest clashes,
    /// the one closest to the given session order wins, so a plan that already
    /// works is never shuffled.
    public static func plan<Session>(
        days: [Weekday], sessions: [Session], kind: (Session) -> SessionKind
    ) -> Plan<Session> {
        let days = Array(Set(days)).sorted()
        guard days.count == sessions.count else {
            let status: Status = days.count < sessions.count
                ? .needMore(sessions.count - days.count)
                : .tooMany(days.count - sessions.count)
            return Plan(days: days, sessions: [], clashes: [], status: status)
        }

        var best: (order: [Int], clashes: [Int])?
        var seenKindSequences = Set<[SessionKind]>()
        for order in permutations(of: Array(sessions.indices)) {
            let kinds = order.map { kind(sessions[$0]) }
            guard seenKindSequences.insert(kinds).inserted else { continue }
            let found = clashIndices(days: days, kinds: kinds)
            if best == nil || found.count < best!.clashes.count {
                best = (order, found)
            }
            if found.isEmpty { break }
        }

        let chosen = best ?? (Array(sessions.indices), [])
        let ordered = chosen.order.map { sessions[$0] }
        let status: Status
        if let first = chosen.clashes.first {
            status = .tight(days[first], days[first + 1])
        } else {
            let run = longestRun(of: days)
            status = run >= 3 ? .longRun(run) : .good
        }
        return Plan(days: days, sessions: ordered, clashes: chosen.clashes, status: status)
    }

    /// Evaluates an order the person arranged by hand: `sessions[i]` lands on
    /// the i-th selected day, Monday first.
    public static func evaluate<Session>(
        days: [Weekday], sessions: [Session], kind: (Session) -> SessionKind
    ) -> Plan<Session> {
        let days = Array(Set(days)).sorted()
        guard days.count == sessions.count else {
            return plan(days: days, sessions: sessions, kind: kind)
        }
        let found = clashIndices(days: days, kinds: sessions.map(kind))
        let status: Status
        if let first = found.first {
            status = .tight(days[first], days[first + 1])
        } else {
            let run = longestRun(of: days)
            status = run >= 3 ? .longRun(run) : .good
        }
        return Plan(days: days, sessions: sessions, clashes: found, status: status)
    }

    static func clashIndices(days: [Weekday], kinds: [SessionKind]) -> [Int] {
        guard days.count > 1 else { return [] }
        return (0..<(days.count - 1)).filter { index in
            days[index + 1].rawValue - days[index].rawValue == 1 && clashes(kinds[index], kinds[index + 1])
        }
    }

    static func longestRun(of days: [Weekday]) -> Int {
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<days.count {
            current = days[index].rawValue - days[index - 1].rawValue == 1 ? current + 1 : 1
            longest = max(longest, current)
        }
        return longest
    }

    /// All orderings, starting with the identity, in lexicographic order of positions.
    static func permutations(of items: [Int]) -> [[Int]] {
        guard items.count > 1 else { return [items] }
        var result: [[Int]] = []
        for (index, item) in items.enumerated() {
            var rest = items
            rest.remove(at: index)
            for tail in permutations(of: rest) {
                result.append([item] + tail)
            }
        }
        return result
    }
}

import Foundation

/// A `TrainingRepository` backed by the JSON files in `Fixtures/`.
///
/// It behaves like a small in-memory back-end: weeks are generated from the
/// weekly template and the chosen training days, writes (week plans, moves,
/// check-ins, logged sessions) change what later reads return, and nothing is
/// persisted between launches.
public actor FixtureTrainingRepository: TrainingRepository {
    private var program: ProgramFixture
    private let exercises: [String: Exercise]
    private let definitions: [String: SessionDefinition]
    private var history: [LocalDate: HistoryEntry]
    private var checkIns: [LocalDate: DailyCheckIn]
    private let progressFixture: ProgressFixture
    /// Week plans saved for a specific week.
    private var weekPlans: [LocalDate: WeekPlanRequest] = [:]
    /// Training days saved with "use every week", keyed by the first week they apply to.
    private var repeatingDays: [LocalDate: [Weekday]] = [:]
    /// Moved sessions per week: original date -> new date.
    private var moves: [LocalDate: [LocalDate: LocalDate]] = [:]
    private var feedback: [SessionFeedback] = []
    private let latencyNanoseconds: UInt64

    /// The day fixture data is anchored to. The app treats this as "today".
    public nonisolated let today: LocalDate

    /// Loads the fixtures bundled with ToekomstKit.
    /// - Parameter latency: Simulated network delay per call, in seconds.
    public init(latency: TimeInterval = 0) throws {
        try self.init(bundle: .module, latency: latency)
    }

    init(bundle: Bundle, latency: TimeInterval) throws {
        let program: ProgramFixture = try Self.load("program", from: bundle)
        let exercises: [Exercise] = try Self.load("exercises", from: bundle)
        let sessions: [SessionDefinition] = try Self.load("sessions", from: bundle)
        let history: [HistoryEntry] = try Self.load("history", from: bundle)
        let checkIns: [DailyCheckIn] = try Self.load("checkins", from: bundle)
        self.program = program
        self.today = program.today
        self.exercises = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        self.definitions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        self.history = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        self.checkIns = Dictionary(uniqueKeysWithValues: checkIns.map { ($0.date, $0) })
        self.progressFixture = try Self.load("progress", from: bundle)
        self.latencyNanoseconds = UInt64(max(0, latency) * 1_000_000_000)

        for template in program.weekTemplate where definitions[template.id] == nil {
            throw RepositoryError.notFound("session template \(template.id)")
        }
    }

    static func load<T: Decodable>(_ name: String, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw RepositoryError.notFound("fixture \(name).json")
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private func simulateLatency() async {
        if latencyNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: latencyNanoseconds)
        }
    }

    // MARK: - TrainingRepository

    public func today() async throws -> TodayOverview {
        await simulateLatency()
        let week = makeWeek(startingOn: today.startOfWeek)
        let session = try assignedTemplate(on: today).map { try makeSession(templateID: $0, date: today) }
        return TodayOverview(
            date: today,
            week: week,
            session: session,
            upNext: upcomingSession(after: today),
            checkIn: checkIns[today] ?? emptyCheckIn(on: today)
        )
    }

    public func week(starting weekStart: LocalDate) async throws -> WeekSchedule {
        await simulateLatency()
        return makeWeek(startingOn: weekStart.startOfWeek)
    }

    public func scheduleBounds() async throws -> ClosedRange<LocalDate> {
        program.firstWeek.startOfWeek...today.startOfWeek.adding(days: 7 * program.weeksAhead)
    }

    public func weekPlanDraft(for weekStart: LocalDate) async throws -> WeekPlanDraft {
        await simulateLatency()
        let weekStart = weekStart.startOfWeek
        return WeekPlanDraft(
            weekStart: weekStart,
            templates: program.weekTemplate,
            selectedDays: trainingDays(forWeekStarting: weekStart),
            repeatEveryWeek: weekPlans[weekStart]?.repeatEveryWeek ?? false
        )
    }

    public func saveWeekPlan(_ request: WeekPlanRequest) async throws -> WeekSchedule {
        await simulateLatency()
        let weekStart = request.weekStart.startOfWeek
        guard weekStart.adding(days: 6) >= today else {
            throw RepositoryError.invalidRequest("Past weeks can't be changed.")
        }
        guard request.trainingDays.count == program.weekTemplate.count,
              Set(request.sessionOrder) == Set(program.weekTemplate.map(\.id)),
              request.sessionOrder.count == request.trainingDays.count
        else {
            throw RepositoryError.invalidRequest("Pick \(program.weekTemplate.count) training days.")
        }
        weekPlans[weekStart] = request
        moves[weekStart] = nil
        if request.repeatEveryWeek {
            repeatingDays[weekStart] = request.trainingDays.sorted()
        }
        return makeWeek(startingOn: weekStart)
    }

    public func session(id: String) async throws -> WorkoutSession {
        await simulateLatency()
        let parts = id.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, let date = LocalDate(parts[1]) else {
            throw RepositoryError.notFound("session \(id)")
        }
        return try makeSession(templateID: parts[0], date: date)
    }

    public func moveSession(id: String, to date: LocalDate) async throws -> WeekSchedule {
        await simulateLatency()
        let parts = id.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, let from = LocalDate(parts[1]), assignedTemplate(on: from) == parts[0] else {
            throw RepositoryError.notFound("session \(id)")
        }
        let weekStart = from.startOfWeek
        guard date.startOfWeek == weekStart else {
            throw RepositoryError.invalidRequest("Sessions can only move within their week.")
        }
        guard date >= today, from >= today else {
            throw RepositoryError.invalidRequest("Only upcoming sessions can move to upcoming days.")
        }
        guard assignedTemplate(on: date) == nil else {
            throw RepositoryError.invalidRequest("\(date.weekday.fullName) already has a session.")
        }
        var weekMoves = moves[weekStart] ?? [:]
        // If this session was already moved, update the original entry instead of chaining.
        let original = weekMoves.first(where: { $0.value == from })?.key ?? from
        weekMoves[original] = original == date ? nil : date
        moves[weekStart] = weekMoves
        return makeWeek(startingOn: weekStart)
    }

    public func saveCheckIn(_ checkIn: DailyCheckIn) async throws -> DailyCheckIn {
        await simulateLatency()
        checkIns[checkIn.date] = checkIn
        return checkIn
    }

    public func progress(range: ProgressRange) async throws -> ProgressOverview {
        await simulateLatency()
        let since = range.weeks.map { today.adding(days: -7 * $0) }
        let inRange: (LocalDate) -> Bool = { date in since.map { date >= $0 } ?? true }

        var weights = progressFixture.bodyweight.filter { inRange($0.date) && $0.date <= today }
        if let logged = checkIns[today]?.bodyweight {
            weights.removeAll { $0.date == today }
            weights.append(BodyweightPoint(date: today, weight: logged))
        }
        let bodyweight = BodyweightTrend(
            current: weights.last?.weight ?? 0,
            weeklyChange: Estimate.weeklyRate(weights),
            targetWeeklyMin: progressFixture.targetWeeklyGainMin,
            targetWeeklyMax: progressFixture.targetWeeklyGainMax,
            points: weights
        )
        let lifts = progressFixture.lifts.map { lift in
            LiftTrend(id: lift.id, name: lift.name, points: lift.points.filter { inRange($0.date) })
        }
        return ProgressOverview(
            range: range,
            bodyweight: bodyweight,
            lifts: lifts,
            volume: progressFixture.volume,
            volumeWindowWeeks: progressFixture.volumeWindowWeeks,
            consistency: progressFixture.consistency
        )
    }

    public func logSession(_ log: SessionLog) async throws -> SessionResult {
        await simulateLatency()
        let session = try await session(id: log.sessionID)
        let result = SessionResultBuilder.build(session: session, log: log)
        let parts = log.sessionID.split(separator: "@", maxSplits: 1).map(String.init)
        history[session.date] = HistoryEntry(
            date: session.date,
            templateId: parts[0],
            status: .completed,
            actualMinutes: Int((Double(result.durationSeconds) / 60).rounded())
        )
        return result
    }

    public func submitFeedback(_ feedback: SessionFeedback) async throws {
        await simulateLatency()
        guard (1...5).contains(feedback.difficulty) else {
            throw RepositoryError.invalidRequest("Difficulty runs from 1 to 5.")
        }
        self.feedback.append(feedback)
    }

    // MARK: - Week generation

    private func trainingDays(forWeekStarting weekStart: LocalDate) -> [Weekday] {
        if let plan = weekPlans[weekStart] {
            return plan.trainingDays.sorted()
        }
        let repeating = repeatingDays.filter { $0.key <= weekStart }.max { $0.key < $1.key }
        return repeating?.value ?? program.defaultTrainingDays
    }

    /// Template id per date for one week, after planning and moves.
    private func assignments(forWeekStarting weekStart: LocalDate) -> [LocalDate: String] {
        var result: [LocalDate: String] = [:]
        if let plan = weekPlans[weekStart] {
            for (day, templateID) in zip(plan.trainingDays.sorted(), plan.sessionOrder) {
                result[weekStart.adding(days: day.rawValue - 1)] = templateID
            }
        } else {
            let plan = WeekPlanner.plan(
                days: trainingDays(forWeekStarting: weekStart),
                sessions: program.weekTemplate,
                kind: \.kind
            )
            for (day, template) in zip(plan.days, plan.sessions) {
                result[weekStart.adding(days: day.rawValue - 1)] = template.id
            }
        }
        // History wins for days already trained.
        for (date, entry) in history where date.startOfWeek == weekStart {
            result[date] = entry.templateId
        }
        for (from, to) in moves[weekStart] ?? [:] {
            if let templateID = result.removeValue(forKey: from) {
                result[to] = templateID
            }
        }
        return result
    }

    private func assignedTemplate(on date: LocalDate) -> String? {
        assignments(forWeekStarting: date.startOfWeek)[date]
    }

    private func blockPosition(for date: LocalDate) -> BlockPosition {
        let block = program.block
        let weeksFromStart = Int((Double(block.startDate.startOfWeek.days(until: date.startOfWeek)) / 7).rounded(.down))
        let blockOffset = Int((Double(weeksFromStart) / Double(block.weeksInBlock)).rounded(.down))
        return BlockPosition(
            blockNumber: block.blockNumber + blockOffset,
            week: weeksFromStart - blockOffset * block.weeksInBlock + 1,
            weeksInBlock: block.weeksInBlock,
            phase: block.phase
        )
    }

    private func status(on date: LocalDate) -> SessionStatus {
        if let entry = history[date] { return entry.status }
        // Fixture weeks before today are treated as trained unless history says otherwise.
        return date < today ? .completed : .planned
    }

    private func overview(templateID: String, date: LocalDate) -> SessionOverview? {
        guard let definition = definitions[templateID] else { return nil }
        let status = status(on: date)
        return SessionOverview(
            id: "\(templateID)@\(date.isoString)",
            kind: definition.kind,
            title: definition.title,
            estimatedMinutes: definition.estimatedMinutes,
            status: status,
            actualMinutes: status == .completed ? (history[date]?.actualMinutes ?? definition.estimatedMinutes) : nil
        )
    }

    private func makeWeek(startingOn weekStart: LocalDate) -> WeekSchedule {
        let assigned = assignments(forWeekStarting: weekStart)
        let days = (0..<7).map { offset -> ScheduledDay in
            let date = weekStart.adding(days: offset)
            return ScheduledDay(date: date, session: assigned[date].flatMap { overview(templateID: $0, date: date) })
        }
        let sessions = days.compactMap { day in
            day.session.flatMap { try? makeSession(templateID: String($0.id.split(separator: "@")[0]), date: day.date) }
        }
        let coverage = CoverageCalculator.coverage(for: sessions)
        return WeekSchedule(
            weekStart: weekStart,
            block: blockPosition(for: weekStart),
            days: days,
            coverage: coverage,
            coverageNote: coverageNote(coverage),
            isEditable: weekStart.adding(days: 6) >= today
        )
    }

    private func coverageNote(_ coverage: [MuscleCoverage]) -> String {
        let under = coverage.filter { CoverageStatus($0) == .under }.map(\.muscle)
        let range = TrainingRules.weeklySetRange
        guard !under.isEmpty else {
            return "Every muscle group gets \(range.lowerBound)-\(range.upperBound) hard sets over at least \(TrainingRules.minimumWeeklyHits) sessions."
        }
        let names = under.enumerated().map { $0.offset == 0 ? $0.element.displayName : $0.element.displayName.lowercased() }
        let list = names.count == 1 ? names[0] : names.dropLast().joined(separator: ", ") + " and " + names.last!
        let verb = under.count == 1 && !under[0].isPlural ? "is" : "are"
        return "\(list) \(verb) under \(range.lowerBound) hard sets this week."
    }

    // MARK: - Sessions

    private func makeSession(templateID: String, date: LocalDate) throws -> WorkoutSession {
        guard let definition = definitions[templateID] else {
            throw RepositoryError.notFound("session template \(templateID)")
        }
        let groups = try definition.groups.map { group in
            ExerciseGroup(
                id: group.id,
                title: group.title,
                format: group.format,
                estimatedMinutes: group.estimatedMinutes,
                isWarmup: group.isWarmup ?? false,
                rounds: group.rounds,
                transitionSeconds: group.transitionSeconds,
                roundRestSeconds: group.roundRestSeconds,
                items: try group.items.map { item in
                    guard let exercise = exercises[item.exercise] else {
                        throw RepositoryError.notFound("exercise \(item.exercise)")
                    }
                    return PlannedExercise(
                        id: item.id,
                        exercise: exercise,
                        prescription: item.prescription,
                        progression: item.progression,
                        history: item.history,
                        setup: item.setup,
                        sideNote: item.sideNote
                    )
                }
            )
        }
        return WorkoutSession(
            id: "\(templateID)@\(date.isoString)",
            date: date,
            kind: definition.kind,
            title: definition.title,
            estimatedMinutes: definition.estimatedMinutes,
            block: blockPosition(for: date),
            status: status(on: date),
            progressionNote: definition.progressionNote,
            previousSessionDate: previousSessionDate(before: date),
            equipment: definition.equipment,
            groups: groups
        )
    }

    private func previousSessionDate(before date: LocalDate) -> LocalDate? {
        for offset in 1...14 where assignedTemplate(on: date.adding(days: -offset)) != nil {
            return date.adding(days: -offset)
        }
        return nil
    }

    private func upcomingSession(after date: LocalDate) -> UpcomingSession? {
        for offset in 1...14 {
            let day = date.adding(days: offset)
            if let templateID = assignedTemplate(on: day), let overview = overview(templateID: templateID, date: day) {
                return UpcomingSession(date: day, session: overview)
            }
        }
        return nil
    }

    private func emptyCheckIn(on date: LocalDate) -> DailyCheckIn {
        DailyCheckIn(
            date: date,
            bodyweight: nil,
            proteinGrams: nil,
            proteinTargetMin: program.proteinTarget.min,
            proteinTargetMax: program.proteinTarget.max
        )
    }
}

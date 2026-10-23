import SwiftUI
import ToekomstKit

enum AppTab: Hashable, CaseIterable {
    case today, schedule, progress, settings

    var title: String {
        switch self {
        case .today: return "Today"
        case .schedule: return "Schedule"
        case .progress: return "Progress"
        case .settings: return "Settings"
        }
    }

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var glyph: GlyphKind {
        switch self {
        case .today: return .tabToday
        case .schedule: return .tabSchedule
        case .progress: return .tabProgress
        case .settings: return .tabSettings
        }
    }
}

/// Destinations pushed onto a tab's navigation stack.
enum Route: Hashable {
    /// Session preview; `backTitle` labels the custom back button.
    case session(id: String, backTitle: String)
    case lift(LiftTrend)
}

/// App-wide state: the repository, Today's data, the running workout.
@Observable
@MainActor
final class AppModel {
    var selectedTab: AppTab = .today
    private(set) var repository: any TrainingRepository
    private(set) var today: LoadState<TodayOverview> = .loading
    /// Bumped after every write so screens showing other data reload.
    private(set) var dataVersion = 0
    var activeWorkout: WorkoutPlayerModel?
    /// Next week's day picker, opened from Settings or Schedule.
    var weekPlanTarget: WeekPlanTarget?
    let settings: AppSettings

    init(repository: any TrainingRepository, settings: AppSettings) {
        self.repository = repository
        self.settings = settings
    }

    /// Fixture-backed model, used by the app until the back-end exists.
    static func fixtures() -> AppModel {
        AppModel(repository: makeFixtureRepository(), settings: AppSettings())
    }

    private static func makeFixtureRepository() -> any TrainingRepository {
        do {
            return try FixtureTrainingRepository(latency: 0.25)
        } catch {
            // The fixtures ship inside the app; failing to load them is a build problem.
            fatalError("Couldn't load bundled fixtures: \(error)")
        }
    }

    func loadToday() async {
        do {
            let loaded = try await repository.today()
            withAnimation(Motion.flat) { today = .loaded(loaded) }
        } catch {
            today = .failed(error.localizedDescription)
        }
    }

    /// Call after any write: reloads Today and tells other screens to refresh.
    func dataDidChange() async {
        dataVersion += 1
        await loadToday()
    }

    func startWorkout(_ session: WorkoutSession) {
        activeWorkout = WorkoutPlayerModel(
            session: session,
            repository: repository,
            autoStartAfterRest: settings.autoStartAfterRest
        )
    }

    /// Called when the workout cover closes, finished or not.
    func workoutDidClose() {
        activeWorkout = nil
        Task { await dataDidChange() }
    }

    func resetFixtureData() async {
        repository = Self.makeFixtureRepository()
        today = .loading
        await dataDidChange()
    }
}

/// What the week planner sheet edits.
struct WeekPlanTarget: Identifiable, Hashable {
    let weekStart: LocalDate
    var id: LocalDate { weekStart }
}

/// Preferences, stored in UserDefaults.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var accent: AccentTheme {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }

    /// Open the next set automatically when rest reaches 0:00.
    var autoStartAfterRest: Bool {
        didSet { defaults.set(autoStartAfterRest, forKey: Keys.autoStart) }
    }

    var keepScreenOn: Bool {
        didSet { defaults.set(keepScreenOn, forKey: Keys.keepScreenOn) }
    }

    var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Keys.haptics) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accent = AccentTheme(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .volt
        autoStartAfterRest = defaults.object(forKey: Keys.autoStart) as? Bool ?? true
        keepScreenOn = defaults.object(forKey: Keys.keepScreenOn) as? Bool ?? true
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    }

    private enum Keys {
        static let accent = "settings.accent"
        static let autoStart = "settings.autoStartAfterRest"
        static let keepScreenOn = "settings.keepScreenOn"
        static let haptics = "settings.haptics"
    }
}

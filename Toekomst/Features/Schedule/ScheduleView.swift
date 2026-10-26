import SwiftUI
import ToekomstKit

struct ScheduleView: View {
    @Environment(AppModel.self) private var model
    @State private var weekStart: LocalDate?
    @State private var bounds: ClosedRange<LocalDate>?
    @State private var state: LoadState<WeekSchedule> = .loading
    /// Direction of the last week change, so pages slide the way the arrows point.
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var today: LocalDate? { model.today.value?.date }

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingView().transition(.opacity)
            case .failed(let message):
                LoadingView(message: message) { Task { await load() } }
                    .transition(.opacity)
            case .loaded(let week):
                content(week).transition(.opacity)
            }
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .animation(Motion.flat, value: state.phase)
        .task(id: TaskKey(week: weekStart, version: model.dataVersion, today: today)) { await load() }
    }

    private struct TaskKey: Equatable {
        let week: LocalDate?
        let version: Int
        let today: LocalDate?
    }

    private func load() async {
        guard let today else { return }
        do {
            if bounds == nil {
                bounds = try await model.repository.scheduleBounds()
            }
            let week = try await model.repository.week(starting: weekStart ?? today.startOfWeek)
            withAnimation(Motion.page) { state = .loaded(week) }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func content(_ week: WeekSchedule) -> some View {
        ScreenScroll {
            header(week)
            VStack(alignment: .leading, spacing: 24) {
                daysCard(week)
                VStack(spacing: 8) {
                    ForEach(week.days) { day in
                        DayRow(day: day, today: today ?? day.date)
                    }
                }
                MuscleCoverageCard(coverage: week.coverage, note: week.coverageNote)
            }
            // A new week is a new page; changes within a week animate in place.
            .id(week.weekStart)
            .transition(.flatPush(forward: forward, reduceMotion: reduceMotion))
        }
        .refreshable { await load() }
    }

    private func header(_ week: WeekSchedule) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Block \(week.block.blockNumber) · Week \(week.block.week) of \(week.block.weeksInBlock)")
                    .textStyle(.label).foregroundStyle(Palette.ink2)
                    .wipe(on: week.block)
                Text(Format.weekRange(week.weekStart)).textStyle(.titleL).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .wipe(on: week.weekStart)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { step(week, by: -1) } label: { Glyph(.chevronLeft, size: 20) }
                    .buttonStyle(IconButtonStyle())
                    .disabled(!canStep(week, by: -1))
                    .opacity(canStep(week, by: -1) ? 1 : 0.38)
                    .accessibilityLabel("Previous week")
                Button { step(week, by: 1) } label: { Glyph(.chevronRight, size: 20) }
                    .buttonStyle(IconButtonStyle())
                    .disabled(!canStep(week, by: 1))
                    .opacity(canStep(week, by: 1) ? 1 : 0.38)
                    .accessibilityLabel("Next week")
            }
        }
    }

    private func canStep(_ week: WeekSchedule, by weeks: Int) -> Bool {
        guard let bounds else { return false }
        return bounds.contains(week.weekStart.adding(days: 7 * weeks))
    }

    private func step(_ week: WeekSchedule, by weeks: Int) {
        forward = weeks > 0
        weekStart = week.weekStart.adding(days: 7 * weeks)
    }

    /// The week the day picker edits: next week while this one is underway.
    private func planTarget(for week: WeekSchedule) -> LocalDate? {
        guard let today, week.isEditable else { return nil }
        return week.weekStart <= today ? week.weekStart.adding(days: 7) : week.weekStart
    }

    private func daysCard(_ week: WeekSchedule) -> some View {
        let target = planTarget(for: week)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Training days this week").textStyle(.label).foregroundStyle(Palette.ink2)
                Text(week.trainingDays.map(\.shortName).joined(separator: " · "))
                    .textStyle(.headline).foregroundStyle(Palette.ink)
                    .wipe(on: week.trainingDays)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let target {
                Button(target == week.weekStart ? "Change days" : "Plan next week") {
                    model.weekPlanTarget = WeekPlanTarget(weekStart: target)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct DayRow: View {
    let day: ScheduledDay
    let today: LocalDate
    @Environment(\.theme) private var theme

    var body: some View {
        if let session = day.session {
            HStack(alignment: .center, spacing: 12) {
                dateColumn
                NavigationLink(value: Route.session(id: session.id, backTitle: "Schedule")) {
                    card(session)
                }
                .buttonStyle(PressableStyle())
            }
        } else {
            HStack(spacing: 12) {
                Text(day.date.weekday.shortName).textStyle(.label).foregroundStyle(Palette.ink3)
                    .frame(width: 40)
                Text("Rest").textStyle(.footnote).foregroundStyle(Palette.ink3)
                Hairline()
            }
            .frame(height: 36)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.date.weekday.fullName), rest")
        }
    }

    private var isToday: Bool { day.date == today }

    private var dateColumn: some View {
        VStack(spacing: 0) {
            Text(day.date.weekday.shortName).textStyle(.label)
                .foregroundStyle(isToday ? Palette.ink : Palette.ink3)
            Text("\(day.date.day)").textStyle(.metricM)
                .foregroundStyle(isToday ? Palette.ink : Palette.ink2)
        }
        .frame(width: 40)
        .accessibilityHidden(true)
    }

    private func card(_ session: SessionOverview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                KindBadge(kind: session.kind)
                Spacer()
                status(session).wipe(on: session.status)
            }
            Text(session.title).textStyle(.headline).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, isToday ? 14 : 16)
        .padding(.vertical, isToday ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isToday && session.status == .planned {
                RoundedRectangle(cornerRadius: 16).strokeBorder(theme.signal, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.date.weekday.fullName) \(day.date.day), \(session.kind.displayName), \(session.title)")
    }

    @ViewBuilder
    private func status(_ session: SessionOverview) -> some View {
        switch session.status {
        case .completed:
            Text("✓ Done" + (session.actualMinutes.map { " · \($0) min" } ?? ""))
                .textStyle(.label).foregroundStyle(Palette.positive)
        case .missed:
            Text("✕ Missed").textStyle(.label).foregroundStyle(Palette.negative)
        case .planned:
            if isToday {
                Text("Today · ~\(session.estimatedMinutes) min").textStyle(.label).foregroundStyle(theme.signal)
            } else {
                Text("~\(session.estimatedMinutes) min").textStyle(.label).foregroundStyle(Palette.ink2)
            }
        }
    }
}

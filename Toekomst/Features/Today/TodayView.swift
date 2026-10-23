import SwiftUI
import ToekomstKit

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showCheckIn = false

    var body: some View {
        switch model.today {
        case .loading:
            LoadingView().background(Palette.bg).toolbar(.hidden, for: .navigationBar)
        case .failed(let message):
            LoadingView(message: message) { Task { await model.loadToday() } }
                .background(Palette.bg).toolbar(.hidden, for: .navigationBar)
        case .loaded(let today):
            ScreenScroll(spacing: 20) {
                header(today)
                if let session = today.session {
                    SessionCard(session: session, actualMinutes: today.week.days.first { $0.date == today.date }?.session?.actualMinutes)
                } else {
                    RestDayCard(upNext: today.upNext)
                }
                WeekStrip(week: today.week, today: today.date)
                links(today)
            }
            .refreshable { await model.loadToday() }
            .sheet(isPresented: $showCheckIn) {
                CheckInSheet(checkIn: today.checkIn)
            }
        }
    }

    private func header(_ today: TodayOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Format.dayHeader(today.date)).textStyle(.label).foregroundStyle(Palette.ink2)
            Text("Today").textStyle(.titleL).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                Text("Block \(today.week.block.blockNumber) · Week \(today.week.block.week) of \(today.week.block.weeksInBlock)")
                    .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink2)
                Badge(text: today.week.block.phase)
            }
        }
    }

    private func links(_ today: TodayOverview) -> some View {
        VStack(spacing: 0) {
            Button {
                showCheckIn = true
            } label: {
                LinkRow(glyph: .scale, eyebrow: nil, title: "Daily check-in", subtitle: checkInSummary(today.checkIn))
            }
            .buttonStyle(PressableStyle())

            if let upNext = today.upNext {
                Hairline()
                Button {
                    model.selectedTab = .schedule
                } label: {
                    LinkRow(
                        glyph: upNext.session.kind == .conditioning ? .bolt : .tabSchedule,
                        eyebrow: "Up next · \(upNext.date.weekday.shortName) \(upNext.date.day)",
                        title: "\(upNext.session.kind.displayName) · \(upNext.session.title)",
                        subtitle: nil
                    )
                }
                .buttonStyle(PressableStyle())
            }
        }
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
    }

    private func checkInSummary(_ checkIn: DailyCheckIn) -> String {
        let weight = checkIn.bodyweight.map { "\(Format.weight($0)) lb logged" } ?? "Weight not logged"
        let protein: String
        if let grams = checkIn.proteinGrams {
            protein = checkIn.proteinTargetMet ? "protein ✓ \(grams) g" : "protein \(grams) of \(checkIn.proteinTargetMin) g"
        } else {
            protein = "protein not yet"
        }
        return "\(weight) · \(protein)"
    }
}

/// Icon tile, text, chevron: the rows in Today's link card.
private struct LinkRow: View {
    let glyph: GlyphKind
    let eyebrow: String?
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            IconTile(glyph: glyph)
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow).textStyle(.label).foregroundStyle(Palette.ink2)
                }
                Text(title).textStyle(.headline).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).textStyle(.callout).foregroundStyle(Palette.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Glyph(.chevronRight, size: 20).foregroundStyle(Palette.ink3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// Today's session: what it is, the core lifts and the start button.
private struct SessionCard: View {
    let session: WorkoutSession
    let actualMinutes: Int?
    @Environment(AppModel.self) private var model

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink(value: Route.session(id: session.id, backTitle: "Today")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            KindBadge(kind: session.kind)
                            Spacer()
                            Text("~\(session.estimatedMinutes) min · \(session.exerciseCount) exercises")
                                .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink2)
                        }
                        HStack {
                            Text(session.title).textStyle(.titleL).foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Glyph(.chevronRight).foregroundStyle(Palette.ink3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Shows the full session")

                if session.coreLifts.isEmpty {
                    groupSummary
                } else {
                    coreLifts
                }

                if session.status == .completed {
                    HStack(spacing: 8) {
                        Glyph(.check, size: 18, weight: 2.5).foregroundStyle(Palette.positive)
                        Text("Done" + (actualMinutes.map { " · \($0) min" } ?? ""))
                            .textStyle(.action).foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Button {
                        model.startWorkout(session)
                    } label: {
                        HStack(spacing: 10) {
                            Glyph(.play, size: 20)
                            Text("Start workout")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private var coreLifts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Core lifts").textStyle(.label).foregroundStyle(Palette.ink2).padding(.bottom, 4)
            ForEach(Array(session.coreLifts.enumerated()), id: \.element.id) { index, lift in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lift.exercise.name).textStyle(.headline).foregroundStyle(Palette.ink)
                        Text(Format.prescription(lift.prescription, loadKind: lift.exercise.loadKind, includeRest: false))
                            .textStyle(.readout).foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    if lift.progression?.direction == .increase {
                        ProgressionBadge(hint: lift.progression, long: true)
                    } else if lift.progression?.direction == .same {
                        Text("Same as last").textStyle(.readout).foregroundStyle(Palette.ink3)
                    } else {
                        ProgressionBadge(hint: lift.progression)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if index < session.coreLifts.count - 1 { Hairline() }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var groupSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Session").textStyle(.label).foregroundStyle(Palette.ink2).padding(.bottom, 4)
            let groups = session.groups.filter { !$0.warmup }
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title).textStyle(.headline).foregroundStyle(Palette.ink)
                        Text(group.items.map(\.exercise.name).joined(separator: " · "))
                            .textStyle(.readout).foregroundStyle(Palette.ink2)
                            .lineLimit(2)
                    }
                    Spacer()
                    if group.format == .circuit {
                        Text("\(group.rounds ?? 1) rounds").textStyle(.readout).foregroundStyle(Palette.ink3)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if index < groups.count - 1 { Hairline() }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct RestDayCard: View {
    let upNext: UpcomingSession?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Badge(text: "Rest day", style: .outline)
                Text("Recover").textStyle(.titleL).foregroundStyle(Palette.ink)
                Text(message).textStyle(.callout).foregroundStyle(Palette.ink2)
            }
        }
    }

    private var message: String {
        guard let upNext else { return "No session today. Sleep and food do the work." }
        return "No session today. Sleep and food do the work. Next up: \(upNext.session.title) on \(upNext.date.weekday.fullName)."
    }
}

/// Seven day cells: done, rest, today, upcoming.
struct WeekStrip: View {
    let week: WeekSchedule
    let today: LocalDate

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "This week", detail: "\(week.completedCount) of \(week.sessions.count) done", detailColor: Palette.ink2)
            HStack(spacing: 6) {
                ForEach(week.days) { day in
                    VStack(spacing: 6) {
                        Text(day.date.weekday.shortName)
                            .textStyle(.label)
                            .foregroundStyle(day.date == today ? Palette.ink : Palette.ink3)
                        cell(day)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(day))
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: ScheduledDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        if let session = day.session {
            switch session.status {
            case .completed:
                Glyph(.check, size: 18, weight: 2).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.surface2, in: shape)
            case .missed:
                Text("—").textStyle(.label).foregroundStyle(Palette.negative)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(shape.strokeBorder(Palette.line, lineWidth: 1))
            case .planned:
                let isToday = day.date == today
                Text(session.kind.code).textStyle(.label)
                    .foregroundStyle(isToday ? Palette.ink : Palette.ink2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(shape.strokeBorder(isToday ? Palette.ink : Palette.lineStrong, lineWidth: isToday ? 2 : 1))
            }
        } else {
            Rectangle().fill(Palette.ink3).frame(width: 10, height: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(shape.strokeBorder(Palette.line, lineWidth: 1))
        }
    }

    private func accessibilityLabel(_ day: ScheduledDay) -> String {
        let name = day.date.weekday.fullName
        guard let session = day.session else { return "\(name), rest" }
        let state: String
        switch session.status {
        case .completed: state = "done"
        case .missed: state = "missed"
        case .planned: state = day.date == today ? "today" : "upcoming"
        }
        return "\(name), \(session.kind.displayName.lowercased()), \(state)"
    }
}

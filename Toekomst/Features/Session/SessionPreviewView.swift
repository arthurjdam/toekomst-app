import SwiftUI
import ToekomstKit

/// Everything in a session before you start it.
struct SessionPreviewView: View {
    let sessionID: String
    let backTitle: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState<WorkoutSession> = .loading
    @State private var moveOptions: [LocalDate] = []
    @State private var showMove = false
    @State private var info: PlannedExercise?
    @State private var error: String?

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingView().transition(.opacity)
            case .failed(let message):
                LoadingView(message: message) { Task { await load() } }
                    .transition(.opacity)
            case .loaded(let session):
                content(session).transition(.opacity)
            }
        }
        .animation(Motion.flat, value: state.phase)
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        // Reload after writes elsewhere, e.g. finishing this session in the player.
        .task(id: model.dataVersion) { await load() }
        .sheet(item: $info) { item in
            ExerciseInfoSheet(item: item)
        }
        .alert("Couldn't move the session", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func load() async {
        do {
            let session = try await model.repository.session(id: sessionID)
            withAnimation(Motion.flat) { state = .loaded(session) }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private var today: LocalDate? { model.today.value?.date }

    private func canMove(_ session: WorkoutSession) -> Bool {
        guard let today else { return false }
        return session.status == .planned && session.date >= today
    }

    private func content(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar(session)
                header(session)
                ForEach(session.groups) { group in
                    groupSection(group)
                }
                equipment(session)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer(session)
        }
        .confirmationDialog("Move \(session.title) to", isPresented: $showMove, titleVisibility: .visible) {
            ForEach(moveOptions, id: \.self) { date in
                Button("\(date.weekday.fullName) \(date.day) \(date.shortMonthName)") {
                    Task { await move(session, to: date) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(moveOptions.isEmpty ? "No free days left this week." : "Free days left this week.")
        }
    }

    private func topBar(_ session: WorkoutSession) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Glyph(.chevronLeft, size: 22)
                    Text(backTitle).textStyle(.action)
                }
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .padding(.leading, -6)
            .accessibilityLabel("Back to \(backTitle)")
            Spacer()
            if canMove(session) {
                Button("Move") {
                    Task { await prepareMove(session) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func header(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KindBadge(kind: session.kind)
                Badge(text: session.block.phase)
            }
            Text(session.title).textStyle(.titleL).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("\(Format.dayHeader(session.date)) · ~\(session.estimatedMinutes) min · \(session.exerciseCount) exercises")
                .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink2)
            let goingUp = session.liftsGoingUp.count
            if goingUp > 0 || session.progressionNote != nil {
                HStack(spacing: 8) {
                    if goingUp > 0 {
                        Badge(text: "▲ \(goingUp) \(goingUp == 1 ? "lift" : "lifts") going up", style: .signalDim)
                    }
                    if let note = session.progressionNote {
                        Text(note).textStyle(.footnote).foregroundStyle(Palette.ink2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 8)
            }
        }
    }

    private func groupSection(_ group: ExerciseGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: group.title, detail: groupDetail(group))
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        info = item
                    } label: {
                        ExerciseRow(item: item, circuit: group.format == .circuit)
                    }
                    .buttonStyle(PressableStyle())
                    if index < group.items.count - 1 { Hairline() }
                }
            }
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func groupDetail(_ group: ExerciseGroup) -> String {
        switch group.format {
        case .straightSets: return "Straight sets · ~\(group.estimatedMinutes) min"
        case .circuit: return "Circuit · \(group.rounds ?? 1) rounds · ~\(group.estimatedMinutes) min"
        }
    }

    private func equipment(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "You'll need")
            FlowLayout(spacing: 8) {
                ForEach(session.equipment, id: \.self) { item in
                    Text(item).textStyle(.callout).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private func footer(_ session: WorkoutSession) -> some View {
        let isToday = session.date == today
        VStack {
            if session.status == .completed {
                HStack(spacing: 8) {
                    Glyph(.check, size: 18, weight: 2.5).foregroundStyle(Palette.positive)
                    Text("Done").textStyle(.action).foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .transition(.opacity)
            } else if isToday {
                Button {
                    model.startWorkout(session)
                } label: {
                    HStack(spacing: 10) {
                        Glyph(.play, size: 20)
                        Text("Start workout")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .transition(.opacity)
            } else if session.status == .planned {
                Text("Scheduled for \(session.date.weekday.fullName)")
                    .textStyle(.action).foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Palette.bg)
        .overlay(alignment: .top) { Hairline() }
    }

    private func prepareMove(_ session: WorkoutSession) async {
        guard let today else { return }
        do {
            let week = try await model.repository.week(starting: session.date.startOfWeek)
            moveOptions = week.days.filter { $0.isRestDay && $0.date >= today }.map(\.date)
            showMove = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func move(_ session: WorkoutSession, to date: LocalDate) async {
        do {
            _ = try await model.repository.moveSession(id: session.id, to: date)
            await model.dataDidChange()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Thumbnail, name, prescription and load change for one planned exercise.
struct ExerciseRow: View {
    let item: PlannedExercise
    var circuit = false

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumb(code: item.exercise.code, emphasized: item.exercise.isCoreLift)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.exercise.name).textStyle(.headline).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    if item.exercise.isCoreLift {
                        Badge(text: "Core", style: .outline, foreground: Palette.ink2)
                    }
                }
                Text(Format.prescription(item.prescription, loadKind: item.exercise.loadKind, includeRest: !circuit))
                    .textStyle(.readout).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ProgressionBadge(hint: item.progression)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows form cues")
    }
}

/// Wraps children onto new lines, like inline text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

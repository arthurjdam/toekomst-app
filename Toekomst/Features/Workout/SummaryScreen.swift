import SwiftUI
import ToekomstKit

/// After the session: stats, highlights, next session's targets and how hard it felt.
struct SummaryScreen: View {
    let model: WorkoutPlayerModel
    let onClose: () -> Void
    @State private var difficulty = 4
    @State private var note = ""
    @State private var addingNote = false
    @State private var submitting = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        if let result = model.result {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(result)
                    stats(result)
                    if !result.highlights.isEmpty {
                        highlights(result.highlights)
                    }
                    if !result.nextTargets.isEmpty {
                        nextSession(result.nextTargets)
                    }
                    feedback
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(submitting ? "Saving…" : "Done") {
                    Task {
                        submitting = true
                        await model.submitFeedback(difficulty: difficulty, note: note)
                        submitting = false
                        onClose()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(submitting)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Palette.bg)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    private func header(_ result: SessionResult) -> some View {
        let session = model.session
        let complete = result.setsCompleted >= result.setsPlanned
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KindBadge(kind: session.kind)
                Text(complete ? "✓ Complete" : "Ended early")
                    .textStyle(.label).foregroundStyle(complete ? Palette.positive : Palette.ink2)
            }
            Text(session.title).textStyle(.titleL).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("\(Format.dayHeader(session.date)) · \(timeRange(result)) · Block \(session.block.blockNumber) wk \(session.block.week)")
                .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink2)
        }
    }

    private func timeRange(_ result: SessionResult) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm"
        let suffix = DateFormatter()
        suffix.locale = Locale(identifier: "en_US_POSIX")
        suffix.dateFormat = "a"
        return "\(formatter.string(from: result.startedAt))-\(formatter.string(from: result.endedAt)) \(suffix.string(from: result.endedAt))"
    }

    private func stats(_ result: SessionResult) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total time").textStyle(.label).foregroundStyle(Palette.ink2)
                Text(Format.clock(result.durationSeconds)).textStyle(.metricXL).foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .accessibilityElement(children: .combine)
            Hairline()
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    cell("Volume · lb", Format.grouped(result.volume))
                    Rectangle().fill(Palette.line).frame(width: 1)
                    cell("Sets", "\(result.setsCompleted)/\(result.setsPlanned)")
                }
                GridRow {
                    Hairline().gridCellColumns(3)
                }
                GridRow {
                    cell("Effort on target", result.effortRated > 0 ? "\(result.effortOnTarget)/\(result.effortRated)" : "—")
                    Rectangle().fill(Palette.line).frame(width: 1)
                    cell("Avg rest", result.averageRestSeconds.map(Format.clock) ?? "—")
                }
            }
        }
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session stats")
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).textStyle(.label).foregroundStyle(Palette.ink2)
            Text(value).textStyle(.metricM).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private func highlights(_ highlights: [SessionHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Highlights")
            VStack(spacing: 0) {
                ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                    HStack {
                        Text(highlight.exerciseName).textStyle(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(highlight.detail).textStyle(.readout)
                            .foregroundStyle(highlight.isPersonalRecord ? Palette.ink : Palette.ink2)
                        if highlight.isPersonalRecord {
                            Badge(text: "PR", style: .signalDim)
                        }
                    }
                    .padding(16)
                    .overlay(alignment: .bottom) { if index < highlights.count - 1 { Hairline() } }
                    .accessibilityElement(children: .combine)
                }
            }
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func nextSession(_ targets: [NextTarget]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Next session")
            VStack(spacing: 0) {
                ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                    HStack {
                        Text(target.exerciseName).textStyle(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(targetText(target)).textStyle(.readout)
                            .foregroundStyle(target.direction == .increase ? Palette.positive : Palette.ink2)
                    }
                    .padding(16)
                    .overlay(alignment: .bottom) { if index < targets.count - 1 { Hairline() } }
                    .accessibilityElement(children: .combine)
                }
            }
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func targetText(_ target: NextTarget) -> String {
        let load = "\(Format.weight(target.load)) lb"
        switch target.direction {
        case .increase: return "▲ " + load
        case .decrease: return "▼ " + load
        case .same, .hold: return "= " + load + (target.note.map { " · \($0)" } ?? "")
        }
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "How hard was that?")
            VStack(alignment: .leading, spacing: 8) {
                ChoiceGrid(
                    options: (1...5).map { Choice(value: $0, label: "\($0)") },
                    selection: difficulty,
                    height: 56,
                    textStyle: .metricM
                ) { difficulty = $0 }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Session difficulty, 1 easy to 5 all out")
                HStack {
                    Text("Easy")
                    Spacer()
                    Text("All out")
                }
                .textStyle(.label).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)

                Hairline().padding(.top, 4)
                if addingNote {
                    TextField("How did it go?", text: $note, axis: .vertical)
                        .textStyle(.body)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2...6)
                        .focused($noteFocused)
                        .padding(.vertical, 8)
                } else {
                    Button {
                        withAnimation(Motion.flat) { addingNote = true }
                        noteFocused = true
                    } label: {
                        HStack(spacing: 10) {
                            Glyph(.plus, size: 18)
                            Text("Add a note").textStyle(.footnote)
                        }
                        .foregroundStyle(Palette.ink2)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(16)
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

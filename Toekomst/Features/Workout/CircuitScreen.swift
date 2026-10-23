import SwiftUI
import ToekomstKit

/// A circuit move: big work timer, one tick per second, and what's next.
/// Between moves the same screen counts down the short rest.
struct CircuitScreen: View {
    @Bindable var model: WorkoutPlayerModel
    let stage: Namespace.ID
    @Environment(\.theme) private var theme

    private var resting: Bool { model.circuitPhase == .rest }

    var body: some View {
        if let step = model.currentStep, let item = model.currentItem, let group = model.currentGroup {
            VStack(spacing: 0) {
                header(step: step, group: group)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .animation(Motion.flat, value: step)

                VStack(spacing: 16) {
                    DemoFigure(demo: item.exercise.demo, code: item.exercise.code)
                        .glitch(on: item.id)
                        .frame(minHeight: 140, maxHeight: 208)
                        .background(Palette.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(alignment: .topTrailing) {
                            Button { model.showInfo = true } label: { Glyph(.info, size: 20) }
                                .buttonStyle(IconButtonStyle())
                                .padding(12)
                                .accessibilityLabel("Exercise info and form cues")
                        }
                        .stage(.card, in: stage)
                        .layoutPriority(-1)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if resting {
                                Text("Up next").textStyle(.label).foregroundStyle(Palette.ink2)
                            }
                            Text(item.exercise.name).textStyle(.titleM).foregroundStyle(Palette.ink)
                                .accessibilityAddTraits(.isHeader)
                                .stage(.title, in: stage)
                                .glitch(on: item.id)
                        }
                        Spacer()
                        if let load = model.engine.targetLoad(for: step) {
                            Text("\(Format.weight(load)) lb" + (item.exercise.loadKind == .dumbbellPair ? " each" : ""))
                                .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink2)
                        }
                    }

                    timer(item)

                    if !resting, let following = followingMove(after: step) {
                        nextCard(following, step: step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .frame(maxHeight: .infinity, alignment: .top)
                .animation(Motion.flat, value: resting)

                footer(item)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private func header(step: WorkoutStep, group: ExerciseGroup) -> some View {
        let rounds = max(1, group.rounds ?? 1)
        let moves = group.items.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Badge(text: model.session.kind.displayName, style: .signal, glyph: .boltFilled)
                Spacer()
                Text((group.title == "Circuit" ? "" : "\(group.title) · ") + "Round \(step.setNumber) of \(rounds)")
                    .textStyle(.label).foregroundStyle(Palette.ink)
            }
            HStack(spacing: 12) {
                ForEach(1...rounds, id: \.self) { round in
                    if round < step.setNumber {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.ink2).frame(width: 8, height: 8)
                    } else if round > step.setNumber {
                        RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.lineStrong, lineWidth: 1).frame(width: 8, height: 8)
                    } else {
                        HStack(spacing: 3) {
                            ForEach(0..<moves, id: \.self) { move in
                                RoundedRectangle(cornerRadius: 2).fill(moveColor(move, current: step.itemIndex))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)
                    }
                }
            }
            .frame(height: 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Round \(step.setNumber) of \(rounds), move \(step.itemIndex + 1) of \(moves)")
            HStack {
                HStack(spacing: 8) {
                    SetBoxes(total: moves, done: step.itemIndex, currentColor: theme.signal)
                    Text("Move \(step.itemIndex + 1)/\(moves)").textStyle(.label).foregroundStyle(Palette.ink2)
                        .glitch(on: step)
                }
                .accessibilityHidden(true)
                Spacer()
                WorkoutControls(model: model)
            }
            .frame(height: 44)
        }
    }

    private func moveColor(_ move: Int, current: Int) -> Color {
        if move < current { return theme.signal }
        if move == current { return resting ? Palette.surface3 : Palette.lineStrong }
        return Palette.surface3
    }

    @ViewBuilder
    private func timer(_ item: PlannedExercise) -> some View {
        let total = max(1, model.phaseDuration)
        let remaining = max(0, model.remainingSeconds)
        if resting || item.prescription.durationSeconds != nil {
            VStack(spacing: 10) {
                HStack(alignment: .bottom) {
                    Text(Format.clock(remaining))
                        .textStyle(.huge)
                        .foregroundStyle(resting ? Palette.ink2 : theme.signal)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer()
                    Text(resting ? "Rest · \(total)s" : "Work · \(total)s")
                        .textStyle(.label).foregroundStyle(Palette.ink2)
                        .glitch(on: resting)
                        .padding(.bottom, 10)
                }
                HStack(spacing: 2) {
                    ForEach(0..<total, id: \.self) { tick in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(tick < remaining ? (resting ? Palette.ink2 : theme.signal) : Palette.surface3)
                    }
                }
                .frame(height: 20)
                .animation(Motion.tick, value: remaining)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(resting ? "Rest time remaining" : "Work time remaining")
            .accessibilityValue("\(remaining) seconds")
            .accessibilityAddTraits(.updatesFrequently)
        } else if let reps = item.prescription.reps {
            HStack(alignment: .bottom) {
                Text(reps.display).textStyle(.huge).foregroundStyle(theme.signal)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Spacer()
                Text("Reps · own pace").textStyle(.label).foregroundStyle(Palette.ink2).padding(.bottom, 10)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The move after the one on screen, within this circuit.
    private func followingMove(after step: WorkoutStep) -> PlannedExercise? {
        guard let index = model.engine.steps.firstIndex(of: step), model.engine.steps.indices.contains(index + 1) else { return nil }
        let next = model.engine.steps[index + 1]
        guard next.groupIndex == step.groupIndex else { return nil }
        return model.engine.item(of: next)
    }

    private func nextCard(_ next: PlannedExercise, step: WorkoutStep) -> some View {
        HStack(spacing: 12) {
            ExerciseThumb(code: next.exercise.code)
            VStack(alignment: .leading, spacing: 2) {
                Text("Next · after \(model.engine.restSeconds(after: step))s").textStyle(.label).foregroundStyle(Palette.ink2)
                Text(next.exercise.name).textStyle(.headline).foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let reps = next.prescription.reps {
                Text(reps.display).textStyle(.metricM).foregroundStyle(Palette.ink)
                Text("reps").textStyle(.readout).foregroundStyle(Palette.ink2)
            } else if let duration = next.prescription.durationSeconds {
                Text("\(duration)").textStyle(.metricM).foregroundStyle(Palette.ink)
                Text("sec").textStyle(.readout).foregroundStyle(Palette.ink2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func footer(_ item: PlannedExercise) -> some View {
        if resting {
            Button {
                withAnimation(Motion.stage) { model.endRest() }
            } label: {
                HStack(spacing: 8) {
                    Text("Skip rest")
                    Glyph(.skip, size: 18, weight: 2)
                }
            }
            .buttonStyle(OutlineButtonStyle())
            .stage(.primary, in: stage)
        } else if item.prescription.durationSeconds == nil {
            VStack(spacing: 8) {
                Button {
                    withAnimation(Motion.stage) { model.completeAsPlanned() }
                } label: {
                    HStack(spacing: 10) {
                        Glyph(.check, size: 20, weight: 2.25)
                        Text("Done move")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .stage(.primary, in: stage)
                Button("Skip move") { withAnimation(Motion.stage) { model.skipCurrent() } }
                    .buttonStyle(QuietButtonStyle())
            }
        } else {
            Button {
                withAnimation(Motion.stage) { model.skipCurrent() }
            } label: {
                HStack(spacing: 8) {
                    Text("Skip move")
                    Glyph(.skip, size: 18, weight: 2)
                }
            }
            .buttonStyle(OutlineButtonStyle())
            .stage(.primary, in: stage)
        }
    }
}

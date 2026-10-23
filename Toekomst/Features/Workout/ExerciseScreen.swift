import SwiftUI
import ToekomstKit

/// One set of a straight-set exercise: demo, target and "Done set".
struct ExerciseScreen: View {
    @Bindable var model: WorkoutPlayerModel
    let stage: Namespace.ID
    @State private var angle = "side"

    var body: some View {
        if let step = model.currentStep, let item = model.currentItem {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    figure(item)
                    titleRow(item, step: step)
                    targets(item, step: step)
                    hints(item, step: step)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxHeight: .infinity, alignment: .top)

                footer(item)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .animation(Motion.flat, value: model.timedSetRunning)
            .onChange(of: item.id, initial: true) { _, _ in
                angle = item.exercise.demoAngles?.first ?? "side"
            }
        }
    }

    private func figure(_ item: PlannedExercise) -> some View {
        DemoFigure(demo: item.exercise.demo, angle: angle, code: item.exercise.code)
            .glitch(on: angle)
            .frame(minHeight: 150, maxHeight: 272)
            .background(Palette.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .topLeading) {
                if let angles = item.exercise.demoAngles, angles.count > 1 {
                    HStack(spacing: 2) {
                        ForEach(angles, id: \.self) { option in
                            Button(option.capitalized) { withAnimation(Motion.flat) { angle = option } }
                                .buttonStyle(.plain)
                                .textStyle(.label)
                                .foregroundStyle(angle == option ? Palette.ink : Palette.ink2)
                                .padding(.horizontal, 12)
                                .frame(height: 40)
                                .background(angle == option ? Palette.surface3 : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityAddTraits(angle == option ? .isSelected : [])
                        }
                    }
                    .padding(2)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
                    .padding(12)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Camera angle")
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { model.showInfo = true } label: { Glyph(.info, size: 20) }
                    .buttonStyle(IconButtonStyle())
                    .padding(12)
                    .accessibilityLabel("Exercise info and form cues")
            }
            .overlay(alignment: .bottomLeading) {
                if item.exercise.loadKind == .barbell {
                    Text("Bar path · mid-foot").textStyle(.label).foregroundStyle(Palette.ink3)
                        .padding(.horizontal, 16).padding(.bottom, 14)
                }
            }
            .stage(.card, in: stage)
            .layoutPriority(-1)
    }

    private func titleRow(_ item: PlannedExercise, step: WorkoutStep) -> some View {
        let total = model.engine.setCount(for: step)
        return HStack {
            HStack(spacing: 8) {
                Text(item.exercise.name).textStyle(.titleM).foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                    .stage(.title, in: stage)
                if item.exercise.isCoreLift {
                    Badge(text: "Core", style: .outline, foreground: Palette.ink2)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                SetBoxes(total: total, done: step.setNumber - 1)
                Text("Set \(step.setNumber)/\(total)").textStyle(.label).foregroundStyle(Palette.ink)
            }
            .stage(.sets, in: stage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Set \(step.setNumber) of \(total)")
        }
    }

    @ViewBuilder
    private func targets(_ item: PlannedExercise, step: WorkoutStep) -> some View {
        let prescription = item.prescription
        if prescription.isTimed, let duration = prescription.durationSeconds {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.timedSetRunning ? "Time left" : "Time").textStyle(.label).foregroundStyle(Palette.ink2)
                        .glitch(on: model.timedSetRunning)
                    Text(Format.clock(model.timedSetRunning ? max(0, model.remainingSeconds) : duration))
                        .textStyle(.metricXL).foregroundStyle(Palette.ink)
                        .stage(.metric, in: stage)
                }
                Spacer()
                if let note = prescription.note {
                    Text(note).textStyle(.readout).foregroundStyle(Palette.ink2).multilineTextAlignment(.trailing)
                        .padding(.bottom, 8)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .bottom) {
                if let load = model.engine.targetLoad(for: step) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.exercise.loadKind == .dumbbellPair ? "Weight · each hand" : "Weight")
                            .textStyle(.label).foregroundStyle(Palette.ink2)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Format.weight(load)).textStyle(.metricXL).foregroundStyle(Palette.ink)
                                .minimumScaleFactor(0.6).lineLimit(1)
                            Text("lb").textStyle(.readout).foregroundStyle(Palette.ink2)
                        }
                        .stage(.metric, in: stage)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(prescription.reps?.isPerSide == true ? "Reps / side" : "Reps").textStyle(.label).foregroundStyle(Palette.ink2)
                        Text(prescription.reps?.rangeDisplay ?? "—").textStyle(.metricL).foregroundStyle(Palette.ink)
                    }
                    .padding(.bottom, 4)
                    .accessibilityElement(children: .combine)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prescription.reps?.isPerSide == true ? "Reps / side" : "Reps").textStyle(.label).foregroundStyle(Palette.ink2)
                        Text(prescription.reps?.rangeDisplay ?? "—").textStyle(.metricXL).foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Text(item.exercise.loadKind == .bodyweight ? "Bodyweight" : (prescription.note ?? ""))
                        .textStyle(.label).foregroundStyle(Palette.ink2)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func hints(_ item: PlannedExercise, step: WorkoutStep) -> some View {
        let held = model.engine.readiness?.holdsLoads == true && item.progression?.direction == .increase
        VStack(alignment: .leading, spacing: 8) {
            if held {
                HStack(spacing: 8) {
                    Badge(text: "= Hold")
                    Text("Ready check: same load as last time today.").textStyle(.footnote).foregroundStyle(Palette.ink2)
                }
            } else if let reason = item.progression?.reason, item.progression?.direction == .increase {
                HStack(spacing: 8) {
                    ProgressionBadge(hint: item.progression, long: true)
                    Text(reason).textStyle(.footnote).foregroundStyle(Palette.ink2)
                }
            }
            HStack {
                if item.exercise.loadKind == .barbell, let load = model.engine.targetLoad(for: step) {
                    Text(platesText(load)).textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink3)
                }
                Spacer()
                if let history = item.history, let last = Format.lastPerformance(history) {
                    Text("Last \(last)").textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink3)
                }
            }
        }
    }

    private func platesText(_ load: Double) -> String {
        guard let plates = PlateCalculator.platesPerSide(for: load) else { return "Bar \(Format.weight(PlateCalculator.standardBar))" }
        if plates.isEmpty { return "Empty bar" }
        return "Plates " + plates.map(Format.weight).joined(separator: " + ") + " / side"
    }

    @ViewBuilder
    private func footer(_ item: PlannedExercise) -> some View {
        if item.prescription.isTimed && !model.timedSetRunning {
            Button {
                withAnimation(Motion.flat) { model.startTimedSet() }
            } label: {
                HStack(spacing: 10) {
                    Glyph(.play, size: 20)
                    Text("Start \(Format.clock(item.prescription.durationSeconds ?? 0))")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .stage(.primary, in: stage)
        } else {
            Button {
                withAnimation(Motion.stage) { model.doneSet() }
            } label: {
                HStack(spacing: 10) {
                    Glyph(.check, size: 20, weight: 2.25)
                    Text(model.timedSetRunning ? "Done early" : "Done set")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .stage(.primary, in: stage)
        }
    }
}

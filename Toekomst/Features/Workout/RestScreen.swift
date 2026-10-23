import SwiftUI
import ToekomstKit

/// Rest between sets of the same exercise: a segmented ring counting down.
struct RestScreen: View {
    @Bindable var model: WorkoutPlayerModel
    let stage: Namespace.ID
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                if let logged = model.lastLogged {
                    loggedChip(logged)
                }
                ring
                if let step = model.currentStep, let item = model.currentItem {
                    upNext(item, step: step)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .frame(maxHeight: .infinity, alignment: .top)

            footer
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }

    private func loggedChip(_ log: SetLog) -> some View {
        HStack(spacing: 8) {
            Glyph(.check, size: 16, weight: 2.5).foregroundStyle(Palette.positive)
            Text("Logged").textStyle(.label).foregroundStyle(Palette.ink)
            Text(loggedSummary(log)).textStyle(.readout).foregroundStyle(Palette.ink2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func loggedSummary(_ log: SetLog) -> String {
        var parts: [String] = []
        if let load = log.load, let reps = log.reps {
            parts.append("\(Format.weight(load)) × \(reps)")
        } else if let reps = log.reps {
            parts.append("\(reps) reps")
        }
        if let reserve = log.repsInReserve {
            parts.append(reserve >= 4 ? "4+ in reserve" : "\(reserve) in reserve")
        }
        return parts.joined(separator: " · ")
    }

    private var label: String {
        if model.isOvertime { return "Overtime" }
        return model.remainingSeconds <= 3 ? "Get set" : "Rest"
    }

    private var ring: some View {
        let remaining = model.remainingSeconds
        let fraction = model.phaseDuration > 0 ? max(0, Double(remaining)) / Double(model.phaseDuration) : 0
        let style = StrokeStyle(lineWidth: 18, dash: [2.5, 4.62])
        return ZStack {
            Circle().inset(by: 12).stroke(Palette.surface3, style: style)
            Circle().inset(by: 12)
                .trim(from: 0, to: fraction)
                .stroke(theme.signal, style: style)
                .rotationEffect(.degrees(-90))
                .animation(Motion.tick, value: fraction)
            VStack(spacing: 6) {
                Text(label).textStyle(.label).foregroundStyle(model.isOvertime ? Palette.negative : Palette.ink2)
                    .glitch(on: label)
                Text((model.isOvertime ? "+" : "") + Format.clock(remaining))
                    .textStyle(.timer)
                    .foregroundStyle(model.isOvertime ? Palette.ink2 : Palette.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("of \(Format.clock(model.phaseDuration))").textStyle(.readout).foregroundStyle(Palette.ink3)
            }
            .padding(40)
        }
        .frame(maxWidth: 296, maxHeight: 296)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest time remaining")
        .accessibilityValue(model.isOvertime ? "Over by \(Format.clock(remaining))" : Format.clock(remaining))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func upNext(_ item: PlannedExercise, step: WorkoutStep) -> some View {
        Button {
            withAnimation(Motion.stage) { model.endRest() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        SetBoxes(total: model.engine.setCount(for: step), done: step.setNumber - 1)
                            .stage(.sets, in: stage)
                        Text("Up next · set \(step.setNumber) of \(model.engine.setCount(for: step))").textStyle(.label).foregroundStyle(Palette.ink2)
                    }
                    Text(item.exercise.name).textStyle(.titleM).foregroundStyle(Palette.ink)
                        .stage(.title, in: stage)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let load = model.engine.targetLoad(for: step) {
                        Text(Format.weight(load)).textStyle(.metricM).foregroundStyle(Palette.ink)
                        Text("lb × \(item.prescription.reps?.display ?? "")").textStyle(.readout).foregroundStyle(Palette.ink2)
                    } else if let reps = item.prescription.reps {
                        Text(reps.display).textStyle(.metricM).foregroundStyle(Palette.ink)
                        Text("reps").textStyle(.readout).foregroundStyle(Palette.ink2)
                    }
                }
                .stage(.metric, in: stage)
            }
            .padding(16)
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
            .stage(.card, in: stage)
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Ends rest and opens the set")
    }

    private var footer: some View {
        let nextSet = model.currentStep?.setNumber ?? 0
        return VStack(spacing: 8) {
            Text(hint(nextSet: nextSet)).textStyle(.label).foregroundStyle(Palette.ink3)
                .glitch(on: model.isOvertime)
                .padding(.bottom, 4)
            HStack(spacing: 8) {
                Button("-15s") { model.adjustRest(by: -15) }
                    .buttonStyle(SecondaryButtonStyle(height: 52, fullWidth: true))
                    .accessibilityLabel("15 seconds less")
                Button("+15s") { model.adjustRest(by: 15) }
                    .buttonStyle(SecondaryButtonStyle(height: 52, fullWidth: true))
                    .accessibilityLabel("15 seconds more")
            }
            Button {
                withAnimation(Motion.stage) { model.endRest() }
            } label: {
                HStack(spacing: 10) {
                    Text(model.isOvertime ? "Start set \(nextSet)" : "Skip rest · set \(nextSet)")
                        .glitch(on: model.isOvertime)
                    Glyph(.skip, size: 18, weight: 2.25)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .stage(.primary, in: stage)
        }
    }

    private func hint(nextSet: Int) -> String {
        if model.isOvertime { return "Rest is over · start when ready" }
        return model.autoStartAfterRest ? "Set \(nextSet) opens on its own at 0:00" : "Start set \(nextSet) when you're ready"
    }
}

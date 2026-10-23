import SwiftUI
import ToekomstKit

/// Between exercises: what was finished, what's next, what to grab. The rest
/// keeps running in the footer.
struct TransitionScreen: View {
    @Bindable var model: WorkoutPlayerModel

    var body: some View {
        VStack(spacing: 0) {
            WorkoutHeader(model: model)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 16) {
                    if let finished = model.engine.previousStep {
                        finishedBanner(finished)
                    }
                    if let step = model.currentStep, let item = model.currentItem {
                        upNextCard(item, step: step)
                        if let setup = item.setup, !setup.isEmpty {
                            equipment(setup)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)

            footer
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }

    private func finishedBanner(_ finished: WorkoutStep) -> some View {
        let group = model.engine.group(of: finished)
        let groupDone = model.engine.finishesGroup(finished)
        let groupNumber = finished.groupIndex + 1
        let next = model.currentGroup
        return HStack(spacing: 12) {
            IconTile(glyph: .check, color: Palette.positive, weight: 2.25)
            VStack(alignment: .leading, spacing: 2) {
                Text(groupDone ? "\(group.title) done" : "\(model.engine.item(of: finished).exercise.name) done")
                    .textStyle(.titleM).foregroundStyle(Palette.ink)
                if groupDone, let next {
                    Text("\(next.title): \(next.items.count) \(next.items.count == 1 ? "exercise" : "exercises"), ~\(next.estimatedMinutes) min")
                        .textStyle(.callout).foregroundStyle(Palette.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if groupDone {
                Text("\(groupNumber)/\(model.session.groups.count)").textStyle(.readout).foregroundStyle(Palette.ink2)
                    .accessibilityLabel("Part \(groupNumber) of \(model.session.groups.count)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func upNextCard(_ item: PlannedExercise, step: WorkoutStep) -> some View {
        VStack(spacing: 0) {
            DemoFigure(demo: item.exercise.demo, code: item.exercise.code, gridColor: Palette.surface3)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Palette.surface2)
                .overlay(alignment: .topLeading) {
                    Badge(text: "Up next", foreground: Palette.ink).background(Palette.bg, in: RoundedRectangle(cornerRadius: 3)).padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if let note = item.sideNote {
                        Badge(text: note, foreground: Palette.ink2).background(Palette.bg, in: RoundedRectangle(cornerRadius: 3)).padding(12)
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    Text(item.exercise.name).textStyle(.titleM).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(model.engine.setCount(for: step)) sets").textStyle(.label).foregroundStyle(Palette.ink2)
                }
                HStack(spacing: 8) {
                    if let load = model.engine.targetLoad(for: step) {
                        tile(label: item.exercise.loadKind == .dumbbellPair ? "Each hand" : "Weight", value: Format.weight(load), unit: "lb")
                    }
                    if let reps = item.prescription.reps {
                        tile(label: reps.isPerSide ? "Reps / side" : "Reps", value: reps.rangeDisplay, unit: nil)
                    } else if let duration = item.prescription.durationSeconds {
                        tile(label: "Time", value: Format.clock(duration), unit: nil)
                    }
                }
                if item.isGoingUp, let reason = item.progression?.reason {
                    HStack(spacing: 8) {
                        ProgressionBadge(hint: item.progression)
                        Text(reason).textStyle(.footnote).foregroundStyle(Palette.ink2)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Hairline() }
                }
            }
            .padding(16)
        }
        .background(Palette.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func tile(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).textStyle(.label).foregroundStyle(Palette.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).textStyle(.metricM).foregroundStyle(Palette.ink)
                if let unit { Text(unit).textStyle(.readout).foregroundStyle(Palette.ink2) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func equipment(_ setup: [EquipmentSetup]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(setup.enumerated()), id: \.offset) { index, entry in
                HStack(spacing: 12) {
                    Text(index == 0 ? "Grab" : "").textStyle(.label).foregroundStyle(Palette.ink2)
                        .frame(width: 44, alignment: .leading)
                    Text(entry.item).textStyle(.headline).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let location = entry.location {
                        Text(location).textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink3)
                    }
                }
                .frame(minHeight: 52)
                .overlay(alignment: .bottom) {
                    if index < setup.count - 1 { Hairline() }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack {
                Text(model.isOvertime ? "Rest done" : "Rest running").textStyle(.label).foregroundStyle(Palette.ink2)
                Spacer()
                Text(model.isOvertime ? "+\(Format.clock(model.remainingSeconds)) over" : "\(Format.clock(model.remainingSeconds)) left")
                    .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink)
            }
            .accessibilityElement(children: .combine)
            Button("I'm ready") { model.endRest() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

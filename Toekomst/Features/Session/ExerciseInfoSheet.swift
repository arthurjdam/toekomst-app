import SwiftUI
import ToekomstKit

/// Form cues, demo and history for one exercise.
struct ExerciseInfoSheet: View {
    let item: PlannedExercise
    @State private var angle: String

    init(item: PlannedExercise) {
        self.item = item
        _angle = State(initialValue: item.exercise.demoAngles?.first ?? "side")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetGrabber().padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.exercise.name).textStyle(.titleM).foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        if item.exercise.isCoreLift {
                            Badge(text: "Core", style: .outline, foreground: Palette.ink2)
                        }
                    }
                    Text(Format.prescription(item.prescription, loadKind: item.exercise.loadKind, includeRest: true))
                        .textStyle(.readout).foregroundStyle(Palette.ink2)
                }

                DemoFigure(demo: item.exercise.demo, angle: angle, code: item.exercise.code)
                    .crossfade(on: angle)
                    .frame(height: 220)
                    .background(Palette.bg, in: RoundedRectangle(cornerRadius: 20))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if let angles = item.exercise.demoAngles, angles.count > 1 {
                    SegmentedControl(
                        options: angles.map { Choice(value: $0, label: $0.capitalized) },
                        selection: $angle,
                        accessibilityLabel: "Camera angle"
                    )
                }

                if !item.exercise.cues.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Form cues")
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(item.exercise.cues.enumerated()), id: \.offset) { index, cue in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(String(format: "%02d", index + 1)).textStyle(.readout).foregroundStyle(Palette.ink3)
                                    Text(cue).textStyle(.body).foregroundStyle(Palette.ink)
                                }
                            }
                        }
                    }
                }

                if let reason = item.progression?.reason {
                    HStack(alignment: .top, spacing: 8) {
                        ProgressionBadge(hint: item.progression, long: true)
                        Text(reason).textStyle(.footnote).foregroundStyle(Palette.ink2)
                    }
                }

                if let history = item.history, let last = Format.lastPerformance(history) {
                    HStack {
                        Text("Last time").textStyle(.label).foregroundStyle(Palette.ink2)
                        Spacer()
                        Text(last).textStyle(.readout).foregroundStyle(Palette.ink)
                    }
                }

                if let setup = item.setup, !setup.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Set up")
                        ForEach(setup, id: \.self) { entry in
                            HStack {
                                Text(entry.item).textStyle(.headline).foregroundStyle(Palette.ink)
                                Spacer()
                                if let location = entry.location {
                                    Text(location).textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink3)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface1)
        .presentationCornerRadius(20)
    }
}

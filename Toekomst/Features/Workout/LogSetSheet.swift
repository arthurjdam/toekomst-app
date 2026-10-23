import SwiftUI
import ToekomstKit

/// Confirm weight and reps, then one tap on "reps in reserve" saves the set
/// and starts the rest.
struct LogSetSheet: View {
    let model: WorkoutPlayerModel
    @State private var load: Double?
    @State private var reps: Int

    private let step: WorkoutStep?
    private let item: PlannedExercise?
    private let target: RepTarget
    private let plannedLoad: Double?

    @MainActor
    init(model: WorkoutPlayerModel) {
        self.model = model
        let step = model.currentStep
        let item = model.currentItem
        let target = item?.prescription.reps ?? RepTarget(exactly: 0)
        let plannedLoad = step.flatMap { model.engine.targetLoad(for: $0) }
        self.step = step
        self.item = item
        self.target = target
        self.plannedLoad = plannedLoad
        _load = State(initialValue: plannedLoad)
        _reps = State(initialValue: target.max)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SheetGrabber().padding(.top, 8)
            if let item, let step {
                header(item, step: step)
                VStack(spacing: 12) {
                    if let load {
                        ValueStepper(
                            label: item.exercise.loadKind == .dumbbellPair ? "Weight · lb each" : "Weight · lb",
                            value: Format.weight(load),
                            decrementLabel: "\(Format.weight(TrainingRules.loadIncrement)) lb less",
                            incrementLabel: "\(Format.weight(TrainingRules.loadIncrement)) lb more",
                            canDecrement: load >= TrainingRules.loadIncrement,
                            onDecrement: { self.load = max(0, load - TrainingRules.loadIncrement) },
                            onIncrement: { self.load = load + TrainingRules.loadIncrement }
                        )
                    }
                    ValueStepper(
                        label: target.isPerSide ? "Reps / side" : "Reps",
                        value: "\(reps)",
                        decrementLabel: "One rep less",
                        incrementLabel: "One rep more",
                        canDecrement: reps > 0,
                        onDecrement: { reps = max(0, reps - 1) },
                        onIncrement: { reps += 1 }
                    )
                    Text(note)
                        .textStyle(.readout).textCase(.uppercase)
                        .foregroundStyle(noteColor)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                reserve
                Spacer(minLength: 0)
                Text(footnote(step))
                    .textStyle(.footnote).foregroundStyle(Palette.ink3)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .presentationDetents([.fraction(0.8), .large])
        .presentationBackground(Palette.surface1)
        .presentationCornerRadius(20)
    }

    private func header(_ item: PlannedExercise, step: WorkoutStep) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(item.exercise.name) · set \(step.setNumber) of \(model.engine.setCount(for: step))")
                    .textStyle(.label).foregroundStyle(Palette.ink2)
                Text("Log set").textStyle(.titleM).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Text("Target " + (plannedLoad.map { "\(Format.weight($0)) × " } ?? "") + target.display)
                .textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink3)
        }
    }

    private var outcome: SetOutcome { SetOutcome(reps: reps, target: target) }

    private var note: String {
        var text: String
        switch outcome {
        case .aboveRange: text = "▲ Above range, nice"
        case .topOfRange: text = "Top of range · as planned"
        case .inRange: text = "In range"
        case .belowRange: text = "▼ Below range · load holds next time"
        }
        if let load, let plannedLoad, load != plannedLoad {
            text += " · \(Format.signedWeight(load - plannedLoad)) lb"
        }
        return text
    }

    private var noteColor: Color {
        switch outcome {
        case .aboveRange: return Palette.positive
        case .belowRange: return Palette.negative
        case .topOfRange, .inRange: return Palette.ink2
        }
    }

    /// 0-3 is the target zone (close to failure); 4+ means the set was light.
    private var reserve: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How many more could you have done?").textStyle(.label).foregroundStyle(Palette.ink2)
            HStack(spacing: 8) {
                ForEach(0...4, id: \.self) { value in
                    Button {
                        model.logSet(load: load, reps: reps, repsInReserve: value)
                    } label: {
                        Text(value == 4 ? "4+" : "\(value)")
                            .textStyle(.metricM)
                            .foregroundStyle(value == 4 ? Palette.ink2 : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(value == 4 ? "4 or more reps left, save set" : "\(value) more \(value == 1 ? "rep" : "reps"), save set")
                }
            }
            GeometryReader { geometry in
                let column = (geometry.size.width - 32) / 5
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 4) {
                        BracketShape()
                            .stroke(Palette.lineStrong, lineWidth: 1)
                            .frame(height: 6)
                        Text("Target zone").textStyle(.label).foregroundStyle(Palette.ink2)
                    }
                    .frame(width: column * 4 + 24)
                    Text("Light").textStyle(.label).foregroundStyle(Palette.ink3)
                        .frame(width: column)
                        .padding(.top, 10)
                }
            }
            .frame(height: 30)
            .accessibilityHidden(true)
        }
    }

    private func footnote(_ step: WorkoutStep) -> String {
        guard model.engine.nextStep != nil else { return "One tap saves the set and finishes the workout." }
        return "One tap saves the set and starts your \(Format.clock(model.engine.restSeconds(after: step))) rest."
    }
}

/// An open-topped bracket under the target-zone buttons.
private struct BracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 0.5, y: rect.maxY - 0.5))
        path.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.maxY - 0.5))
        path.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.minY))
        return path
    }
}

import SwiftUI
import ToekomstKit

/// Two questions before the session. If soreness hasn't cleared or energy is
/// low, today's load increases are held back.
struct ReadinessSheet: View {
    let session: WorkoutSession
    let onStart: (ReadinessAnswers?) -> Void
    let onCancel: () -> Void
    @State private var soreness: Soreness = .gone
    @State private var energy: Energy = .good

    private var answers: ReadinessAnswers { ReadinessAnswers(soreness: soreness, energy: energy) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SheetGrabber().padding(.top, 8)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before you start · 2 questions").textStyle(.label).foregroundStyle(Palette.ink2)
                    Text("Ready check").textStyle(.titleL).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button { onCancel() } label: { Glyph(.close, size: 20) }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Close without starting")
            }

            question(sorenessQuestion) {
                ChoiceGrid(
                    options: [
                        Choice(value: Soreness.gone, label: "Gone"),
                        Choice(value: Soreness.aBit, label: "A bit"),
                        Choice(value: Soreness.stillSore, label: "Still sore")
                    ],
                    selection: soreness
                ) { soreness = $0 }
            }

            question("Energy today?") {
                ChoiceGrid(
                    options: [
                        Choice(value: Energy.good, label: "Good"),
                        Choice(value: Energy.okay, label: "Okay"),
                        Choice(value: Energy.drained, label: "Drained")
                    ],
                    selection: energy
                ) { energy = $0 }
            }

            verdict

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Button {
                    onStart(answers)
                } label: {
                    HStack(spacing: 10) {
                        Glyph(.play, size: 20)
                        Text("Start workout")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Skip check") { onStart(nil) }
                    .buttonStyle(QuietButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .presentationDetents([.large])
        .presentationBackground(Palette.surface1)
        .presentationCornerRadius(20)
        .interactiveDismissDisabled()
    }

    private var sorenessQuestion: String {
        guard let previous = session.previousSessionDate else { return "Any soreness?" }
        return "Soreness from \(previous.weekday.fullName)?"
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textStyle(.label).foregroundStyle(Palette.ink2)
            content()
        }
    }

    private var verdict: some View {
        let hold = answers.holdsLoads
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Badge(text: hold ? "= Hold" : "▲ Go", style: hold ? .neutral : .signalDim)
                Text(hold ? "Holding loads today" : "Going for it").textStyle(.titleM).foregroundStyle(Palette.ink)
            }
            .wipe(on: hold)
            Text(reason).textStyle(.footnote).foregroundStyle(Palette.ink2)
                .wipe(on: reason)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var reason: String {
        let day = session.previousSessionDate?.weekday.fullName
        let hold = "Same loads as last week, no increases. Effort targets stay the same."
        if soreness == .stillSore {
            return "Still sore\(day.map { " from \($0)" } ?? ""). " + hold
        }
        if energy == .drained {
            return "Low energy today. " + hold
        }
        let increases = session.liftsGoingUp
        let plan: String
        if increases.isEmpty {
            plan = "Running the planned loads."
        } else {
            let names = increases.map { $0.exercise.name.lowercased() }
            let list = names.count == 1 ? names[0] : names.dropLast().joined(separator: ", ") + " and " + names.last!
            let change = increases.first?.progression?.loadChange ?? TrainingRules.loadIncrement
            plan = "Running the planned loads, including \(Format.signedWeight(change)) lb on \(list)."
        }
        if soreness == .aBit {
            return "A little soreness is normal. " + plan
        }
        return (day.map { "Recovered from \($0). " } ?? "") + plan
    }
}

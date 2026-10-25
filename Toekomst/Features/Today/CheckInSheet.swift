import SwiftUI
import ToekomstKit

/// Morning bodyweight and the day's protein.
struct CheckInSheet: View {
    let checkIn: DailyCheckIn
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var bodyweight: Double
    @State private var protein: Int
    @State private var saving = false
    @State private var error: String?

    init(checkIn: DailyCheckIn) {
        self.checkIn = checkIn
        _bodyweight = State(initialValue: checkIn.bodyweight ?? 180)
        _protein = State(initialValue: checkIn.proteinGrams ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SheetGrabber().padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily check-in · \(Format.dayHeader(checkIn.date))").textStyle(.label).foregroundStyle(Palette.ink2)
                Text("Check in").textStyle(.titleL).foregroundStyle(Palette.ink)
            }

            ValueStepper(
                label: "Bodyweight · lb",
                value: Format.weight(bodyweight),
                decrementLabel: "0.2 lb less",
                incrementLabel: "0.2 lb more",
                canDecrement: bodyweight > 50,
                onDecrement: { bodyweight = ((bodyweight - 0.2) * 10).rounded() / 10 },
                onIncrement: { bodyweight = ((bodyweight + 0.2) * 10).rounded() / 10 }
            )

            VStack(spacing: 8) {
                ValueStepper(
                    label: "Protein so far · g",
                    value: "\(protein)",
                    decrementLabel: "10 grams less",
                    incrementLabel: "10 grams more",
                    canDecrement: protein > 0,
                    onDecrement: { protein = max(0, protein - 10) },
                    onIncrement: { protein += 10 }
                )
                Text(proteinNote)
                    .textStyle(.readout).textCase(.uppercase)
                    .foregroundStyle(protein >= checkIn.proteinTargetMin ? Palette.positive : Palette.ink2)
                    .wipe(on: protein >= checkIn.proteinTargetMin)
                    .frame(maxWidth: .infinity)
            }

            if let error {
                Text(error).textStyle(.footnote).foregroundStyle(Palette.negative)
            }

            Spacer(minLength: 0)

            Button(saving ? "Saving…" : "Save check-in") {
                Task { await save() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(saving)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .presentationDetents([.height(600), .large])
        .presentationBackground(Palette.surface1)
        .presentationCornerRadius(20)
    }

    private var proteinNote: String {
        let target = "Target \(checkIn.proteinTargetMin)-\(checkIn.proteinTargetMax) g"
        if protein >= checkIn.proteinTargetMin { return "✓ " + target }
        return "\(checkIn.proteinTargetMin - protein) g to go · " + target
    }

    private func save() async {
        saving = true
        defer { saving = false }
        var updated = checkIn
        updated.bodyweight = bodyweight
        updated.proteinGrams = protein
        do {
            _ = try await model.repository.saveCheckIn(updated)
            await model.dataDidChange()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

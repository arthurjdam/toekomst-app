import SwiftUI

/// "−  VALUE  +" with 64-point buttons, as on the log-set sheet.
/// VoiceOver users adjust it with swipe up/down.
struct ValueStepper: View {
    let label: String
    let value: String
    var unit: String?
    let decrementLabel: String
    let incrementLabel: String
    var canDecrement = true
    var canIncrement = true
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            stepButton(.minus, label: decrementLabel, enabled: canDecrement, action: onDecrement)
            VStack(spacing: 2) {
                Text(label).textStyle(.label).foregroundStyle(Palette.ink2)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value).textStyle(.metricL).foregroundStyle(Palette.ink)
                        .glitch(on: value)
                    if let unit {
                        Text(unit).textStyle(.readout).foregroundStyle(Palette.ink2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue([value, unit].compactMap { $0 }.joined(separator: " "))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if canIncrement { onIncrement() }
                case .decrement: if canDecrement { onDecrement() }
                @unknown default: break
                }
            }
            stepButton(.plus, label: incrementLabel, enabled: canIncrement, action: onIncrement)
        }
    }

    private func stepButton(_ glyph: GlyphKind, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Glyph(glyph, size: 24, weight: 2)
                .foregroundStyle(Palette.ink)
                .frame(width: 64, height: 64)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableStyle())
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
        .accessibilityLabel(label)
    }
}

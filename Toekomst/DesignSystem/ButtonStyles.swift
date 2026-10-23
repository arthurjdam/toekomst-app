import SwiftUI

/// The 64-point signal button for the one primary action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 64
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.action)
            .foregroundStyle(theme.onSignal)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(configuration.isPressed ? theme.signalPress : theme.signal, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.38)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// A 44-point surface-2 button ("Move", "Change days", "-15s").
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.action)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .background(configuration.isPressed ? Palette.surface3 : Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.38)
    }
}

/// Outlined button for secondary actions inside the workout ("Skip move").
struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.action)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(configuration.isPressed ? Palette.surface2 : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.lineStrong, lineWidth: 1))
    }
}

/// Text-only button ("Cancel", "Skip check").
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.action)
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// A 44-point square icon button on surface-2.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.ink)
            .frame(width: 44, height: 44)
            .background(configuration.isPressed ? Palette.surface3 : Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Plain style that dims slightly while pressed, for custom-drawn rows and tiles.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

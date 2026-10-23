import SwiftUI

/// Torque design tokens. Toekomst is dark only: true black ground with
/// surfaces stepping up in lightness, one accent ("signal") used sparingly.
enum Palette {
    /// Screen ground.
    static let bg = Color(hex: 0x000000)
    /// Cards, grouped lists, sheets.
    static let surface1 = Color(hex: 0x0F1011)
    /// Controls on a card: segmented tracks, stepper buttons, icon tiles.
    static let surface2 = Color(hex: 0x1A1B1D)
    /// Pressed surface-2 controls and neutral badge fills. Never text.
    static let surface3 = Color(hex: 0x26282B)
    /// Decorative hairlines.
    static let line = Color(hex: 0x2A2C30)
    /// Borders that define a control.
    static let lineStrong = Color(hex: 0x686E75)
    /// Primary text, numbers and icons.
    static let ink = Color(hex: 0xF4F5F6)
    /// Secondary text: labels, details, units.
    static let ink2 = Color(hex: 0xA7ADB3)
    /// Tertiary text: hints and axis labels. Not on surface-3.
    static let ink3 = Color(hex: 0x848B92)
    /// Improvements and completed states; always with a glyph or word.
    static let positive = Color(hex: 0x5FD98E)
    /// Regressions and destructive actions; always with a glyph or word.
    static let negative = Color(hex: 0xFF5C5C)
    /// Non-current bars and inactive data marks.
    static let chartMuted = Color(hex: 0x5D636A)
}

/// The accent, which differs between the two Torque themes.
struct SignalTheme: Equatable {
    var signal: Color
    var signalPress: Color
    /// Flat tinted fill behind signal text (PR and "load up" badges).
    var signalDim: Color
    /// Text and icons on a signal fill.
    var onSignal: Color

    static let volt = SignalTheme(
        signal: Color(hex: 0xE4FF1A),
        signalPress: Color(hex: 0xC4DC12),
        signalDim: Color(hex: 0x262B04),
        onSignal: Color(hex: 0x000000)
    )

    static let greyscale = SignalTheme(
        signal: Palette.ink,
        signalPress: Color(hex: 0xC9CDD1),
        signalDim: Color(hex: 0x2A2C30),
        onSignal: Color(hex: 0x000000)
    )
}

enum AccentTheme: String, CaseIterable, Identifiable {
    case volt, greyscale

    var id: String { rawValue }

    var label: String {
        switch self {
        case .volt: return "Volt"
        case .greyscale: return "Greyscale"
        }
    }

    var colors: SignalTheme {
        switch self {
        case .volt: return .volt
        case .greyscale: return .greyscale
        }
    }
}

private struct SignalThemeKey: EnvironmentKey {
    static let defaultValue = SignalTheme.volt
}

extension EnvironmentValues {
    var theme: SignalTheme {
        get { self[SignalThemeKey.self] }
        set { self[SignalThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

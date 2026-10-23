import SwiftUI

/// Torque type scale. Kode Mono carries numbers, titles and labels; Barlow
/// carries readable text. Sizes scale with Dynamic Type relative to the
/// closest system style.
enum TextStyle {
    /// 88 pt mono: the one big number on a screen (working weight, total time).
    case metricXL
    /// 48 pt mono: secondary big numbers (reps, bodyweight).
    case metricL
    /// 26 pt mono: numbers in tiles and lists.
    case metricM
    /// 96 pt mono: the rest timer.
    case timer
    /// 128 pt mono: the circuit work timer.
    case huge
    /// 32 pt mono uppercase: screen titles.
    case titleL
    /// 19 pt mono uppercase: section and card titles.
    case titleM
    /// 15 pt mono uppercase: button labels.
    case action
    /// 11 pt mono uppercase: labels and badges.
    case label
    /// 13 pt mono: readouts ("4 × 6-8 · 185 lb").
    case readout
    /// 17 pt Barlow semibold: list item titles.
    case headline
    /// 17 pt Barlow.
    case body
    /// 15 pt Barlow medium.
    case callout
    /// 13 pt Barlow.
    case footnote

    fileprivate var spec: (font: String, size: CGFloat, tracking: CGFloat, uppercase: Bool, relativeTo: Font.TextStyle) {
        switch self {
        case .metricXL: return (FontName.monoBold, 88, -0.02, false, .largeTitle)
        case .metricL: return (FontName.monoBold, 48, -0.01, false, .largeTitle)
        case .metricM: return (FontName.monoBold, 26, -0.01, false, .title)
        case .timer: return (FontName.monoBold, 96, -0.03, false, .largeTitle)
        case .huge: return (FontName.monoBold, 128, -0.04, false, .largeTitle)
        case .titleL: return (FontName.monoBold, 32, 0, true, .largeTitle)
        case .titleM: return (FontName.monoBold, 19, 0.01, true, .title3)
        case .action: return (FontName.monoBold, 15, 0.04, true, .headline)
        case .label: return (FontName.monoMedium, 11, 0.06, true, .caption2)
        case .readout: return (FontName.monoMedium, 13, 0, false, .footnote)
        case .headline: return (FontName.textSemiBold, 17, 0, false, .headline)
        case .body: return (FontName.textRegular, 17, 0, false, .body)
        case .callout: return (FontName.textMedium, 15, 0, false, .callout)
        case .footnote: return (FontName.textRegular, 13, 0, false, .footnote)
        }
    }

    var font: Font {
        Font.custom(spec.font, size: spec.size, relativeTo: spec.relativeTo)
    }
}

/// PostScript names of the bundled fonts (registered through `UIAppFonts`).
enum FontName {
    static let monoRegular = "KodeMono-Regular"
    static let monoMedium = "KodeMono-Medium"
    static let monoBold = "KodeMono-Bold"
    static let textRegular = "Barlow-Regular"
    static let textMedium = "Barlow-Medium"
    static let textSemiBold = "Barlow-SemiBold"
    static let textBold = "Barlow-Bold"
}

private struct TextStyleModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        let spec = style.spec
        content
            .font(style.font)
            .tracking(spec.size * spec.tracking)
            .textCase(spec.uppercase ? .uppercase : nil)
            .monospacedDigit()
    }
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}

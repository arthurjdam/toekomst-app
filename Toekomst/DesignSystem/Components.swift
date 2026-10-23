import SwiftUI
import ToekomstKit

// MARK: - Badges

enum BadgeStyle {
    /// Neutral fill (phase, "On pace").
    case neutral
    /// Outlined (lower mass, "Core").
    case outline
    /// Signal fill (conditioning).
    case signal
    /// Signal text on a dim signal fill ("▲ Load up", "PR").
    case signalDim
}

/// A small mono label in a 20-point pill.
struct Badge: View {
    let text: String
    var style: BadgeStyle = .neutral
    var foreground: Color?
    var glyph: GlyphKind?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            if let glyph { Glyph(glyph, size: 12) }
            Text(text)
        }
        .textStyle(.label)
        .lineLimit(1)
        .foregroundStyle(foreground ?? defaultForeground)
        .padding(.horizontal, 6)
        .frame(minHeight: 20)
        .background(background, in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            if style == .outline {
                RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.lineStrong, lineWidth: 1)
            }
        }
        .fixedSize()
    }

    private var defaultForeground: Color {
        switch style {
        case .neutral, .outline: return Palette.ink
        case .signal: return theme.onSignal
        case .signalDim: return theme.signal
        }
    }

    private var background: Color {
        switch style {
        case .neutral: return Palette.surface3
        case .outline: return .clear
        case .signal: return theme.signal
        case .signalDim: return theme.signalDim
        }
    }
}

/// The session-type badge, styled the same everywhere.
struct KindBadge: View {
    let kind: SessionKind

    var body: some View {
        switch kind {
        case .conditioning: Badge(text: kind.displayName, style: .signal)
        case .upperMass: Badge(text: kind.displayName, style: .neutral)
        case .lowerMass: Badge(text: kind.displayName, style: .outline)
        }
    }
}

/// The badge for a planned load change ("▲ +5", "▲ Load up").
struct ProgressionBadge: View {
    let hint: ProgressionHint?
    var long = false

    var body: some View {
        if let hint, hint.direction == .increase {
            Badge(text: long ? "▲ Load up" : "▲ " + Format.signedWeight(hint.loadChange ?? TrainingRules.loadIncrement), style: .signalDim)
        } else if let hint, hint.direction == .hold || hint.direction == .decrease {
            Badge(text: "= Hold", style: .neutral)
        }
    }
}

// MARK: - Containers

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: radius))
    }
}

/// "LABEL ............ DETAIL" above a section.
struct SectionHeader: View {
    let title: String
    var detail: String?
    var detailColor: Color = Palette.ink3

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Palette.ink2)
            Spacer(minLength: 8)
            if let detail { Text(detail).foregroundStyle(detailColor) }
        }
        .textStyle(.label)
        .accessibilityElement(children: .combine)
    }
}

/// A 1-point separator in the hairline color.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Palette.line).frame(height: 1)
    }
}

/// The 48-point tile with an exercise's two-letter code.
struct ExerciseThumb: View {
    let code: String
    var emphasized = false
    var size: CGFloat = 48

    var body: some View {
        Text(code)
            .textStyle(.label)
            .foregroundStyle(emphasized ? Palette.ink : Palette.ink2)
            .frame(width: size, height: size)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

/// A 44-point square icon tile used in list rows.
struct IconTile: View {
    let glyph: GlyphKind
    var color: Color = Palette.ink
    var weight: CGFloat = 1.75

    var body: some View {
        Glyph(glyph, size: 22, weight: weight)
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Set boxes: filled for done, heavy outline for current, thin outline for upcoming.
struct SetBoxes: View {
    let total: Int
    let done: Int
    var currentColor: Color = Palette.ink

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                if index < done {
                    RoundedRectangle(cornerRadius: 2).fill(Palette.ink).frame(width: 10, height: 10)
                } else if index == done {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(currentColor, lineWidth: 2).frame(width: 10, height: 10)
                } else {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.lineStrong, lineWidth: 1).frame(width: 10, height: 10)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// One option of a segmented control or choice grid.
struct Choice<Value: Hashable>: Hashable {
    let value: Value
    let label: String
}

/// Segmented control on a surface-2 track (Progress range, camera angle).
struct SegmentedControl<Value: Hashable>: View {
    let options: [Choice<Value>]
    @Binding var selection: Value
    var height: CGFloat = 36
    var accessibilityLabel: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .textStyle(.action)
                        .foregroundStyle(selected ? Palette.ink : Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(selected ? Palette.surface3 : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A row of equal choice buttons; the selected one turns ink-on-black inverted.
struct ChoiceGrid<Value: Hashable>: View {
    let options: [Choice<Value>]
    let selection: Value?
    var height: CGFloat = 64
    var textStyle: TextStyle = .action
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    onSelect(option.value)
                } label: {
                    Text(option.label)
                        .textStyle(textStyle)
                        .foregroundStyle(selected ? Palette.bg : Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(selected ? Palette.ink : Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Grabber at the top of custom sheets.
struct SheetGrabber: View {
    var body: some View {
        Capsule().fill(Palette.lineStrong).frame(width: 36, height: 5).frame(maxWidth: .infinity)
    }
}

// MARK: - Loading

enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// Spinner while loading, an error with retry on failure.
struct LoadingView: View {
    var message: String?
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            if let message {
                Text(message)
                    .textStyle(.callout)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                if let retry {
                    Button("Try again", action: retry).buttonStyle(SecondaryButtonStyle())
                }
            } else {
                ProgressView().tint(Palette.ink2)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

/// Torque motion. Two kinds of movement and nothing else:
///
/// - **Flat**: anything that can interpolate (position, size, opacity, color)
///   eases out with no overshoot, no scaling, no blur. Pages, progress bars,
///   selection highlights and charts all use it.
/// - **Wipe**: text that can't interpolate (a number or label swapping) is
///   covered by a white bar growing from the left; the text swaps underneath;
///   the bar then leaves towards the right. Figures that swap cross-fade.
///
/// With Reduce Motion on, pages fade instead of sliding and wipes are skipped.
enum Motion {
    /// The house curve: fast start, soft landing, no overshoot.
    static let flat = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.22)
    /// Page changes: the same curve, a little longer.
    static let page = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.3)
    /// Once-a-second countdown visuals.
    static let tick = Animation.linear(duration: 0.25)
    /// One workout screen morphing into the next. Long enough to follow the
    /// card, title and numbers to their new places.
    static let stage = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.45)
    /// Each step of the session progress bar (fill, then collapse and expand).
    static let progress = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.4)
    /// A full text wipe: cover in, then out.
    static let wipe = Animation.linear(duration: 0.42)
    /// How far a page travels as it fades in or out.
    static let pageOffset: CGFloat = 32
}

extension AnyTransition {
    /// A page slides a short way in the direction of travel while fading.
    static func flatPush(forward: Bool = true, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let distance = Motion.pageOffset * (forward ? 1 : -1)
        return .asymmetric(
            insertion: .offset(x: distance).combined(with: .opacity),
            removal: .offset(x: -distance).combined(with: .opacity)
        )
    }
}

/// Elements that carry over between workout screens. Each screen tags its
/// version of an element; when the screen changes, the element morphs (flat)
/// from its old frame to its new one instead of the page being swapped.
enum StageElement: Hashable {
    /// The exercise card: demo on the exercise screen, "up next" on rest and transition.
    case card
    /// The exercise name.
    case title
    /// The working weight (or time).
    case metric
    /// The set boxes and counter.
    case sets
    /// The main button at the bottom.
    case primary
}

private struct StageModifier: ViewModifier {
    let element: StageElement
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // Cards travelling across the screen is a lot of motion; just cross-fade.
            content
        } else {
            content.matchedGeometryEffect(id: element, in: namespace)
        }
    }
}

extension View {
    func stage(_ element: StageElement, in namespace: Namespace.ID) -> some View {
        modifier(StageModifier(element: element, namespace: namespace))
    }
}

/// One side of the wipe. The leaving text is covered by a bar growing from
/// the left during the first half and then disappears; the arriving text is
/// hidden during the first half and revealed as the bar shrinks towards the
/// right in the second half. Both meet fully covered at the midpoint.
private struct WipeCover: ViewModifier, Animatable {
    /// 0 to 1 over the whole wipe.
    var progress: Double
    let leaving: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Ease-out within each half, so the bar lands softly at each end.
    private func eased(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    private var visible: Bool { leaving ? progress < 0.5 : progress >= 0.5 }

    private var coverFraction: Double {
        leaving ? eased(progress * 2) : 1 - eased((progress - 0.5) * 2)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(width: geometry.size.width * coverFraction)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leaving ? .leading : .trailing)
                }
                .allowsHitTesting(false)
            }
            .opacity(visible ? 1 : 0)
    }
}

extension AnyTransition {
    /// Old text is covered from the left, new text is revealed towards the right.
    static var wipe: AnyTransition {
        .asymmetric(
            // Arriving: progress runs 0 → 1 as it settles into place.
            insertion: .modifier(active: WipeCover(progress: 0, leaving: false), identity: WipeCover(progress: 1, leaving: false)),
            // Leaving: progress runs 0 → 1 as it goes.
            removal: .modifier(active: WipeCover(progress: 1, leaving: true), identity: WipeCover(progress: 0, leaving: true))
        )
    }
}

private struct WipeModifier<Trigger: Hashable>: ViewModifier {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            // A new identity per value keeps the old text on screen (leaving)
            // while the new one arrives, so the bar really covers the old text.
            ZStack {
                content
                    .id(trigger)
                    .transition(.wipe)
            }
            .animation(Motion.wipe, value: trigger)
        }
    }
}

private struct CrossfadeModifier<Trigger: Hashable>: ViewModifier {
    let trigger: Trigger

    func body(content: Content) -> some View {
        ZStack {
            content
                .id(trigger)
                .transition(.opacity)
        }
        .animation(Motion.flat, value: trigger)
    }
}

extension View {
    /// Wipes whenever `trigger` changes. Use for text that swaps rather than moves.
    func wipe<Trigger: Hashable>(on trigger: Trigger) -> some View {
        modifier(WipeModifier(trigger: trigger))
    }

    /// Cross-fades whenever `trigger` changes. Use for figures and other large content.
    func crossfade<Trigger: Hashable>(on trigger: Trigger) -> some View {
        modifier(CrossfadeModifier(trigger: trigger))
    }
}

/// Coarse loading state, for animating between spinner, content and error.
enum LoadPhase: Hashable {
    case loading, loaded, failed
}

extension LoadState {
    var phase: LoadPhase {
        switch self {
        case .loading: return .loading
        case .loaded: return .loaded
        case .failed: return .failed
        }
    }
}

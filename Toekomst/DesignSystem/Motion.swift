import SwiftUI

/// Torque motion. Two kinds of movement and nothing else:
///
/// - **Flat**: anything that can interpolate (position, size, opacity, color)
///   eases out with no overshoot, no scaling, no blur. Pages, progress bars,
///   selection highlights and charts all use it.
/// - **Glitch**: values that can't interpolate (a number or label swapping,
///   a demo figure redrawing) jitter sideways in hard steps with a signal
///   scan line, then settle.
///
/// With Reduce Motion on, pages fade instead of sliding and glitches are skipped.
enum Motion {
    /// The house curve: fast start, soft landing, no overshoot.
    static let flat = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.22)
    /// Page changes: the same curve, a little longer.
    static let page = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.3)
    /// Once-a-second countdown visuals.
    static let tick = Animation.linear(duration: 0.25)
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

struct GlitchFrame {
    var offset: CGFloat = 0
    var opacity: Double = 1
    var scan: Double = 0
    var scanY: CGFloat = 0
}

private struct GlitchModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: GlitchFrame(), trigger: trigger) { view, frame in
                view
                    .offset(x: frame.offset)
                    .opacity(frame.opacity)
                    .overlay {
                        Rectangle()
                            .fill(theme.signal)
                            .frame(height: 2)
                            .offset(y: frame.scanY)
                            .opacity(frame.scan)
                            .allowsHitTesting(false)
                    }
            } keyframes: { _ in
                // Hard steps (move, then hold) rather than smooth curves.
                KeyframeTrack(\.offset) {
                    MoveKeyframe(-4)
                    LinearKeyframe(-4, duration: 0.05)
                    MoveKeyframe(3)
                    LinearKeyframe(3, duration: 0.05)
                    MoveKeyframe(-2)
                    LinearKeyframe(-2, duration: 0.04)
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.04)
                    MoveKeyframe(0)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0.4)
                    LinearKeyframe(0.4, duration: 0.05)
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.05)
                    MoveKeyframe(0.7)
                    LinearKeyframe(0.7, duration: 0.04)
                    MoveKeyframe(1)
                }
                KeyframeTrack(\.scan) {
                    MoveKeyframe(0.9)
                    LinearKeyframe(0.9, duration: 0.14)
                    MoveKeyframe(0)
                }
                KeyframeTrack(\.scanY) {
                    MoveKeyframe(-5)
                    LinearKeyframe(-5, duration: 0.05)
                    MoveKeyframe(4)
                    LinearKeyframe(4, duration: 0.05)
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: 0.04)
                }
            }
        }
    }
}

extension View {
    /// Plays the glitch whenever `trigger` changes. Use for content that swaps
    /// rather than moves: labels, numbers, figures.
    func glitch<Trigger: Equatable>(on trigger: Trigger) -> some View {
        modifier(GlitchModifier(trigger: trigger))
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

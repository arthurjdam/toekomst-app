import SwiftUI
import ToekomstKit

/// Says the workout is running: an outlined chip with a blinking signal
/// square, the elapsed time with a blinking colon, and "Live".
/// While paused (or before the ready check) nothing blinks.
struct LiveIndicator: View {
    let startedAt: Date
    let isRunning: Bool
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 0.5)) { context in
            let elapsed = isRunning ? max(0, context.date.timeIntervalSince(startedAt)) : 0
            let seconds = Int(elapsed)
            // On for the first half of every second, off for the second half.
            let blinkOn = !isRunning || reduceMotion || Int(elapsed * 2) % 2 == 0
            HStack(spacing: 10) {
                Rectangle()
                    .fill(isRunning ? theme.signal : Palette.ink3)
                    .frame(width: 10, height: 10)
                    .opacity(blinkOn ? 1 : 0)
                // The colon blinks by fading, not by being removed, so nothing shifts.
                HStack(spacing: 0) {
                    Text("\(seconds / 60)")
                    Text(":").opacity(blinkOn ? 1 : 0)
                    Text(String(format: "%02d", seconds % 60))
                }
                .font(.custom(FontName.monoBold, size: 13, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                Text(isRunning ? "Live" : "Paused")
                    .textStyle(.label)
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 32)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.lineStrong, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isRunning ? "Workout live, elapsed time" : "Workout paused")
            .accessibilityValue("\(seconds / 60) minutes \(seconds % 60) seconds")
        }
    }
}

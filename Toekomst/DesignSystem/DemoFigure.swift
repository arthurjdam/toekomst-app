import SwiftUI

/// Line-drawn exercise demos from the Torque design: a blueprint grid, the
/// body in ink, joints marked in signal. Exercises without a drawing show
/// the grid and their movement code until real demo media comes from the
/// back-end.
struct DemoFigure: View {
    let demo: String?
    var angle: String = "side"
    let code: String
    var gridColor: Color = Palette.surface2
    @Environment(\.theme) private var theme

    var body: some View {
        let figure = Figure.make(demo: demo, angle: angle)
        Canvas { context, size in
            drawGrid(in: &context, size: size)
            guard let figure else { return }
            let scale = min(size.width / figure.viewBox.width, size.height / figure.viewBox.height)
            context.translateBy(
                x: (size.width - figure.viewBox.width * scale) / 2,
                y: (size.height - figure.viewBox.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            figure.draw(&context, FigureInk(ink: Palette.ink, signal: theme.signal, guide: Palette.lineStrong))
        }
        .overlay {
            if figure == nil {
                Text(code)
                    .textStyle(.metricL)
                    .foregroundStyle(Palette.lineStrong)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(figure?.label ?? "No demo yet")
        .accessibilityAddTraits(.isImage)
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        var grid = Path()
        var y: CGFloat = 16
        while y < size.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += 40
        }
        var x = size.width / 2 - 20
        while x > 0 { x -= 40 }
        x += 40
        while x < size.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += 40
        }
        context.stroke(grid, with: .color(gridColor), lineWidth: 1)
    }
}

struct FigureInk {
    let ink: Color
    let signal: Color
    let guide: Color
}

private struct Figure {
    let viewBox: CGSize
    let label: String
    let draw: (inout GraphicsContext, FigureInk) -> Void

    static func make(demo: String?, angle: String) -> Figure? {
        switch (demo, angle) {
        case ("back-squat", "front"): return backSquatFront
        case ("back-squat", _): return backSquatSide
        case ("split-squat", _): return splitSquat
        case ("kettlebell-swing", _): return kettlebellSwing
        default: return nil
        }
    }

    static let bodyStroke = StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .miter)

    static func lines(_ segments: [[CGPoint]]) -> Path {
        var path = Path()
        for segment in segments {
            guard let first = segment.first else { continue }
            path.move(to: first)
            for point in segment.dropFirst() { path.addLine(to: point) }
        }
        return path
    }

    static func joints(_ points: [CGPoint], in context: inout GraphicsContext, color: Color) {
        for point in points {
            context.fill(Path(CGRect(x: point.x, y: point.y, width: 8, height: 8)), with: .color(color))
        }
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static let backSquatSide = Figure(viewBox: CGSize(width: 350, height: 272), label: "Demo: back squat, side view, bottom position") { context, ink in
        context.stroke(Figure.lines([[CGPoint(x: 40, y: 234), CGPoint(x: 310, y: 234)]]), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(
            lines([[CGPoint(x: 187, y: 40), CGPoint(x: 187, y: 234)]]),
            with: .color(ink.signal), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5])
        )
        context.stroke(Figure.circle(CGPoint(x: 168, y: 118), 34), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(Figure.lines([
            [CGPoint(x: 178, y: 232), CGPoint(x: 204, y: 232)],
            [CGPoint(x: 182, y: 230), CGPoint(x: 212, y: 186), CGPoint(x: 142, y: 182), CGPoint(x: 172, y: 116)],
            [CGPoint(x: 172, y: 116), CGPoint(x: 152, y: 138), CGPoint(x: 166, y: 118)]
        ]), with: .color(ink.ink), style: Figure.bodyStroke)
        context.stroke(Figure.circle(CGPoint(x: 186, y: 96), 14), with: .color(ink.ink), lineWidth: 3)
        Figure.joints([CGPoint(x: 138, y: 178), CGPoint(x: 208, y: 182), CGPoint(x: 178, y: 226)], in: &context, color: ink.signal)
        context.fill(Figure.circle(CGPoint(x: 168, y: 118), 4), with: .color(ink.ink))
    }

    static let backSquatFront = Figure(viewBox: CGSize(width: 350, height: 272), label: "Demo: back squat, front view, bottom position") { context, ink in
        context.stroke(Figure.lines([[CGPoint(x: 40, y: 234), CGPoint(x: 310, y: 234)]]), with: .color(ink.guide), lineWidth: 1.75)
        // Bar and plates.
        context.stroke(Figure.lines([[CGPoint(x: 92, y: 118), CGPoint(x: 258, y: 118)]]), with: .color(ink.ink), lineWidth: 3)
        context.stroke(Path(CGRect(x: 96, y: 96, width: 12, height: 44)), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(Path(CGRect(x: 242, y: 96, width: 12, height: 44)), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(Figure.lines([
            [CGPoint(x: 140, y: 232), CGPoint(x: 160, y: 232)],
            [CGPoint(x: 190, y: 232), CGPoint(x: 210, y: 232)],
            // Legs: feet, knees out over toes, hips.
            [CGPoint(x: 150, y: 230), CGPoint(x: 128, y: 190), CGPoint(x: 160, y: 176)],
            [CGPoint(x: 200, y: 230), CGPoint(x: 222, y: 190), CGPoint(x: 190, y: 176)],
            // Pelvis and torso.
            [CGPoint(x: 160, y: 176), CGPoint(x: 190, y: 176)],
            [CGPoint(x: 175, y: 176), CGPoint(x: 175, y: 120)],
            // Arms up to the bar.
            [CGPoint(x: 160, y: 126), CGPoint(x: 140, y: 120)],
            [CGPoint(x: 190, y: 126), CGPoint(x: 210, y: 120)]
        ]), with: .color(ink.ink), style: Figure.bodyStroke)
        context.stroke(Figure.circle(CGPoint(x: 175, y: 92), 14), with: .color(ink.ink), lineWidth: 3)
        Figure.joints([CGPoint(x: 124, y: 186), CGPoint(x: 218, y: 186), CGPoint(x: 171, y: 172)], in: &context, color: ink.signal)
    }

    static let splitSquat = Figure(viewBox: CGSize(width: 350, height: 196), label: "Demo: Bulgarian split squat, side view") { context, ink in
        context.stroke(Figure.lines([[CGPoint(x: 40, y: 172), CGPoint(x: 310, y: 172)]]), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(Path(CGRect(x: 88, y: 128, width: 54, height: 10)), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(Figure.lines([
            [CGPoint(x: 100, y: 138), CGPoint(x: 100, y: 172)],
            [CGPoint(x: 130, y: 138), CGPoint(x: 130, y: 172)]
        ]), with: .color(ink.guide), lineWidth: 1.75)
        context.stroke(Figure.lines([
            [CGPoint(x: 210, y: 170), CGPoint(x: 230, y: 170)],
            [CGPoint(x: 214, y: 168), CGPoint(x: 218, y: 124), CGPoint(x: 176, y: 112), CGPoint(x: 150, y: 152), CGPoint(x: 118, y: 128)],
            [CGPoint(x: 176, y: 112), CGPoint(x: 180, y: 58)],
            [CGPoint(x: 180, y: 64), CGPoint(x: 176, y: 100)]
        ]), with: .color(ink.ink), style: Figure.bodyStroke)
        context.stroke(Figure.circle(CGPoint(x: 182, y: 42), 12), with: .color(ink.ink), lineWidth: 3)
        context.fill(Path(CGRect(x: 168, y: 100, width: 16, height: 8)), with: .color(ink.ink))
        Figure.joints([CGPoint(x: 172, y: 108), CGPoint(x: 214, y: 120), CGPoint(x: 146, y: 148)], in: &context, color: ink.signal)
    }

    static let kettlebellSwing = Figure(viewBox: CGSize(width: 350, height: 208), label: "Demo: kettlebell swing, hinge position") { context, ink in
        context.stroke(Figure.lines([[CGPoint(x: 40, y: 184), CGPoint(x: 310, y: 184)]]), with: .color(ink.guide), lineWidth: 1.75)
        var arc = Path()
        // The bell's path: SVG arc from (150,150) to (250,60), radius 70.
        arc.addArc(center: CGPoint(x: 187.05, y: 90.61), radius: 70, startAngle: .degrees(121.95), endAngle: .degrees(-25.93), clockwise: true)
        context.stroke(arc, with: .color(ink.signal), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
        context.stroke(Figure.lines([
            [CGPoint(x: 160, y: 182), CGPoint(x: 182, y: 182)],
            [CGPoint(x: 164, y: 180), CGPoint(x: 172, y: 140), CGPoint(x: 140, y: 112), CGPoint(x: 198, y: 82)],
            [CGPoint(x: 198, y: 82), CGPoint(x: 180, y: 140)]
        ]), with: .color(ink.ink), style: Figure.bodyStroke)
        context.stroke(Figure.circle(CGPoint(x: 214, y: 72), 12), with: .color(ink.ink), lineWidth: 3)
        context.fill(Figure.circle(CGPoint(x: 178, y: 158), 12), with: .color(ink.ink))
        context.fill(Path(CGRect(x: 172, y: 140, width: 12, height: 6)), with: .color(ink.ink))
        Figure.joints([CGPoint(x: 136, y: 108), CGPoint(x: 168, y: 136)], in: &context, color: ink.signal)
    }
}

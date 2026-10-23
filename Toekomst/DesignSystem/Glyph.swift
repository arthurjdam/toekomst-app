import SwiftUI

/// The Torque icon set: square-capped strokes on a 24-point grid, drawn
/// natively so they scale crisply and take the current foreground style.
enum GlyphKind {
    case chevronRight, chevronLeft, check, play, pause, plus, minus, info, skip
    case bolt, boltFilled, scale, dragHandle, close, note
    case tabToday, tabSchedule, tabProgress, tabSettings

    /// Stroked parts, in 24-unit coordinates.
    fileprivate func stroke(_ p: inout GridPath) {
        switch self {
        case .chevronRight: p.lines([(9, 5), (16, 12), (9, 19)])
        case .chevronLeft: p.lines([(15, 5), (8, 12), (15, 19)])
        case .check: p.lines([(5, 12.5), (9.5, 17), (19, 7.5)])
        case .plus: p.lines([(5, 12), (19, 12)]); p.lines([(12, 5), (12, 19)])
        case .minus: p.lines([(5, 12), (19, 12)])
        case .info:
            p.circle(center: (12, 12), radius: 9)
            p.lines([(12, 11), (12, 17)]); p.lines([(12, 7), (12, 8)])
        case .skip: p.lines([(6, 5), (13, 12), (6, 19)]); p.lines([(17, 5), (17, 19)])
        case .bolt: p.lines([(13, 3), (5, 14), (11, 14), (10, 21), (18, 10), (12, 10), (13, 3)])
        case .scale:
            p.rect(x: 3.5, y: 3.5, width: 17, height: 17)
            p.lines([(8, 9.5), (16, 9.5)]); p.lines([(12, 9.5), (14, 7)])
        case .dragHandle: p.lines([(5, 8), (19, 8)]); p.lines([(5, 12), (19, 12)]); p.lines([(5, 16), (19, 16)])
        case .close: p.lines([(6, 6), (18, 18)]); p.lines([(18, 6), (6, 18)])
        case .note: p.rect(x: 5, y: 4, width: 14, height: 16); p.lines([(8.5, 9), (15.5, 9)]); p.lines([(8.5, 13), (13, 13)])
        case .tabToday: p.rect(x: 4, y: 4, width: 16, height: 16); p.lines([(4, 9), (20, 9)])
        case .tabSchedule: p.lines([(4, 6), (20, 6)]); p.lines([(4, 12), (20, 12)]); p.lines([(4, 18), (14, 18)])
        case .tabProgress: p.lines([(4, 18), (9, 12), (13, 15), (20, 6)]); p.lines([(4, 21), (20, 21)])
        case .tabSettings:
            p.lines([(4, 7), (13, 7)]); p.lines([(17, 7), (20, 7)]); p.lines([(4, 17), (7, 17)]); p.lines([(11, 17), (20, 17)])
            p.rect(x: 13, y: 4.5, width: 4, height: 5); p.rect(x: 7, y: 14.5, width: 4, height: 5)
        case .play, .pause, .boltFilled: break
        }
    }

    /// Filled parts, in 24-unit coordinates.
    fileprivate func fill(_ p: inout GridPath) {
        switch self {
        case .play: p.polygon([(7, 4.5), (20, 12), (7, 19.5)])
        case .pause: p.rect(x: 6, y: 5, width: 4, height: 14); p.rect(x: 14, y: 5, width: 4, height: 14)
        case .boltFilled: p.polygon([(13, 2), (4, 14), (10.5, 14), (9.5, 22), (18.5, 10), (12, 10)])
        case .tabToday: p.rect(x: 10, y: 12.5, width: 4, height: 4)
        default: break
        }
    }
}

/// Builds a path from 24-unit grid coordinates scaled into a rect.
private struct GridPath {
    var path = Path()
    let scale: CGFloat
    let origin: CGPoint

    init(in rect: CGRect) {
        scale = min(rect.width, rect.height) / 24
        origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
    }

    func point(_ p: (CGFloat, CGFloat)) -> CGPoint {
        CGPoint(x: origin.x + p.0 * scale, y: origin.y + p.1 * scale)
    }

    mutating func lines(_ points: [(CGFloat, CGFloat)]) {
        guard let first = points.first else { return }
        path.move(to: point(first))
        for p in points.dropFirst() { path.addLine(to: point(p)) }
    }

    mutating func polygon(_ points: [(CGFloat, CGFloat)]) {
        lines(points)
        path.closeSubpath()
    }

    mutating func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        path.addRect(CGRect(origin: point((x, y)), size: CGSize(width: width * scale, height: height * scale)))
    }

    mutating func circle(center: (CGFloat, CGFloat), radius: CGFloat) {
        let c = point(center)
        path.addEllipse(in: CGRect(x: c.x - radius * scale, y: c.y - radius * scale, width: radius * 2 * scale, height: radius * 2 * scale))
    }
}

private struct GlyphStrokeShape: Shape {
    let kind: GlyphKind
    func path(in rect: CGRect) -> Path {
        var grid = GridPath(in: rect)
        kind.stroke(&grid)
        return grid.path
    }
}

private struct GlyphFillShape: Shape {
    let kind: GlyphKind
    func path(in rect: CGRect) -> Path {
        var grid = GridPath(in: rect)
        kind.fill(&grid)
        return grid.path
    }
}

/// A Torque icon. Decorative by default; give icon-only buttons an accessibility label.
struct Glyph: View {
    let kind: GlyphKind
    var size: CGFloat = 24
    /// Stroke weight in grid units (1.75 regular, 2-2.5 for emphasis).
    var weight: CGFloat = 1.75

    init(_ kind: GlyphKind, size: CGFloat = 24, weight: CGFloat = 1.75) {
        self.kind = kind
        self.size = size
        self.weight = weight
    }

    var body: some View {
        ZStack {
            GlyphStrokeShape(kind: kind)
                .stroke(style: StrokeStyle(lineWidth: weight * size / 24, lineCap: .square, lineJoin: .miter))
            GlyphFillShape(kind: kind)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

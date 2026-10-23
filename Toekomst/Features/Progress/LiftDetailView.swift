import Charts
import SwiftUI
import ToekomstKit

/// One core lift's estimated max over the selected range.
struct LiftDetailView: View {
    let lift: LiftTrend
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        ScreenScroll {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Glyph(.chevronLeft, size: 22)
                    Text("Progress").textStyle(.action)
                }
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .padding(.leading, -6)
            .accessibilityLabel("Back to Progress")

            VStack(alignment: .leading, spacing: 8) {
                Text("Core lift · est. max").textStyle(.label).foregroundStyle(Palette.ink2)
                Text(lift.name).textStyle(.titleL).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.weight(lift.estimatedMax.rounded())).textStyle(.metricXL).foregroundStyle(Palette.ink)
                    Text("lb").textStyle(.readout).foregroundStyle(Palette.ink2)
                    Spacer()
                    Text("\(lift.change >= 0 ? "▲" : "▼") \(Int((abs(lift.change) * 100).rounded()))%")
                        .textStyle(.readout).foregroundStyle(lift.change >= 0 ? Palette.positive : Palette.negative)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    chart.frame(height: 200)
                    if let index = lift.latestBlockStartIndex {
                        HStack(spacing: 8) {
                            Rectangle().fill(Palette.lineStrong).frame(width: 1, height: 12)
                            Text("\(blockName(lift.points[index].blockNumber)) starts \(Format.dayHeader(lift.points[index].date))")
                                .textStyle(.footnote).foregroundStyle(Palette.ink2)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "By week")
                VStack(spacing: 0) {
                    let rows = Array(lift.points.reversed().enumerated())
                    ForEach(rows, id: \.offset) { index, point in
                        HStack {
                            Text(Format.dayHeader(point.date)).textStyle(.readout).textCase(.uppercase).foregroundStyle(Palette.ink2)
                            Text(blockName(point.blockNumber)).textStyle(.label).foregroundStyle(Palette.ink3)
                            Spacer()
                            Text("\(Format.weight(point.estimatedMax)) lb").textStyle(.readout).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) { if index < rows.count - 1 { Hairline() } }
                        .accessibilityElement(children: .combine)
                    }
                }
                .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private var chart: some View {
        let values = lift.points.map(\.estimatedMax)
        let low = ((values.min() ?? 0) - 5).rounded(.down)
        let high = ((values.max() ?? 1) + 5).rounded(.up)
        return Chart {
            if let index = lift.latestBlockStartIndex {
                RuleMark(x: .value("Week", index))
                    .foregroundStyle(Palette.lineStrong)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            ForEach(Array(lift.points.enumerated()), id: \.offset) { index, point in
                LineMark(x: .value("Week", index), y: .value("Estimated max", point.estimatedMax))
                    .foregroundStyle(Palette.ink)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let last = lift.points.last {
                PointMark(x: .value("Week", lift.points.count - 1), y: .value("Estimated max", last.estimatedMax))
                    .symbol(.square)
                    .symbolSize(64)
                    .foregroundStyle(theme.signal)
            }
        }
        .chartXScale(domain: 0...max(1, lift.points.count - 1))
        .chartYScale(domain: low...high)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Palette.line)
                AxisValueLabel {
                    if let pounds = value.as(Double.self) {
                        Text(Format.weight(pounds)).textStyle(.label).foregroundStyle(Palette.ink3)
                    }
                }
            }
        }
        .accessibilityLabel("\(lift.name) estimated max")
        .accessibilityValue("From \(Format.weight(values.first ?? 0)) to \(Format.weight(values.last ?? 0)) pounds")
    }
}

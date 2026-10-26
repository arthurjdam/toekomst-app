import Charts
import SwiftUI
import ToekomstKit

struct ProgressScreen: View {
    @Environment(AppModel.self) private var model
    @State private var range: ProgressRange = .twelveWeeks
    @State private var state: LoadState<ProgressOverview> = .loading

    var body: some View {
        ScreenScroll {
            VStack(alignment: .leading, spacing: 16) {
                Text("Progress").textStyle(.titleL).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                SegmentedControl(
                    options: ProgressRange.allCases.map { Choice(value: $0, label: $0.label) },
                    selection: $range,
                    accessibilityLabel: "Range"
                )
            }
            Group {
                switch state {
                case .loading:
                    LoadingView().frame(height: 300).transition(.opacity)
                case .failed(let message):
                    LoadingView(message: message) { Task { await load() } }
                        .transition(.opacity)
                case .loaded(let progress):
                    // A new range redraws the same cards: charts and bars move flat,
                    // numbers wipe.
                    VStack(alignment: .leading, spacing: 24) {
                        BodyweightCard(trend: progress.bodyweight, range: progress.range)
                        LiftsSection(lifts: progress.lifts)
                        VolumeCard(volume: progress.volume, windowWeeks: progress.volumeWindowWeeks)
                        ConsistencyCard(consistency: progress.consistency)
                    }
                    .transition(.opacity)
                }
            }
            .animation(Motion.flat, value: state.phase)
        }
        .refreshable { await load() }
        .task(id: LoadKey(range: range, version: model.dataVersion)) { await load() }
    }

    private struct LoadKey: Equatable {
        let range: ProgressRange
        let version: Int
    }

    private func load() async {
        do {
            let progress = try await model.repository.progress(range: range)
            withAnimation(Motion.flat) { state = .loaded(progress) }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct BodyweightCard: View {
    let trend: BodyweightTrend
    let range: ProgressRange
    @Environment(\.theme) private var theme

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bodyweight").textStyle(.label).foregroundStyle(Palette.ink2)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Format.weight(trend.current)).textStyle(.metricL).foregroundStyle(Palette.ink)
                                .wipe(on: trend.current)
                            Text("lb").textStyle(.readout).foregroundStyle(Palette.ink2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(trend.weeklyChange >= 0 ? "▲" : "▼") \(String(format: "%.2f", abs(trend.weeklyChange))) lb/wk")
                            .wipe(on: trend.weeklyChange)
                            .textStyle(.readout)
                            .foregroundStyle(trend.weeklyChange >= 0 ? Palette.positive : Palette.negative)
                        Badge(text: paceLabel).wipe(on: paceLabel)
                    }
                    .padding(.top, 2)
                }
                .accessibilityElement(children: .combine)

                chart
                    .frame(height: 140)

                HStack {
                    Text(startLabel).wipe(on: startLabel)
                    Spacer()
                    Text("Now")
                }
                .textStyle(.label).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)

                Hairline()
                HStack(spacing: 8) {
                    Rectangle().fill(Palette.surface3).frame(width: 16, height: 10)
                    Text(paceSentence).textStyle(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
    }

    private var paceLabel: String {
        switch trend.pace {
        case .onPace: return "On pace"
        case .belowTarget: return "Below pace"
        case .aboveTarget: return "Above pace"
        }
    }

    private var paceSentence: String {
        let band = "Target pace +\(Format.weight(trend.targetWeeklyMin)) to \(Format.weight(trend.targetWeeklyMax)) lb a week."
        switch trend.pace {
        case .onPace: return band + " You're inside it."
        case .belowTarget: return band + " You're under it; eat a little more."
        case .aboveTarget: return band + " You're over it; trim the surplus slightly."
        }
    }

    private var startLabel: String {
        guard let first = trend.points.first, let last = trend.points.last else { return "" }
        let weeks = first.date.days(until: last.date) / 7
        return "\(weeks) wks ago"
    }

    /// The target band starts at the first point and widens at the min and max weekly rate.
    private struct BandPoint {
        let date: Date
        let low: Double
        let high: Double
    }

    private var bandPoints: [BandPoint] {
        guard let first = trend.points.first else { return [] }
        return trend.points.map { point in
            let weeks = Double(first.date.days(until: point.date)) / 7
            return BandPoint(
                date: chartDate(point.date),
                low: first.weight + trend.targetWeeklyMin * weeks,
                high: first.weight + trend.targetWeeklyMax * weeks
            )
        }
    }

    private func chartDate(_ date: LocalDate) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? .now
    }

    private var chart: some View {
        let weights = trend.points.map(\.weight) + bandPoints.flatMap { [$0.low, $0.high] }
        let low = (weights.min() ?? 0) - 0.5
        let high = (weights.max() ?? 1) + 0.5
        return Chart {
            ForEach(bandPoints, id: \.date) { band in
                AreaMark(x: .value("Week", band.date), yStart: .value("Low", band.low), yEnd: .value("High", band.high))
                    .foregroundStyle(Palette.surface3)
                    .interpolationMethod(.linear)
            }
            ForEach(trend.points, id: \.date) { point in
                LineMark(x: .value("Week", chartDate(point.date)), y: .value("Weight", point.weight))
                    .foregroundStyle(Palette.ink)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .miter))
            }
            if let last = trend.points.last {
                PointMark(x: .value("Week", chartDate(last.date)), y: .value("Weight", last.weight))
                    .symbol(.square)
                    .symbolSize(64)
                    .foregroundStyle(theme.signal)
            }
        }
        .chartYScale(domain: low...high)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Palette.line)
            }
        }
        .accessibilityLabel("Bodyweight over \(startLabel.replacingOccurrences(of: " ago", with: ""))")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = trend.points.first, let last = trend.points.last else { return "" }
        let direction = last.weight >= first.weight ? "rising" : "falling"
        return "\(direction) from \(Format.weight(first.weight)) to \(Format.weight(last.weight)) pounds, \(paceLabel.lowercased())"
    }
}

private struct LiftsSection: View {
    let lifts: [LiftTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Core lifts · est. max", detail: blockLabel)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(lifts) { lift in
                    NavigationLink(value: Route.lift(lift)) {
                        LiftTile(lift: lift)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var blockLabel: String? {
        guard let points = lifts.first?.points, let latest = points.last?.blockNumber,
              let previous = points.last(where: { $0.blockNumber != latest })?.blockNumber
        else { return nil }
        return "\(blockName(previous)) | \(blockName(latest))"
    }
}

func blockName(_ number: Int) -> String {
    number < 1 ? "Ramp-up" : "Block \(number)"
}

private struct LiftTile: View {
    let lift: LiftTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lift.name).textStyle(.label).foregroundStyle(Palette.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.weight(lift.estimatedMax.rounded())).textStyle(.metricM).foregroundStyle(Palette.ink)
                    .wipe(on: lift.estimatedMax)
                Text("lb").textStyle(.readout).foregroundStyle(Palette.ink2)
                Spacer(minLength: 0)
                Text(changeText).textStyle(.readout).foregroundStyle(lift.change >= 0 ? Palette.positive : Palette.negative)
                    .wipe(on: changeText)
            }
            Sparkline(lift: lift)
                .frame(height: 40)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lift.name)
        .accessibilityValue("Estimated max \(Int(lift.estimatedMax.rounded())) pounds, \(changeText.replacingOccurrences(of: "▲ ", with: "up ").replacingOccurrences(of: "▼ ", with: "down "))")
        .accessibilityHint("Shows the trend")
    }

    private var changeText: String {
        "\(lift.change >= 0 ? "▲" : "▼") \(Int((abs(lift.change) * 100).rounded()))%"
    }
}

/// Estimated max per session with a dashed line where the latest block starts.
struct Sparkline: View {
    let lift: LiftTrend
    var lineWidth: CGFloat = 1.75

    var body: some View {
        let values = lift.points.map(\.estimatedMax)
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 1) + 1
        Chart {
            if let index = lift.latestBlockStartIndex {
                RuleMark(x: .value("Session", index))
                    .foregroundStyle(Palette.lineStrong)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            ForEach(Array(lift.points.enumerated()), id: \.offset) { index, point in
                LineMark(x: .value("Session", index), y: .value("Estimated max", point.estimatedMax))
                    .foregroundStyle(Palette.ink)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth))
            }
        }
        .chartXScale(domain: 0...max(1, lift.points.count - 1))
        .chartYScale(domain: low...high)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }
}

private struct VolumeCard: View {
    let volume: [VolumeEntry]
    let windowWeeks: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Weekly volume").textStyle(.titleM).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("Avg hard sets · \(windowWeeks) wks").textStyle(.label).foregroundStyle(Palette.ink2)
                }
                VStack(spacing: 10) {
                    ForEach(volume) { entry in
                        let under = entry.averageHardSets < Double(TrainingRules.weeklySetRange.lowerBound)
                        HStack(spacing: 10) {
                            Text(entry.muscle.displayName).textStyle(.callout).foregroundStyle(Palette.ink)
                                .frame(width: 104, alignment: .leading)
                            RangeBar(value: entry.averageHardSets, dimmed: under)
                            Text((under ? "▼ " : "") + Format.weight(entry.averageHardSets))
                                .textStyle(.readout)
                                .foregroundStyle(under ? Palette.negative : Palette.ink)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(entry.muscle.displayName)
                        .accessibilityValue("\(Format.weight(entry.averageHardSets)) hard sets a week\(under ? ", under target" : "")")
                    }
                }
            }
        }
    }
}

private struct ConsistencyCard: View {
    let consistency: Consistency
    @Environment(\.theme) private var theme

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consistency · \(consistency.completedWeeks.count) wks").textStyle(.label).foregroundStyle(Palette.ink2)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(consistency.completedSessions)/\(consistency.plannedSessions)").textStyle(.metricM).foregroundStyle(Palette.ink)
                            Text("sessions").textStyle(.readout).foregroundStyle(Palette.ink2)
                        }
                    }
                    Spacer()
                    Text("Goal \(consistency.goalPerWeek)/wk").textStyle(.label).foregroundStyle(Palette.ink3)
                }
                .accessibilityElement(children: .combine)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(consistency.weeks.enumerated()), id: \.offset) { index, week in
                        let current = index == consistency.weeks.count - 1
                        UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                            .fill(current ? theme.signal : Palette.chartMuted)
                            .frame(height: max(2, 72 * Double(week.sessions) / Double(max(1, consistency.goalPerWeek))))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 72, alignment: .bottom)
                .overlay(alignment: .bottom) { Hairline() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sessions per week")
                .accessibilityValue(consistency.weeks.map { "\($0.sessions)" }.joined(separator: ", ") + " so far this week")

                HStack {
                    Text("\(consistency.completedWeeks.count) wks ago")
                    Spacer()
                    Text("This wk")
                }
                .textStyle(.label).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
            }
        }
    }
}

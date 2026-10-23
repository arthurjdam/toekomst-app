import SwiftUI
import ToekomstKit

/// Hard sets per muscle group this week against the 10-20 target band.
struct MuscleCoverageCard: View {
    let coverage: [MuscleCoverage]
    let note: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Muscle coverage").textStyle(.titleM).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("Target \(TrainingRules.weeklySetRange.lowerBound)-\(TrainingRules.weeklySetRange.upperBound) sets")
                        .textStyle(.label).foregroundStyle(Palette.ink2)
                }
                HStack(spacing: 10) {
                    Color.clear.frame(width: 104, height: 1)
                    Text("Hard sets").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Sets").frame(width: 28, alignment: .trailing)
                    Text("Hits").frame(width: 28, alignment: .trailing)
                }
                .textStyle(.label).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
                VStack(spacing: 10) {
                    ForEach(coverage) { row in
                        CoverageRow(row: row)
                    }
                }
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.surface3).frame(width: 16, height: 8)
                        Text("\(TrainingRules.weeklySetRange.lowerBound)-\(TrainingRules.weeklySetRange.upperBound) band")
                    }
                    Text("▼ Under target")
                }
                .textStyle(.label).foregroundStyle(Palette.ink2)
                .padding(.top, 4)
                .accessibilityHidden(true)
                if let note {
                    Hairline()
                    Text(note).textStyle(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
    }
}

private struct CoverageRow: View {
    let row: MuscleCoverage

    private var status: CoverageStatus { CoverageStatus(row) }
    private var hitsShort: Bool { row.hits < TrainingRules.minimumWeeklyHits }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(row.muscle.displayName).textStyle(.callout).foregroundStyle(Palette.ink)
                if status == .under {
                    Text("▼").textStyle(.label).foregroundStyle(Palette.negative)
                }
            }
            .frame(width: 104, alignment: .leading)
            RangeBar(value: Double(row.hardSets), dimmed: status == .under)
            Text("\(row.hardSets)").textStyle(.readout)
                .foregroundStyle(row.hardSets < TrainingRules.weeklySetRange.lowerBound ? Palette.negative : Palette.ink)
                .frame(width: 28, alignment: .trailing)
            Text("\(row.hits)×").textStyle(.readout)
                .foregroundStyle(hitsShort ? Palette.negative : Palette.ink2)
                .frame(width: 28, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.muscle.displayName)
        .accessibilityValue("\(row.hardSets) hard sets, trained \(row.hits) times\(status == .under ? ", under target" : "")")
    }
}

/// A horizontal bar on a 0-24 set scale with the 10-20 band behind it.
struct RangeBar: View {
    let value: Double
    var dimmed = false
    var scaleMax: Double = 24

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let band = TrainingRules.weeklySetRange
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Palette.surface2)
                Rectangle().fill(Palette.surface3)
                    .frame(width: width * Double(band.upperBound - band.lowerBound) / scaleMax)
                    .offset(x: width * Double(band.lowerBound) / scaleMax)
                RoundedRectangle(cornerRadius: 3).fill(dimmed ? Palette.chartMuted : Palette.ink2)
                    .frame(width: width * min(value, scaleMax) / scaleMax)
            }
        }
        .frame(height: 8)
        .frame(maxWidth: .infinity)
    }
}

import Charts
import SwiftUI

struct GrowthChartCard: View {
    let entries: [GrowthEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Growth.chartTitle)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)

            chart(
                title: L10n.Growth.height,
                values: entries.map { ($0.date, Double($0.heightCm)) },
                unit: "cm"
            )

            chart(
                title: L10n.Growth.weight,
                values: entries.map { ($0.date, $0.weightKg) },
                unit: "kg"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
    }

    private func chart(title: String, values: [(Date, Double)], unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)

            Chart(values, id: \.0) { point in
                LineMark(
                    x: .value(L10n.Growth.date, point.0),
                    y: .value(title, point.1)
                )
                .foregroundStyle(Color.accent)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value(L10n.Growth.date, point.0),
                    y: .value(title, point.1)
                )
                .foregroundStyle(Color.accent)
            }
            .chartYAxisLabel(unit)
            .frame(height: 120)
        }
    }
}

import Charts
import SwiftUI

/// Height and weight on one card. Months and years share the same points — the
/// scale control only changes the x-axis, so one reading per year still draws a line.
struct GrowthChartCard: View {
    let points: [GrowthTrendPoint]
    let totals: GrowthYearTotals
    let periodLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: GrowthChartScale
    @State private var selectedPointID: UUID?

    init(points: [GrowthTrendPoint], totals: GrowthYearTotals, periodLabel: String) {
        self.points = points
        self.totals = totals
        self.periodLabel = periodLabel
        let years = Set(points.map { Calendar.current.component(.year, from: $0.date) })
        _scale = State(initialValue: years.count > 1 ? .years : .months)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            GrowthTrendPage(
                points: points,
                scale: scale,
                selectedPointID: $selectedPointID
            )
            .padding(.horizontal, 16)
            footer
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
        .sensoryFeedback(.selection, trigger: selectedPointID)
        .sensoryFeedback(.selection, trigger: scale)
        .onChange(of: scale) { _, _ in
            selectedPointID = nil
        }
    }

    private var selectedPoint: GrowthTrendPoint? {
        guard let selectedPointID else { return nil }
        return points.first { $0.id == selectedPointID }
    }

    private var headerTrailing: String {
        if let selectedPoint {
            selectedPoint.date.formatted(.dateTime.day().month(.abbreviated).year())
        } else {
            periodLabel
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Growth.chartTitle)
                    .font(.headingXS)
                    .foregroundStyle(Color.textTertiary)

                Spacer(minLength: 8)

                Text(headerTrailing)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                    .contentTransition(.opacity)
                    .animation(GrowthChartMotion.page, value: headerTrailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Growth.chartTitle)
            .accessibilityValue(headerTrailing)

            scalePicker
        }
        .padding(.horizontal, 16)
    }

    private var scalePicker: some View {
        HStack(spacing: 4) {
            scaleChip(.months, L10n.Growth.chartMonths)
            scaleChip(.years, L10n.Growth.chartYears)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    private func scaleChip(_ value: GrowthChartScale, _ title: String) -> some View {
        Button {
            withAnimation(GrowthChartMotion.page) { scale = value }
        } label: {
            Text(title)
                .font(.captionS)
                .foregroundStyle(scale == value ? Color.white : Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(scale == value ? Color.surfaceDark : Color.backgroundPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(scale == value ? .isSelected : [])
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var footer: some View {
        if !totals.isEmpty {
            Text(L10n.Growth.yearGrowth(
                formatHeightTotal(totals.heightCm),
                formatWeightTotal(totals.weightKg),
                periodLabel
            ))
            .font(.headingS)
            .foregroundStyle(Color.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .padding(.horizontal, 16)
        }
    }

    private func formatHeightTotal(_ cm: Int) -> String {
        cm >= 0 ? "+\(cm)cm" : "\(cm)cm"
    }

    private func formatWeightTotal(_ kg: Double) -> String {
        let amount = GrowthEntry.formatWeight(abs(kg)).replacingOccurrences(of: " kg", with: "")
        return kg >= 0 ? "+\(amount)kg" : "-\(amount)kg"
    }
}

// MARK: - Motion

private enum GrowthChartMotion {
    static let page = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let reveal = Animation.timingCurve(0.25, 1, 0.5, 1, duration: 0.45)
    static let selection = Animation.easeOut(duration: 0.18)
    static let stagger = 0.08
}

private enum GrowthChartLayout {
    static let plotHeight: CGFloat = 120
    static let metricHeaderHeight: CGFloat = 24
    static let metricSpacing: CGFloat = 8
    static let metricHeight: CGFloat = metricHeaderHeight + metricSpacing + plotHeight
    static let pageSpacing: CGFloat = 20
    static let pageHeight: CGFloat = metricHeight * 2 + pageSpacing
}

// MARK: - Stacked height + weight

private struct GrowthTrendPage: View {
    let points: [GrowthTrendPoint]
    let scale: GrowthChartScale
    @Binding var selectedPointID: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heightReveal: CGFloat = 0
    @State private var weightReveal: CGFloat = 0
    @State private var didReveal = false

    private var axis: GrowthTrendAxis {
        GrowthTrendAxis(dates: points.map(\.plotDate), scale: scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GrowthChartLayout.pageSpacing) {
            GrowthMetricChart(
                metric: .height,
                axis: axis,
                points: GrowthMetric.height.chartPoints(from: points),
                showsDateLabels: false,
                reveal: heightReveal,
                selectedPointID: $selectedPointID
            )
            GrowthMetricChart(
                metric: .weight,
                axis: axis,
                points: GrowthMetric.weight.chartPoints(from: points),
                reveal: weightReveal,
                selectedPointID: $selectedPointID
            )
        }
        .frame(height: GrowthChartLayout.pageHeight, alignment: .top)
        .animation(reduceMotion ? .linear(duration: 0) : GrowthChartMotion.page, value: scale)
        .onAppear(perform: startRevealIfNeeded)
    }

    private func startRevealIfNeeded() {
        if reduceMotion {
            heightReveal = 1
            weightReveal = 1
            didReveal = true
            return
        }

        guard !didReveal else { return }
        didReveal = true
        heightReveal = 0
        weightReveal = 0
        withAnimation(GrowthChartMotion.reveal) {
            heightReveal = 1
        }
        withAnimation(GrowthChartMotion.reveal.delay(GrowthChartMotion.stagger)) {
            weightReveal = 1
        }
    }
}

// MARK: - Metric

private enum GrowthMetric {
    case height
    case weight

    var title: String {
        switch self {
        case .height: L10n.Growth.height
        case .weight: L10n.Growth.weight
        }
    }

    var unit: String {
        switch self {
        case .height: "cm"
        case .weight: "kg"
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .height:
            "\(Int(value.rounded())) cm"
        case .weight:
            GrowthEntry.formatWeight(value)
        }
    }

    func chartPoints(from points: [GrowthTrendPoint]) -> [GrowthChartPoint] {
        points.map { point in
            GrowthChartPoint(
                id: point.id,
                date: point.plotDate,
                value: self == .height ? Double(point.heightCm) : point.weightKg
            )
        }
    }
}

// MARK: - Metric chart

private struct GrowthMetricChart: View {
    let metric: GrowthMetric
    let axis: GrowthTrendAxis
    let points: [GrowthChartPoint]
    var showsDateLabels = true
    var reveal: CGFloat = 1
    @Binding var selectedPointID: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var yDomain: ClosedRange<Double> {
        GrowthTrendAxis.valueDomain(for: points.map(\.value))
    }

    private var displayedPoint: GrowthChartPoint? {
        if let selectedPointID, let match = points.first(where: { $0.id == selectedPointID }) {
            return match
        }
        return points.last
    }

    private var selectedPoint: GrowthChartPoint? {
        guard let selectedPointID else { return nil }
        return points.first { $0.id == selectedPointID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GrowthChartLayout.metricSpacing) {
            header
                .frame(height: GrowthChartLayout.metricHeaderHeight, alignment: .bottom)
            plot
        }
        .frame(height: GrowthChartLayout.metricHeight, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(metric.title)
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)

            Spacer(minLength: 8)

            Text(displayedPoint.map { metric.formattedValue($0.value) } ?? metric.unit)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())
                .animation(GrowthChartMotion.selection, value: displayedPoint?.id)
        }
        .accessibilityElement(children: .combine)
    }

    private var plot: some View {
        Chart {
            if points.count > 1 {
                ForEach(points) { point in
                    AreaMark(
                        x: .value(L10n.Growth.date, point.date),
                        yStart: .value(metric.title, yDomain.lowerBound),
                        yEnd: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(areaFill)
                    .alignsMarkStylesWithPlotArea()

                    LineMark(
                        x: .value(L10n.Growth.date, point.date),
                        y: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }

            ForEach(points) { point in
                PointMark(
                    x: .value(L10n.Growth.date, point.date),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(Color.surfaceWhite)
                .symbolSize(haloSize(for: point))

                PointMark(
                    x: .value(L10n.Growth.date, point.date),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(Color.accent)
                .symbolSize(dotSize(for: point))
            }

            if let selectedPoint {
                RuleMark(x: .value(L10n.Growth.date, selectedPoint.date))
                    .foregroundStyle(Color.accent.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .zIndex(-1)
            }
        }
        .chartXScale(domain: axis.domain)
        .chartYScale(domain: yDomain)
        .chartXAxis { xAxis }
        .chartYAxis { yAxis }
        .chartPlotStyle { plotArea in
            plotArea.mask {
                Rectangle()
                    .scaleEffect(x: max(reveal, 0.001), y: 1, anchor: .leading)
            }
        }
        .frame(height: GrowthChartLayout.plotHeight)
        .animation(reduceMotion ? .linear(duration: 0) : GrowthChartMotion.selection, value: selectedPointID)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, coordinateSpace: .local) { location in
                        selectPoint(at: location, proxy: proxy, geometry: geometry)
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(metric.title)
        .accessibilityValue(accessibilitySummary)
    }

    private var areaFill: LinearGradient {
        LinearGradient(
            colors: [Color.accent.opacity(0.15), Color.accent.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var xAxis: some AxisContent {
        AxisMarks(values: axis.labeledDates) { value in
            AxisGridLine()
                .foregroundStyle(Color.stroke)
            if showsDateLabels, let date = value.as(Date.self) {
                AxisValueLabel(centered: true) {
                    Text(axis.label(for: date))
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    private var yAxis: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine()
                .foregroundStyle(Color.stroke)
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number.rounded()))")
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    private func haloSize(for point: GrowthChartPoint) -> CGFloat {
        if point.id == selectedPointID { return 110 }
        if point.id == points.last?.id { return 80 }
        return 56
    }

    private func dotSize(for point: GrowthChartPoint) -> CGFloat {
        if point.id == selectedPointID { return 70 }
        if point.id == points.last?.id { return 50 }
        return 36
    }

    private func selectPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xInPlot = location.x - geometry[plotFrame].origin.x
        guard let tapped: Date = proxy.value(atX: xInPlot) else { return }
        guard let point = points.min(by: {
            abs($0.date.timeIntervalSince(tapped)) < abs($1.date.timeIntervalSince(tapped))
        }) else { return }

        selectedPointID = selectedPointID == point.id ? nil : point.id
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "" }
        if let displayedPoint, displayedPoint.id != last.id {
            return metric.formattedValue(displayedPoint.value)
        }
        guard points.count > 1 else { return metric.formattedValue(first.value) }
        return "\(metric.formattedValue(first.value)) – \(metric.formattedValue(last.value))"
    }
}

private struct GrowthChartPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let value: Double
}

// MARK: - Previews

#if DEBUG
private enum GrowthChartPreviewData {
    static func entry(_ year: Int, _ month: Int, _ day: Int, _ cm: Int, _ kg: Double) -> GrowthEntry {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        return GrowthEntry(date: date, heightCm: cm, weightKg: kg)
    }

    static let sparseYear: [GrowthEntry] = [
        entry(2026, 1, 12, 78, 10.2),
        entry(2026, 2, 20, 80, 10.8),
        entry(2026, 6, 4, 86, 12.6),
        entry(2026, 8, 3, 50, 24.0),
        entry(2026, 8, 22, 89, 13.4)
    ]

    static let twoYears: [GrowthEntry] = [
        entry(2025, 2, 8, 62, 6.5),
        entry(2025, 5, 14, 67, 7.8),
        entry(2025, 9, 2, 72, 9.0),
        entry(2025, 12, 19, 76, 9.9)
    ] + sparseYear

    static let onePerYear: [GrowthEntry] = [
        entry(2024, 6, 10, 70, 8.4),
        entry(2025, 6, 12, 82, 11.2),
        entry(2026, 6, 8, 90, 13.5)
    ]

    static func card(_ entries: [GrowthEntry]) -> some View {
        let points = GrowthTrendPoint.points(from: entries)
        let totals: GrowthYearTotals = {
            guard let first = points.first, let last = points.last else { return .zero }
            return GrowthYearTotals(
                heightCm: last.heightCm - first.heightCm,
                weightKg: last.weightKg - first.weightKg
            )
        }()
        let years = Set(points.map { Calendar.current.component(.year, from: $0.date) }).sorted()
        let period: String = {
            guard let first = years.first, let last = years.last else { return "" }
            return first == last ? String(first) : "\(first)–\(last)"
        }()
        return GrowthChartCard(points: points, totals: totals, periodLabel: period)
    }
}

#Preview("Single measurement") {
    GrowthChartPreviewData.card([GrowthChartPreviewData.entry(2026, 8, 22, 55, 26.5)])
        .padding(20)
        .background(Color.backgroundPrimary)
}

#Preview("One per year") {
    GrowthChartPreviewData.card(GrowthChartPreviewData.onePerYear)
        .padding(20)
        .background(Color.backgroundPrimary)
}

#Preview("Two entries, same day") {
    GrowthChartPreviewData.card([
        GrowthChartPreviewData.entry(2026, 8, 31, 50, 24.0),
        GrowthChartPreviewData.entry(2026, 8, 31, 55, 26.5)
    ])
    .padding(20)
    .background(Color.backgroundPrimary)
}

#Preview("Sparse year") {
    GrowthChartPreviewData.card(GrowthChartPreviewData.sparseYear)
        .padding(20)
        .background(Color.backgroundPrimary)
}

#Preview("Two years") {
    GrowthChartPreviewData.card(GrowthChartPreviewData.twoYears)
        .padding(20)
        .background(Color.backgroundPrimary)
}

#Preview("Two years · Arabic RTL") {
    GrowthChartPreviewData.card(GrowthChartPreviewData.twoYears)
        .padding(20)
        .background(Color.backgroundPrimary)
        .environment(\.layoutDirection, .rightToLeft)
}
#endif

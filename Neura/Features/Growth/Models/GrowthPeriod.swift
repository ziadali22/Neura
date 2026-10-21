import Foundation

// MARK: - Chart scale

/// Whether the trend x-axis is labeled by month or by year — same points, one chart.
enum GrowthChartScale: Hashable {
    case months
    case years
}

// MARK: - Point

/// One logged measurement on the shared months/years timeline.
///
/// `date` is what the user logged. `plotDate` is that date with a small offset when two
/// readings share a calendar day, so both stay visible instead of stacking on one x.
struct GrowthTrendPoint: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let plotDate: Date
    let heightCm: Int
    let weightKg: Double

    /// Every measurement, oldest first. No yearly bucketing — one reading is one point,
    /// so a single weigh-in per year still draws a line across years.
    ///
    /// `entries` must arrive in recorded order because two entries can share a timestamp
    /// and Swift's sort is not stable. Position in the incoming array breaks such ties.
    static func points(from entries: [GrowthEntry]) -> [GrowthTrendPoint] {
        let calendar = Calendar.current
        let ordered = entries
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.date == rhs.element.date
                    ? lhs.offset < rhs.offset
                    : lhs.element.date < rhs.element.date
            }

        var collisions: [Date: Int] = [:]
        return ordered.map { _, pair in
            let day = calendar.startOfDay(for: pair.date)
            let offset = collisions[day, default: 0]
            collisions[day] = offset + 1
            let plotDate = calendar.date(byAdding: .hour, value: offset * 3, to: pair.date)
                ?? pair.date
            return GrowthTrendPoint(
                id: pair.id,
                date: pair.date,
                plotDate: plotDate,
                heightCm: pair.heightCm,
                weightKg: pair.weightKg
            )
        }
    }
}

// MARK: - Axis

/// Shared x-axis for the stacked height and weight charts.
struct GrowthTrendAxis {
    static let maxLabels = 6

    let domain: ClosedRange<Date>
    let labeledDates: [Date]
    let scale: GrowthChartScale
    let spansYears: Bool

    init(dates: [Date], scale: GrowthChartScale, calendar: Calendar = .current) {
        self.scale = scale
        let sorted = dates.sorted()
        guard let first = sorted.first, let last = sorted.last else {
            let now = Date()
            self.domain = now...now
            self.labeledDates = []
            self.spansYears = false
            return
        }

        let firstYear = calendar.component(.year, from: first)
        let lastYear = calendar.component(.year, from: last)
        self.spansYears = firstYear != lastYear

        switch scale {
        case .months:
            if firstYear == lastYear {
                // A lone reading still sits on a full Jan–Dec axis so the chart
                // isn't an empty plot with one orphaned dot.
                let start = calendar.date(from: DateComponents(year: firstYear, month: 1, day: 1)) ?? first
                let end = calendar.date(
                    from: DateComponents(year: firstYear, month: 12, day: 31, hour: 23, minute: 59)
                ) ?? last
                self.domain = start...end
                self.labeledDates = Self.ticks(
                    from: start,
                    through: end,
                    by: .month,
                    calendar: calendar
                )
            } else {
                let start = calendar.date(
                    from: DateComponents(
                        year: firstYear,
                        month: calendar.component(.month, from: first),
                        day: 1
                    )
                ) ?? first
                let end = Self.endOfMonth(containing: last, calendar: calendar)
                self.domain = start...end
                self.labeledDates = Self.ticks(
                    from: start,
                    through: end,
                    by: .month,
                    calendar: calendar
                )
            }

        case .years:
            let start = calendar.date(from: DateComponents(year: firstYear, month: 1, day: 1)) ?? first
            let end = calendar.date(
                from: DateComponents(year: lastYear, month: 12, day: 31, hour: 23, minute: 59)
            ) ?? last
            self.domain = start...end
            self.labeledDates = (firstYear...lastYear).compactMap { year in
                calendar.date(from: DateComponents(year: year, month: 1, day: 1))
            }
        }
    }

    func label(for date: Date, calendar: Calendar = .current) -> String {
        switch scale {
        case .months:
            if spansYears, calendar.component(.month, from: date) == 1 {
                return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            }
            return date.formatted(.dateTime.month(.abbreviated))
        case .years:
            return date.formatted(.dateTime.year())
        }
    }

    /// The y-range for a metric's chart, computed rather than left to `.automatic`.
    ///
    /// A single measurement is a real state, and one value gives `.automatic` nothing to
    /// derive a range from — it collapses to a flat axis. Identical values get a fixed
    /// margin so the point lands mid-chart; spread values get proportional headroom.
    static func valueDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        guard high > low else {
            let margin = max(1, abs(low) * 0.05)
            return (low - margin)...(high + margin)
        }
        let padding = (high - low) * 0.15
        return (low - padding)...(high + padding)
    }

    private static func endOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let start = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: start) else {
            return date
        }
        return calendar.date(
            from: DateComponents(
                year: comps.year,
                month: comps.month,
                day: range.count,
                hour: 23,
                minute: 59
            )
        ) ?? date
    }

    private static func ticks(
        from start: Date,
        through end: Date,
        by component: Calendar.Component,
        calendar: Calendar,
        maxLabels: Int = maxLabels
    ) -> [Date] {
        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: component, value: 1, to: current),
                  next > current else { break }
            current = next
        }
        guard dates.count > maxLabels else { return dates }

        let step = Double(dates.count - 1) / Double(maxLabels - 1)
        var indices: [Int] = []
        for slot in 0..<maxLabels {
            let index = Int((Double(slot) * step).rounded())
            if indices.last != index { indices.append(index) }
        }
        return indices.map { dates[$0] }
    }
}

// MARK: - Totals

/// Growth from the first reading to the last, shown beneath the chart.
struct GrowthYearTotals: Hashable {
    let heightCm: Int
    let weightKg: Double

    static let zero = GrowthYearTotals(heightCm: 0, weightKg: 0)

    var isEmpty: Bool { heightCm == 0 && abs(weightKg) < 0.05 }
}

import SwiftUI

/// Timeline of all entries grouped by year (newest first), one card per entry —
/// a big colour-coded day number + month, title, subtitle, and a chevron.
struct AgendaListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onTapEntry: (CalendarEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(yearGroups) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.representativeDate, format: .dateTime.year())
                                    .font(.headingS)
                                    .foregroundStyle(Color.textTertiary)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 10) {
                                    ForEach(group.entries) { entry in
                                        Button { onTapEntry(entry) } label: {
                                            TimelineRow(entry: entry)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 46, height: 46)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Entries grouped by calendar year, years descending, entries newest first.
    private var yearGroups: [YearGroup] {
        let cal = Calendar.current
        var buckets: [Int: [CalendarEntry]] = [:]
        for entry in viewModel.timelineEntries {
            buckets[cal.component(.year, from: entry.date), default: []].append(entry)
        }
        return buckets.keys.sorted(by: >).map { year in
            let entries = buckets[year]!
            return YearGroup(year: year, representativeDate: entries[0].date, entries: entries)
        }
    }
}

private struct YearGroup: Identifiable {
    let year: Int
    let representativeDate: Date
    let entries: [CalendarEntry]
    var id: Int { year }
}

/// A single timeline card: colour-coded date-number badge, title, subtitle, chevron.
struct TimelineRow: View {
    let entry: CalendarEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(entry.date, format: .dateTime.day())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(dayColor)
                Text(entry.date, format: .dateTime.month(.abbreviated))
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(entry.subtitle)
                    .font(.captionS)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    /// Day-number colour: medical events red, medications orange, appointments black.
    private var dayColor: Color { entry.type.color }
}

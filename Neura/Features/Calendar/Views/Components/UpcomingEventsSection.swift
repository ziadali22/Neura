import SwiftUI

/// Upcoming events shown below the calendar grid: the soonest event under a
/// "Next" header, then remaining events grouped by month.
struct UpcomingEventsSection: View {
    let items: [(date: Date, entry: CalendarEntry)]
    let onTap: (CalendarEntry) -> Void
    let onToggleComplete: (CalendarEntry, Date) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        header(for: group)
                        ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
                            UpcomingEventRow(
                                date: row.date,
                                entry: row.entry,
                                isCompleted: row.entry.isCompleted(on: row.date),
                                onTap: { onTap(row.entry) },
                                onToggle: { onToggleComplete(row.entry, row.date) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func header(for group: UpcomingGroup) -> some View {
        Group {
            if group.isNext {
                Text(L10n.Calendar.next)
            } else {
                Text(group.monthDate, format: .dateTime.month(.wide))
            }
        }
        .font(.headingS)
        .foregroundStyle(Color.textPrimary)
    }

    /// First item → "Next"; the rest grouped into consecutive month buckets.
    private var groups: [UpcomingGroup] {
        guard let first = items.first else { return [] }
        var result = [UpcomingGroup(id: "next", isNext: true, monthDate: first.date, rows: [first])]
        let cal = Calendar.current
        var currentKey: DateComponents?
        for item in items.dropFirst() {
            let key = cal.dateComponents([.year, .month], from: item.date)
            if key == currentKey {
                result[result.count - 1].rows.append(item)
            } else {
                currentKey = key
                result.append(UpcomingGroup(id: "\(key.year ?? 0)-\(key.month ?? 0)", isNext: false, monthDate: item.date, rows: [item]))
            }
        }
        return result
    }
}

private struct UpcomingGroup: Identifiable {
    let id: String
    let isNext: Bool
    let monthDate: Date
    var rows: [(date: Date, entry: CalendarEntry)]
}

/// A single upcoming-event card: date badge, title + subtitle, and a trailing
/// completion ring. The content and the ring are sibling buttons so tapping the
/// ring toggles completion without also opening the editor.
struct UpcomingEventRow: View {
    let date: Date
    let entry: CalendarEntry
    let isCompleted: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Text(date, format: .dateTime.day())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(entry.type.color)
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(.captionS)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(width: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.headingXS)
                            .fontWeight(.bold)
                            .foregroundStyle(isCompleted ? Color.textTertiary : Color.textPrimary)
                            .strikethrough(isCompleted)
                            .lineLimit(1)
                        Text(entry.subtitle)
                            .font(.captionS)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                completionRing
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? L10n.Common.done : entry.title)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var completionRing: some View {
        if isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(entry.type.color)
        } else {
            Circle()
                .strokeBorder(entry.type.color.opacity(0.6), lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }
}

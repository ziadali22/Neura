import SwiftUI

/// The selected day's entries, or the empty state with an "Add entry" CTA.
struct DayEntriesList: View {
    let day: Date
    let entries: [CalendarEntry]
    let onTapEntry: (CalendarEntry) -> Void
    let onToggleComplete: (CalendarEntry, Date) -> Void
    let onAdd: () -> Void

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    let occurrence = occurrenceDate(for: entry)
                    CalendarEntryRow(
                        entry: entry,
                        isCompleted: entry.isCompleted(on: occurrence),
                        onTap: { onTapEntry(entry) },
                        onToggle: { onToggleComplete(entry, occurrence) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    /// The exact occurrence datetime of `entry` on the displayed day (matches the
    /// value stored in `completedDates`), falling back to the entry's own date.
    private func occurrenceDate(for entry: CalendarEntry) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) else { return entry.date }
        return entry.occurrences(in: start...end).first ?? entry.date
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(L10n.Calendar.emptyTitle)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.Calendar.emptyMessage)
                .font(.bodyS)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onAdd) {
                Text(L10n.Calendar.addFirstEntry)
                    .font(.buttonL)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.top, 24)
    }
}

/// A single entry row: type icon, title, time, and a completion toggle. The
/// content and the ring are sibling buttons so the ring toggles completion
/// without also opening the editor.
struct CalendarEntryRow: View {
    let entry: CalendarEntry
    let isCompleted: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(entry.type.color.opacity(0.15))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: entry.type.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(entry.type.color)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.headingXS)
                            .foregroundStyle(isCompleted ? Color.textTertiary : Color.textPrimary)
                            .strikethrough(isCompleted)
                            .lineLimit(1)
                        if entry.isAllDay == true {
                            Text(L10n.Calendar.fieldAllDay)
                                .font(.captionS)
                                .foregroundStyle(Color.textTertiary)
                        } else {
                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.captionS)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    Spacer(minLength: 8)

                    if entry.linkedDocumentID != nil {
                        Image(systemName: "paperclip")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                CompletionRing(color: entry.type.color, isCompleted: isCompleted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

/// Shared completion indicator: filled check when done, accent-tinted ring otherwise.
struct CompletionRing: View {
    let color: Color
    let isCompleted: Bool

    var body: some View {
        if isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(color)
        } else {
            Circle()
                .strokeBorder(color.opacity(0.6), lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }
}

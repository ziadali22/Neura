import SwiftUI

/// Monday-first month grid. Weekends de-emphasized; today and the selected day
/// styled; days that have entries show a dot.
struct MonthGridView: View {
    let month: Date
    let selectedDay: Date
    let daysWithEntries: Set<Int>
    let onSelect: (Date) -> Void

    @Environment(\.locale) private var locale

    private var cal: Calendar {
        var c = Calendar.current
        c.locale = locale
        return c
    }
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daySlots.enumerated()), id: \.offset) { _, slot in
                    if let day = slot {
                        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
                        let isToday = cal.isDateInToday(day)
                        let hasEntry = daysWithEntries.contains(cal.component(.day, from: day))
                        Button { onSelect(day) } label: {
                            DayCell(
                                date: day,
                                isSelected: isSelected,
                                isToday: isToday,
                                isWeekend: cal.isDateInWeekend(day),
                                hasEntry: hasEntry
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(for: day, isToday: isToday, hasEntry: hasEntry))
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    /// VoiceOver label like "Tuesday 10 July, today, has events".
    private func accessibilityLabel(for day: Date, isToday: Bool, hasEntry: Bool) -> Text {
        var label = Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
        if isToday { label = label + Text(", ") + Text(L10n.Calendar.today) }
        if hasEntry { label = label + Text(", ") + Text(L10n.Calendar.a11yHasEvents) }
        return label
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Short weekday names starting Monday, localized by the current locale.
    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols          // [Sun, Mon, ... Sat]
        return Array(symbols[1...]) + [symbols[0]]      // -> [Mon ... Sat, Sun]
    }

    /// Day cells for the visible month with leading blanks so day 1 lands on the
    /// correct Monday-first weekday.
    private var daySlots: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstOfMonth = interval.start
        let dayCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        // weekday: 1=Sun ... 7=Sat. Convert to Monday-first index 0...6.
        let weekday = cal.component(.weekday, from: firstOfMonth)
        let leading = (weekday + 5) % 7
        var slots: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            slots.append(cal.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        return slots
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isWeekend: Bool
    let hasEntry: Bool

    private var dayNumber: String { "\(Calendar.current.component(.day, from: date))" }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayNumber)
                .font(.bodyL)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(textColor)
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        if isSelected {
                            Circle().fill(Color.textPrimary)
                        } else if isToday {
                            Circle().strokeBorder(Color.accent, lineWidth: 1.5)
                        }
                    }
                )
            Circle()
                .fill(hasEntry ? Color.accent : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return .accent }
        if isWeekend { return .textTertiary }
        return .textPrimary
    }
}

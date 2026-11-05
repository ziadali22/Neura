import Foundation

/// The appointment Home should surface, plus the moment it leaves the screen.
struct HomeNextAppointment: Equatable {
    let occurrence: Date
    let entry: CalendarEntry
    /// Timed appointments stay for one hour after they start.
    /// All-day appointments stay until the end of that day.
    let hideAt: Date

    static let graceInterval: TimeInterval = 60 * 60

    /// Soonest appointment that is still relevant at `now`.
    /// A timed visit remains for one hour after it starts, then the next one takes its place.
    static func next(in entries: [CalendarEntry], at now: Date = Date()) -> HomeNextAppointment? {
        let calendar = Calendar.current
        let lower = now.addingTimeInterval(-graceInterval)
        guard let upper = calendar.date(byAdding: .year, value: 1, to: now) else { return nil }
        let range = lower...upper

        var candidates: [HomeNextAppointment] = []
        for entry in entries where entry.type == .appointment {
            for occurrence in entry.occurrences(in: range) {
                let hideAt = visibilityEnd(for: entry, occurrence: occurrence, calendar: calendar)
                guard now < hideAt else { continue }
                candidates.append(HomeNextAppointment(occurrence: occurrence, entry: entry, hideAt: hideAt))
            }
        }

        return candidates.min(by: { lhs, rhs in
            let sameDay = calendar.isDate(lhs.occurrence, inSameDayAs: rhs.occurrence)
            if sameDay, (lhs.entry.isAllDay == true) != (rhs.entry.isAllDay == true) {
                return lhs.entry.isAllDay != true
            }
            return lhs.occurrence < rhs.occurrence
        })
    }

    /// "Today", "Tomorrow", or a weekday date for anything further out.
    static func sectionTitle(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return L10n.Calendar.today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return L10n.Calendar.tomorrow
        }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private static func visibilityEnd(for entry: CalendarEntry, occurrence: Date, calendar: Calendar) -> Date {
        if entry.isAllDay == true {
            let start = calendar.startOfDay(for: occurrence)
            return calendar.date(byAdding: .day, value: 1, to: start) ?? occurrence
        }
        return occurrence.addingTimeInterval(graceInterval)
    }
}

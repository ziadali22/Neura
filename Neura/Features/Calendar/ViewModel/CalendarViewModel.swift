import SwiftUI
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var visibleMonth: Date
    @Published var selectedDay: Date

    private let store: CalendarEntryStore
    private let scheduler = CalendarReminderScheduler.shared
    private var cancellable: AnyCancellable?

    /// Mirror of the store's entries so SwiftUI re-renders on change.
    @Published private(set) var entries: [CalendarEntry] = []

    init(store: CalendarEntryStore = .shared) {
        self.store = store
        let today = Calendar.current.startOfDay(for: Date())
        self.visibleMonth = today
        self.selectedDay = today
        self.entries = store.entries
        cancellable = store.$entries.sink { [weak self] in self?.entries = $0 }
    }

    // MARK: - Derived queries

    /// Entries occurring on a given day, sorted by time.
    func entries(on day: Date) -> [CalendarEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) else { return [] }
        let range = start...end
        return entries
            .filter { !$0.occurrences(in: range).isEmpty }
            .sorted { $0.date < $1.date }
    }

    /// Day numbers (1...31) in `visibleMonth` that have at least one entry — for grid dots.
    var daysWithEntries: Set<Int> {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let range = interval.start...interval.end
        var days: Set<Int> = []
        for entry in entries {
            for occ in entry.occurrences(in: range) {
                if cal.isDate(occ, equalTo: visibleMonth, toGranularity: .month) {
                    days.insert(cal.component(.day, from: occ))
                }
            }
        }
        return days
    }

    /// All occurrences across all entries, chronological, for the agenda.
    func agendaItems(horizonDays: Int = 365) -> [(date: Date, entry: CalendarEntry)] {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        guard let lower = cal.date(byAdding: .day, value: -horizonDays, to: now),
              let upper = cal.date(byAdding: .day, value: horizonDays, to: now) else { return [] }
        let range = lower...upper
        var items: [(Date, CalendarEntry)] = []
        for entry in entries {
            for occ in entry.occurrences(in: range) { items.append((occ, entry)) }
        }
        return items.sorted { $0.0 < $1.0 }.map { (date: $0.0, entry: $0.1) }
    }

    /// Upcoming occurrences from the start of *today* forward, chronological.
    /// The lower bound is `startOfDay(today)`, so today's events stay listed all
    /// day (even once their time has passed) while anything from yesterday or
    /// earlier is excluded — past days belong to the agenda/history, not here.
    func upcomingItems(horizonDays: Int = 365) -> [(date: Date, entry: CalendarEntry)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let upper = cal.date(byAdding: .day, value: horizonDays, to: start) else { return [] }
        let range = start...upper
        var items: [(Date, CalendarEntry)] = []
        for entry in entries {
            for occ in entry.occurrences(in: range) where occ >= start {
                items.append((occ, entry))
            }
        }
        return items.sorted { $0.0 < $1.0 }.map { (date: $0.0, entry: $0.1) }
    }

    /// All entries for the timeline, newest first (one row per entry, by its date).
    var timelineEntries: [CalendarEntry] {
        entries.sorted { $0.date > $1.date }
    }

    // MARK: - Month navigation

    func goToPreviousMonth() { shiftMonth(by: -1) }
    func goToNextMonth() { shiftMonth(by: 1) }

    /// True when the grid is showing the current calendar month.
    var isViewingCurrentMonth: Bool {
        Calendar.current.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Jump back to the current month and select today.
    func goToToday() {
        HapticManager.selection()
        let today = Calendar.current.startOfDay(for: Date())
        visibleMonth = today
        selectedDay = today
    }

    private func shiftMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: visibleMonth) {
            HapticManager.selection()
            visibleMonth = next
        }
    }

    // MARK: - Mutations

    func save(_ entry: CalendarEntry) {
        store.update(entry)            // update() inserts if id is new
        scheduler.reschedule(for: store.entries)
    }

    func delete(_ entry: CalendarEntry) {
        store.delete(id: entry.id)
        scheduler.reschedule(for: store.entries)
    }

    /// Toggle completion for a specific occurrence of an entry.
    func toggleCompletion(_ entry: CalendarEntry, on date: Date) {
        var updated = entry
        if let idx = updated.completedDates.firstIndex(of: date) {
            updated.completedDates.remove(at: idx)
            HapticManager.light()
        } else {
            updated.completedDates.append(date)
            HapticManager.success()
        }
        store.update(updated)
        // Reschedule so the medication "Did you take it?" follow-up is dropped
        // once taken (and restored if un-checked).
        scheduler.reschedule(for: store.entries)
    }
}

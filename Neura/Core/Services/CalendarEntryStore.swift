import Foundation
import Combine

/// Persists calendar entries as JSON in UserDefaults (same pattern as HealthProfile)
/// and mirrors them to encrypted cloud sync so they survive a reinstall.
@MainActor
final class CalendarEntryStore: ObservableObject {
    static let shared = CalendarEntryStore()

    @Published private(set) var entries: [CalendarEntry] = []

    private static let storageKey = "calendar_entries_data"

    private init() {
        entries = Self.loadFromDisk()
        // Pick up entries pulled down by performInitialRestore on a new device.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestored),
            name: .calendarEntriesRestored,
            object: nil
        )
    }

    // MARK: - CRUD

    func add(_ entry: CalendarEntry) {
        entries.append(entry)
        save()
    }

    func update(_ entry: CalendarEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else {
            add(entry)
            return
        }
        entries[idx] = entry
        save()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func entry(id: UUID) -> CalendarEntry? {
        entries.first { $0.id == id }
    }

    // MARK: - Restore

    /// Reads entries straight from disk without touching `@Published` state — used
    /// by the sync queue to reconstruct upload/restore payloads.
    func loadEntriesFromDisk() -> [CalendarEntry] {
        Self.loadFromDisk()
    }

    /// Replaces the entry list (e.g. after a cloud restore) and persists it,
    /// without re-enqueuing a redundant upload of data we just downloaded.
    func replaceAll(_ newEntries: [CalendarEntry]) {
        entries = newEntries
        persist()
    }

    @objc private func handleRestored() {
        entries = Self.loadFromDisk()
    }

    // MARK: - Persistence

    /// Persists locally and queues an encrypted cloud upload so the entries
    /// survive an app reinstall (recovered via `performInitialRestore`).
    private func save() {
        persist()
        SyncQueueManager.shared.enqueueCalendarUpload(entries)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func loadFromDisk() -> [CalendarEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([CalendarEntry].self, from: data) else {
            return []
        }
        return saved
    }
}

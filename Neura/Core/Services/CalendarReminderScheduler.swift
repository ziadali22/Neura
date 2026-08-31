import Foundation
import UserNotifications

/// Schedules local notifications for calendar entries. Appointments get three
/// reminders — 1 week, 1 day and 2 hours before — naming the doctor in the
/// notification. Medication fires at the scheduled time plus a
/// +30 min "Did you take your medication?" follow-up, which is skipped once the
/// occurrence is marked taken. Medical events get two short reminders (30m / 15m
/// before). Reschedules a rolling window of the soonest reminders to stay under
/// iOS's 64 pending-notification limit, prioritising appointments so their
/// long-lead reminders are never starved by high-frequency entries. Local
/// notifications need no Info.plist key — only an authorization prompt.
final class CalendarReminderScheduler {
    static let shared = CalendarReminderScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "neura.calendar."
    /// Max pending reminders we schedule — well under the 64 system cap, leaving
    /// room for other local notifications in the app.
    private let maxScheduled = 60
    /// How far ahead to expand recurring occurrences.
    private let horizonDays = 365

    /// A reminder offset relative to an occurrence (positive = before, negative =
    /// after), with the body shown when it fires.
    private struct Lead {
        let minutes: Int
        let body: String
        /// When true, skip this reminder if the occurrence is already marked
        /// complete — used for the medication "Did you take it?" follow-up.
        var skipIfCompleted: Bool = false
    }

    /// Reminder schedule for an entry type. Appointments lead long (week / 1 day
    /// / 2 hours). Medication fires at the scheduled time plus a +30 min
    /// follow-up that is suppressed once taken. Medical events keep the short
    /// 30m / 15m reminders.
    private func leads(for type: CalendarEntryType) -> [Lead] {
        switch type {
        case .appointment:
            return [
                Lead(minutes: 7 * 24 * 60, body: L10n.Calendar.reminderBodyWeek),
                Lead(minutes: 1 * 24 * 60, body: L10n.Calendar.reminderBody1Day),
                Lead(minutes: 2 * 60,      body: L10n.Calendar.reminderBody2Hours),
            ]
        case .medication:
            return [
                Lead(minutes: 0,   body: L10n.Calendar.reminderBodyMedTime),
                Lead(minutes: -30, body: L10n.Calendar.reminderBodyMedFollowUp, skipIfCompleted: true),
            ]
        case .medicalEvent:
            return [
                Lead(minutes: 30, body: L10n.Calendar.reminderBody30),
                Lead(minutes: 15, body: L10n.Calendar.reminderBody15),
            ]
        }
    }

    /// Rebuild all calendar reminders from the current entry list.
    /// Call after any add/update/delete and on app foreground.
    func reschedule(for entries: [CalendarEntry]) {
        guard !entries.isEmpty else {
            // Nothing to remind about — clear any we previously set, don't prompt.
            clearOurPending()
            return
        }
        NotificationAuthorization.runIfAuthorized { [weak self] in
            self?.rebuild(entries)
        }
    }

    private func clearOurPending() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    private func rebuild(_ entries: [CalendarEntry]) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)

            let now = Date()
            let horizon = Calendar.current.date(byAdding: .day, value: self.horizonDays, to: now) ?? now
            guard horizon > now else { return }
            let range = now...horizon

            // Per-type reminders for every occurrence of every entry.
            var fires: [(date: Date, entry: CalendarEntry, occurrence: Date, lead: Lead)] = []
            for entry in entries {
                let leads = self.leads(for: entry.type)
                for occ in entry.occurrences(in: range) {
                    for lead in leads {
                        // Suppress the medication follow-up once this occurrence is taken.
                        if lead.skipIfCompleted && entry.isCompleted(on: occ) { continue }
                        let fireDate = occ.addingTimeInterval(-Double(lead.minutes) * 60)
                        if fireDate > now {
                            fires.append((fireDate, entry, occ, lead))
                        }
                    }
                }
            }

            // Cap to the system-safe window, prioritising appointments so their
            // long-lead reminders aren't evicted by high-frequency entries. Each
            // group is soonest-first; appointments fill first, the rest backfill.
            let appointments = fires
                .filter { $0.entry.type == .appointment }
                .sorted { $0.date < $1.date }
            let others = fires
                .filter { $0.entry.type != .appointment }
                .sorted { $0.date < $1.date }
            let chosen = Array(appointments.prefix(self.maxScheduled))
                + others.prefix(max(0, self.maxScheduled - appointments.count))
            for fire in chosen {
                self.schedule(fire.entry, fireDate: fire.date, occurrence: fire.occurrence, lead: fire.lead)
            }
        }
    }

    private func schedule(_ entry: CalendarEntry, fireDate: Date, occurrence: Date, lead: Lead) {
        let content = UNMutableNotificationContent()
        content.title = entry.notificationHeadline
        content.body = lead.body
        content.sound = .default
        // Deep-links to the linked document on tap (see AppDelegate's
        // UNUserNotificationCenterDelegate conformance).
        if let linkedDocumentID = entry.linkedDocumentID {
            content.userInfo = ["documentID": linkedDocumentID.uuidString]
        }

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        // Unique per entry + occurrence + lead so rescheduling replaces cleanly.
        let occStamp = Int(occurrence.timeIntervalSince1970)
        let request = UNNotificationRequest(
            identifier: "\(idPrefix)\(entry.id.uuidString).\(occStamp).\(lead.minutes)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

import Foundation
import UserNotifications

/// Nudges a user who hasn't opened the app in a while to come back. Reschedules
/// a single "come back" reminder 7 days out every time the app is foregrounded,
/// so it only ever fires after a real 7-day gap — each new open pushes it
/// further out rather than letting reminders stack.
final class ReEngagementNotificationManager {
    static let shared = ReEngagementNotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let reminderID = "neura.reengagement.reminder"
    private let inactivityDays = 7

    /// Call on every app foreground. No-ops (and never prompts) when notifications
    /// aren't authorized — permission is requested elsewhere, in onboarding's
    /// "Stay updated" step, not here.
    func scheduleIfNeeded() {
        NotificationAuthorization.runIfAlreadyAuthorized { [weak self] in
            self?.schedule()
        }
    }

    private func schedule() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        guard let fireDate = Calendar.current.date(byAdding: .day, value: inactivityDays, to: Date()) else { return }
        let content = UNMutableNotificationContent()
        content.title = "We miss you at Neura"
        content.body = "Your documents and health profile are waiting. Tap to pick up where you left off."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }
}

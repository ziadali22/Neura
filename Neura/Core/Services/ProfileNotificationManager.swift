import UserNotifications
import Foundation

/// Manages local notifications that nudge the user to complete their health profile.
///
/// Usage:
///  - Call `requestPermissionAndScheduleIfNeeded(filledCount:total:)` after every profile save.
///  - The manager auto-cancels pending reminders when the profile is complete.
final class ProfileNotificationManager {

    static let shared = ProfileNotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Notification identifiers
    private let reminderID   = "neura.profile.incomplete.reminder"
    private let followUpID   = "neura.profile.incomplete.followup"

    // UserDefaults key — tracks whether we've already asked for permission
    private let permissionKey = "neura_notifications_permission_requested"

    // MARK: - Public API

    /// Requests notification authorization. Used by the onboarding "Stay updated" step so
    /// the system prompt appears there rather than at launch. Safe to call when the status
    /// is already determined — it simply reports the existing decision without re-prompting.
    /// - Returns: `true` if notifications are authorized after the call.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Call this after every profile save. Handles permission, scheduling, and cancellation.
    func requestPermissionAndScheduleIfNeeded(filledCount: Int, total: Int) {
        if filledCount >= total {
            cancelAll()
            return
        }
        requestPermissionThenSchedule(filledCount: filledCount, total: total)
    }

    // MARK: - Permission

    private func requestPermissionThenSchedule(filledCount: Int, total: Int) {
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self?.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { self?.schedule(filledCount: filledCount, total: total) }
                }
            case .authorized, .provisional, .ephemeral:
                self?.schedule(filledCount: filledCount, total: total)
            default:
                break
            }
        }
    }

    // MARK: - Scheduling

    private func schedule(filledCount: Int, total: Int) {
        // Remove any existing reminders first so we don't stack duplicates
        center.removePendingNotificationRequests(withIdentifiers: [reminderID, followUpID])

        scheduleReminder(
            id: reminderID,
            title: "Your health profile isn't complete yet",
            body: "You've filled \(filledCount) of \(total) fields. It only takes a minute — finish it so your profile is ready when you need it.",
            triggerAfterDays: 1
        )

        scheduleReminder(
            id: followUpID,
            title: "Don't forget to finish your profile",
            body: "A complete health profile helps doctors help you faster. Tap to add the missing details.",
            triggerAfterDays: 4
        )
    }

    private func scheduleReminder(id: String, title: String, body: String, triggerAfterDays: Int) {
        // Fire at 9 AM, N days from now
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day! += triggerAfterDays
        components.hour = 9
        components.minute = 0
        components.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Cancellation

    /// Removes all pending profile-completion reminders (called when profile is fully filled).
    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID, followUpID])
    }
}

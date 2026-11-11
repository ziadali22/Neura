import UserNotifications

/// This app's single local-notification permission protocol, shared by every
/// reminder scheduler (calendar, document expiry, profile completion,
/// re-engagement) so the authorization-status switch lives in one place
/// instead of being copied into each scheduler.
enum NotificationAuthorization {
    /// Runs `block` once notifications are authorized. If permission hasn't
    /// been decided yet, prompts first and only runs `block` if granted.
    static func runIfAuthorized(_ block: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { block() }
                }
            case .authorized, .provisional, .ephemeral:
                block()
            default:
                break
            }
        }
    }

    /// Runs `block` only if notifications are already authorized — never
    /// prompts. For features that must ride on permission granted elsewhere
    /// rather than surface their own dialog (e.g. the re-engagement nudge).
    static func runIfAlreadyAuthorized(_ block: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                block()
            default:
                break
            }
        }
    }
}

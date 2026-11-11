import Foundation
import UserNotifications

/// Schedules local notifications reminding the user before a document (passport,
/// insurance card, warranty, etc.) expires. Reminders fire 30 and 7 days before
/// `Document.expiryDate`. Tapping the notification deep-links to the document via
/// `userInfo["documentID"]`, handled by `AppDelegate`'s
/// `UNUserNotificationCenterDelegate` conformance. Local notifications need no
/// Info.plist key — only an authorization prompt, already granted via onboarding's
/// "Stay updated" step or another reminder feature.
final class DocumentExpiryReminderScheduler {
    static let shared = DocumentExpiryReminderScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "neura.docExpiry."
    private let leadDays = [30, 7]

    /// Rebuild all expiry reminders from the current document list.
    /// Call after any add/update/delete and on app foreground.
    ///
    /// Reminders deliberately cover every account, not just the active one — an
    /// expiring passport shouldn't go unannounced because the user happens to be
    /// in a different account. `accountNames` (space id → name) lets each
    /// reminder say which account it's about, so documents that share a name
    /// across accounts stay distinguishable.
    func reschedule(for documents: [Document], accountNames: [UUID: String] = [:]) {
        let withExpiry = documents.filter { $0.expiryDate != nil }
        guard !withExpiry.isEmpty else {
            clearOurPending()
            return
        }
        NotificationAuthorization.runIfAuthorized { [weak self] in
            self?.rebuild(withExpiry, accountNames: accountNames)
        }
    }

    private func clearOurPending() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    private func rebuild(_ documents: [Document], accountNames: [UUID: String]) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)

            let now = Date()
            for document in documents {
                guard let expiryDate = document.expiryDate, expiryDate > now else { continue }
                for days in self.leadDays {
                    guard let fireDate = Calendar.current.date(byAdding: .day, value: -days, to: expiryDate),
                          fireDate > now else { continue }
                    self.schedule(
                        document,
                        expiryDate: expiryDate,
                        fireDate: fireDate,
                        daysBefore: days,
                        accountName: Self.accountName(for: document, in: accountNames)
                    )
                }
            }
        }
    }

    /// The owning account's name, or nil when the document belongs to the
    /// account owner — their own documents need no label.
    private static func accountName(for document: Document, in names: [UUID: String]) -> String? {
        let spaceID = document.spaceID ?? ActiveSpaceManager.defaultSpaceID
        guard spaceID != ActiveSpaceManager.defaultSpaceID else { return nil }
        return names[spaceID]
    }

    private func schedule(_ document: Document,
                          expiryDate: Date,
                          fireDate: Date,
                          daysBefore: Int,
                          accountName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Document expiring soon"
        let dateString = Self.dateFormatter.string(from: expiryDate)
        let subject = accountName.map { "\($0): \(document.name)" } ?? document.name
        content.body = daysBefore == 1
            ? "\(subject) expires tomorrow (\(dateString)). Renew it before it lapses."
            : "\(subject) expires in \(daysBefore) days (\(dateString)). Renew it before it lapses."
        content.sound = .default
        content.userInfo = ["documentID": document.id.uuidString]

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(idPrefix)\(document.id.uuidString).\(daysBefore)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

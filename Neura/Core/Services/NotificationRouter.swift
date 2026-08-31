import Foundation
import Combine

/// Bridges a tapped local notification's payload into SwiftUI. Written by
/// `AppDelegate`'s `UNUserNotificationCenterDelegate` conformance on notification
/// tap; read by `DashboardView` to deep-link into the relevant document.
///
/// A `@Published` singleton rather than a `NotificationCenter` post: `@Published`
/// replays its current value to a new subscriber, so a value set before the view
/// hierarchy exists (e.g. a cold launch via notification tap, which can race
/// SwiftUI's first render) is never lost the way a plain notification post would be.
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    private init() {}

    @Published var pendingDocumentID: UUID?
}

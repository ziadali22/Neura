import UIKit

/// Centralised haptic feedback wrapper.
/// Use the static helpers anywhere in the app — no instance needed.
enum HapticManager {

    // MARK: - Impact

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func light()   { impact(.light) }
    static func medium()  { impact(.medium) }
    static func heavy()   { impact(.heavy) }
    static func soft()    { impact(.soft) }
    static func rigid()   { impact(.rigid) }

    // MARK: - Notification

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    static func success() { notification(.success) }
    static func warning() { notification(.warning) }
    static func error()   { notification(.error) }

    // MARK: - Selection

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

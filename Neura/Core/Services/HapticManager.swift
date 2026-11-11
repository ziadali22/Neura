import UIKit

/// Centralised haptic feedback wrapper.
/// Use the static helpers anywhere in the app — no instance needed.
/// Generators are retained so the system actually plays the feedback.
enum HapticManager {

    // MARK: - Generators

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Impact

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator: UIImpactFeedbackGenerator = switch style {
        case .light: lightGenerator
        case .medium: mediumGenerator
        case .heavy: heavyGenerator
        case .soft: softGenerator
        case .rigid: rigidGenerator
        @unknown default: mediumGenerator
        }
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
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }

    static func success() { notification(.success) }
    static func warning() { notification(.warning) }
    static func error()   { notification(.error) }

    // MARK: - Selection

    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}

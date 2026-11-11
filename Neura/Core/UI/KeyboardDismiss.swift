import SwiftUI
import UIKit

/// Dismiss the keyboard when the user taps anywhere on screen, WITHOUT swallowing
/// the touch. A tap gesture attached to a SwiftUI `Form`/`List` consumes the tap
/// before it reaches the row, silently breaking Pickers, buttons and
/// NavigationLinks. Installing the recognizer on the window with
/// `cancelsTouchesInView = false` lets the tap dismiss the keyboard *and* still
/// reach the underlying control.
private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var recognizer: UITapGestureRecognizer?

    func install() {
        guard recognizer == nil, let window = Self.keyWindow else { return }
        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false        // do not block taps to controls
        tap.delegate = self
        window.addGestureRecognizer(tap)
        recognizer = tap
    }

    func remove() {
        if let tap = recognizer { tap.view?.removeGestureRecognizer(tap) }
        recognizer = nil
    }

    // Recognize alongside the controls' own gestures (picker menus, buttons, etc).
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    @State private var coordinator = KeyboardDismissCoordinator()

    func body(content: Content) -> some View {
        content
            .onAppear { coordinator.install() }
            .onDisappear { coordinator.remove() }
    }
}

extension View {
    /// Tap anywhere to dismiss the keyboard, without interfering with controls.
    func dismissKeyboardOnTap() -> some View { modifier(DismissKeyboardOnTapModifier()) }
}

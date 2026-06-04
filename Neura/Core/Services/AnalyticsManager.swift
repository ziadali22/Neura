import Foundation
import Mixpanel

/// App-wide analytics, backed by Mixpanel.
///
/// Initialize once at launch via `AnalyticsManager.shared.initialize()`. Until a real
/// project token is set in `token`, the manager stays uninitialized and every `track`
/// call is a safe no-op — so the app never sends events to a bogus project or crashes.
final class AnalyticsManager {
    static let shared = AnalyticsManager()

    /// Mixpanel project token.
    /// TODO: replace with the real Mixpanel token before shipping.
    private let token = "51e98df5764628442010f4f052c2f40a"

    private let placeholderToken = "51e98df5764628442010f4f052c2f40a"
    private var isInitialized = false

    private init() {}

    /// The app's marketing version (`CFBundleShortVersionString`, e.g. "1.0"),
    /// used to version analytics event names.
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    /// Configures Mixpanel. Safe to call multiple times — only the first call has effect.
    /// No-ops while the token is still the placeholder, so analytics silently stays off
    /// until the real token lands.
    func initialize() {
        guard !isInitialized else { return }
        guard token != placeholderToken, !token.isEmpty else { return }

        Mixpanel.initialize(token: token, trackAutomaticEvents: false)
        isInitialized = true
    }

    /// Tracks an event. No-ops if analytics isn't initialized yet.
    func track(_ event: String, properties: [String: MixpanelType]? = nil) {
        guard isInitialized else { return }
        Mixpanel.mainInstance().track(event: event, properties: properties)
    }

    /// Associates subsequent events with a stable user identifier (e.g. after sign-in).
    func identify(_ distinctId: String) {
        guard isInitialized else { return }
        Mixpanel.mainInstance().identify(distinctId: distinctId)
    }

    /// Clears the current identity (e.g. on sign-out).
    func reset() {
        guard isInitialized else { return }
        Mixpanel.mainInstance().reset()
    }
}

import Foundation
import UIKit
import AppTrackingTransparency
import FacebookCore

/// Meta (Facebook) App Events, used to attribute installs and in-app actions to
/// Meta ad campaigns so App Promotion / App Install campaigns can optimise.
///
/// Configuration lives in `Info.plist` (`FacebookAppID`, `FacebookClientToken`) because
/// that is where the Facebook SDK itself reads it from — duplicating the values in Swift
/// would create two sources of truth that can drift. This manager only *validates* those
/// keys: while either one is still a `YOUR_*` placeholder the SDK is never started, so the
/// app can ship in this state without sending events to a non-existent Meta app. This
/// mirrors how `AnalyticsManager` gates on its Mixpanel token.
///
/// `fb_mobile_activate_app` (install + launch) is logged automatically by the SDK via
/// `FacebookAutoLogAppEventsEnabled` — it is deliberately never logged by hand here,
/// which would double-count launches.
final class MetaAdsManager {
    static let shared = MetaAdsManager()

    private let placeholderAppID = "YOUR_FACEBOOK_APP_ID"
    private let placeholderClientToken = "YOUR_FACEBOOK_CLIENT_TOKEN"

    private var isInitialized = false

    private init() {}

    // MARK: - Configuration

    private var appID: String {
        Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String ?? ""
    }

    private var clientToken: String {
        Bundle.main.object(forInfoDictionaryKey: "FacebookClientToken") as? String ?? ""
    }

    /// True once real Meta credentials have replaced the Info.plist placeholders.
    var isConfigured: Bool {
        !appID.isEmpty && appID != placeholderAppID
            && !clientToken.isEmpty && clientToken != placeholderClientToken
    }

    // MARK: - Lifecycle

    /// Starts the Facebook SDK. Must be called from
    /// `application(_:didFinishLaunchingWithOptions:)` — the SDK reads the launch options to
    /// log the activate-app event and to resolve deferred deep links from ads.
    ///
    /// Safe to call repeatedly; only the first call has effect. No-ops entirely while the
    /// Info.plist credentials are still placeholders.
    func initialize(application: UIApplication,
                    launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isInitialized, isConfigured else { return }

        // Must come before any Settings writes: this call is what injects Settings'
        // backing data store. Assignments made beforehand can land on an unconfigured
        // store and be silently dropped.
        _ = ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Send app events (including fb_mobile_activate_app) and collect the IDFV-based
        // advertiser ID so Meta can attribute installs. Both are also set via Info.plist;
        // repeating them here keeps the intent visible in code.
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true

        isInitialized = true

        // Push the auto-logged activate-app event out immediately instead of waiting
        // for the SDK's flush timer — Events Manager otherwise lags by a few minutes.
        flush()

        // Note there is deliberately no `Settings.shared.isAdvertiserTrackingEnabled`
        // assignment here. That setter is deprecated and inert on SDK v17+ / iOS 17+ —
        // the SDK now reads `ATTrackingManager.trackingAuthorizationStatus` itself, so
        // setting it would be misleading dead code.
        //
        // Neura shows no App Tracking Transparency prompt, so that status stays
        // `.notDetermined` and attribution runs through SKAdNetwork + Meta's Aggregated
        // Event Measurement — which is what App Install campaigns need. Adding an ATT
        // prompt later requires no change here: the SDK picks the new status up on its own.
    }

    /// Whether the user has granted ATT permission. Never prompts — only reads the
    /// current status. Exposed for diagnostics: the SDK consults ATT itself, so this is
    /// not wired into any setting.
    var isTrackingAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// Forwards an incoming URL to the SDK so clicks from Meta ads can be attributed.
    /// Returns whether the SDK consumed the URL.
    @discardableResult
    func handle(url: URL,
                application: UIApplication,
                options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard isInitialized else { return false }
        return ApplicationDelegate.shared.application(application, open: url, options: options)
    }

    // MARK: - Standard events

    /// `fb_mobile_complete_registration` — fired when a user finishes signing up.
    /// `method` records the auth provider (e.g. "apple", "google").
    func logCompleteRegistration(method: String) {
        guard isInitialized else { return }
        AppEvents.shared.logEvent(.completedRegistration,
                                  parameters: [.registrationMethod: method])
    }

    /// `fb_mobile_purchase` — a completed subscription purchase, with the real price and
    /// currency so Meta can optimise for value, not just conversion count.
    func logPurchase(amount: Double, currency: String, productID: String) {
        guard isInitialized else { return }
        AppEvents.shared.logPurchase(amount: amount,
                                     currency: currency,
                                     parameters: [.contentID: productID])
    }

    /// `fb_mobile_initiated_checkout` — the paywall was shown. The top of the purchase
    /// funnel, useful as an optimisation event before purchase volume is significant.
    func logInitiatedCheckout() {
        guard isInitialized else { return }
        AppEvents.shared.logEvent(.initiatedCheckout)
    }

    /// `fb_mobile_tutorial_completion` — onboarding finished. A strong early-quality
    /// signal for install campaigns, since it separates real users from bounces.
    func logCompletedTutorial() {
        guard isInitialized else { return }
        AppEvents.shared.logEvent(.completedTutorial)
    }

    /// `document_saved` — the app's core activation action. Deliberately a custom event
    /// rather than a standard one: no Meta standard event actually means "saved a
    /// document", and mislabelling it as `fb_mobile_content_view` would corrupt a signal
    /// the optimiser treats as meaningful. A single accurately-named custom event is
    /// still selectable as an optimisation goal for app-events campaigns.
    func logDocumentSaved() {
        guard isInitialized else { return }
        AppEvents.shared.logEvent(AppEvents.Name("document_saved"))
    }

    /// Flushes buffered events immediately instead of waiting for the SDK's timer.
    /// Only needed when verifying the integration in Meta Events Manager.
    func flush() {
        guard isInitialized else { return }
        AppEvents.shared.flush()
    }
}

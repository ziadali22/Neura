import AppTrackingTransparency

enum ATTrackingService {

    /// Requests ATT authorization if the status is still undetermined.
    /// Safe to call multiple times — no-ops if already determined.
    /// Must be called from the main actor after the UI has settled.
    @MainActor
    static func requestIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await ATTrackingManager.requestTrackingAuthorization()
    }
}

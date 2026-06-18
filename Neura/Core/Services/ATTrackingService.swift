import AppTrackingTransparency

enum ATTrackingService {
    @MainActor private static var didRequestThisSession = false

    /// Requests ATT authorization if the status is still undetermined.
    /// Safe to call multiple times — no-ops if already determined.
    /// Must be called from the main actor after the UI has settled.
    @MainActor
    @discardableResult
    static func requestIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        guard currentStatus == .notDetermined, !didRequestThisSession else {
            return currentStatus
        }

        didRequestThisSession = true
        return await ATTrackingManager.requestTrackingAuthorization()
    }
}

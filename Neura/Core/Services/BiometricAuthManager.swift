import Foundation
import LocalAuthentication
import Combine

@MainActor
final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isUnlocked = false

    enum BiometricType {
        case faceID, touchID, none
    }

    var biometricType: BiometricType {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics available — fall back to passcode
            return await authenticateWithPasscode()
        }

        let reason = "Unlock your Health Profile"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            isUnlocked = success
            return success
        } catch {
            return false
        }
    }

    private func authenticateWithPasscode() async -> Bool {
        let context = LAContext()
        let reason = "Unlock your Health Profile"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isUnlocked = success
            return success
        } catch {
            return false
        }
    }

    func lock() {
        isUnlocked = false
    }
}

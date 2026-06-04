import Foundation
import LocalAuthentication
import Combine

@MainActor
final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isUnlocked = false
    @Published private(set) var isBiometricLockEnabled: Bool

    private let preferenceKey = "neura_biometric_lock_enabled"

    private init() {
        isBiometricLockEnabled = UserDefaults.standard.bool(forKey: preferenceKey)
    }

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

    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "Biometrics"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.fill"
        }
    }

    @discardableResult
    func setBiometricLockEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            updateBiometricLockPreference(false)
            lock()
            return true
        }

        guard isBiometricAvailable else { return false }
        guard await authenticate() else { return false }
        updateBiometricLockPreference(true)
        return true
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

    private func updateBiometricLockPreference(_ enabled: Bool) {
        isBiometricLockEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: preferenceKey)
    }
}

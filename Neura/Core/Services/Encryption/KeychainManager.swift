import Foundation
import CryptoKit
import Security

// MARK: - Keychain Manager

@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.neura.encryption"
    private var cachedKey: SymmetricKey?

    private init() {}

    // MARK: - Load or Create Key

    /// Returns the existing encryption key for this user, or creates and stores a new one.
    /// The key is stored in iCloud Keychain so it syncs across the user's devices automatically.
    @discardableResult
    func loadOrCreateKey(for uid: String) -> SymmetricKey {
        if let cached = cachedKey { return cached }

        if let existing = loadKey(for: uid) {
            cachedKey = existing
            return existing
        }

        let newKey = SymmetricKey(size: .bits256)
        saveKey(newKey, for: uid)
        cachedKey = newKey
        return newKey
    }

    var currentKey: SymmetricKey? { cachedKey }

    /// Loads from cache or Keychain without creating a new key if absent.
    func tryLoadKey(for uid: String) -> SymmetricKey? {
        if let cached = cachedKey { return cached }
        if let key = loadKey(for: uid) {
            cachedKey = key
            return key
        }
        return nil
    }

    func clearKey() {
        cachedKey = nil
    }

    // MARK: - Keychain Read

    private func loadKey(for uid: String) -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: uid,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    // MARK: - Keychain Write

    private func saveKey(_ key: SymmetricKey, for uid: String) {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Remove any existing entry first (handles updates and old non-sync'd entries)
        let deleteQuery: [CFString: Any] = [
            kSecClass:              kSecClassGenericPassword,
            kSecAttrService:        service,
            kSecAttrAccount:        uid,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass:              kSecClassGenericPassword,
            kSecAttrService:        service,
            kSecAttrAccount:        uid,
            kSecValueData:          keyData,
            kSecAttrSynchronizable: true,                           // iCloud Keychain sync
            kSecAttrAccessible:     kSecAttrAccessibleAfterFirstUnlock  // background access
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

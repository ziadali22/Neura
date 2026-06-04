import Foundation
import FirebaseFirestore
import CryptoKit

/// Owns the canonical AES key stored at users/{uid}/keys/master in Firestore.
/// Firestore is the source of truth; the iCloud Keychain is an offline cache.
@MainActor
final class EncryptionKeyService {
    static let shared = EncryptionKeyService()
    private init() {}

    /// Resolves the account's encryption key.
    ///
    /// Order: Firestore (source of truth) → migrate a local Keychain key → create new.
    /// Returns `nil` only when offline with no cached key — callers must then defer
    /// sync rather than risk creating a divergent key.
    func resolveKey(uid: String) async -> SymmetricKey? {
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("keys").document("master")

        do {
            let snapshot = try await ref.getDocument()

            // 1. Firestore has the canonical key — use it, refresh the local cache.
            if let b64 = snapshot.data()?["key"] as? String,
               let raw = Data(base64Encoded: b64) {
                let key = SymmetricKey(data: raw)
                KeychainManager.shared.store(key, for: uid)
                SyncLog.success("Key resolved from Firestore")
                return key
            }

            // 2. No cloud key yet — migrate an existing local key if present.
            if let local = KeychainManager.shared.tryLoadKey(for: uid) {
                try await upload(local, to: ref)
                SyncLog.success("Migrated local key to Firestore")
                return local
            }

            // 3. Genuinely new user — create, upload, cache.
            let fresh = SymmetricKey(size: .bits256)
            try await upload(fresh, to: ref)
            KeychainManager.shared.store(fresh, for: uid)
            SyncLog.success("Created new account key")
            return fresh
        } catch {
            // 4. Offline / fetch failed — fall back to cache; never mint a key blind.
            SyncLog.failure("Key fetch failed; using cached key if any", error: error)
            return KeychainManager.shared.tryLoadKey(for: uid)
        }
    }

    private func upload(_ key: SymmetricKey, to ref: DocumentReference) async throws {
        let raw = key.withUnsafeBytes { Data($0) }
        try await ref.setData([
            "key": raw.base64EncodedString(),
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

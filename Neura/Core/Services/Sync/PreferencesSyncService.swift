import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Preferences Sync Service

/// Encrypted sync of onboarding preferences (medical areas + location) to
/// `users/{uid}/preferences/data`, mirroring HealthProfileSyncService.
actor PreferencesSyncService {
    static let shared = PreferencesSyncService()

    private init() {}

    // MARK: - Upload

    func upload(_ prefs: UserPreferences, uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(prefs)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("preferences").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> UserPreferences? {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("preferences").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode(UserPreferences.self, from: decrypted)
    }
}

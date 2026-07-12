import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Space Sync Service

/// Encrypted sync of the user's Space list to `users/{uid}/spaces/data`, mirroring
/// CalendarEntrySyncService/CustomFolderSyncService. The whole list is stored as a
/// single last-write-wins blob.
actor SpaceSyncService {
    static let shared = SpaceSyncService()

    private init() {}

    // MARK: - Upload

    func upload(_ spaces: [Space], uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(spaces)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("spaces").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> [Space]? {
        SyncLog.info("Downloading spaces")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("spaces").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode([Space].self, from: decrypted)
    }
}

import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Health Profile Sync Service

actor HealthProfileSyncService {
    static let shared = HealthProfileSyncService()

    private init() {}

    // MARK: - Upload

    func upload(profiles: [UUID: HealthProfile], uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(profiles)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("profile").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> [UUID: HealthProfile]? {
        SyncLog.info("Downloading health profiles")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("profile").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode([UUID: HealthProfile].self, from: decrypted)
    }
}

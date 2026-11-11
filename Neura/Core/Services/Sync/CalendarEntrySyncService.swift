import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Calendar Entry Sync Service

/// Encrypted sync of the user's calendar entries (appointments, medication,
/// medical events) to `users/{uid}/calendar/data`, mirroring
/// PreferencesSyncService. The whole entry list is stored as a single
/// last-write-wins blob — the same model used for the health profile and
/// preferences — so deleting an entry is just re-uploading the array without it.
actor CalendarEntrySyncService {
    static let shared = CalendarEntrySyncService()

    private init() {}

    // MARK: - Upload

    func upload(_ entries: [CalendarEntry], uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(entries)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("calendar").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> [CalendarEntry]? {
        SyncLog.info("Downloading calendar entries")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("calendar").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode([CalendarEntry].self, from: decrypted)
    }
}

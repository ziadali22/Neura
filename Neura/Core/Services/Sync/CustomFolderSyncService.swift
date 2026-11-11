import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Custom Folder Sync Service

/// Encrypted sync of the user's custom document folders to
/// `users/{uid}/folders/data`, mirroring CalendarEntrySyncService. The whole
/// folder list is stored as a single last-write-wins blob.
///
/// Folder *membership* lives on each document (the folder UUID in `tags`), but
/// the folder *name* lives only here — so without this sync a reinstall loses
/// every custom folder (and the auto-created "Other"), orphaning their docs.
actor CustomFolderSyncService {
    static let shared = CustomFolderSyncService()

    private init() {}

    // MARK: - Upload

    func upload(_ folders: [CustomFolder], uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(folders)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("folders").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> [CustomFolder]? {
        SyncLog.info("Downloading custom folders")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("folders").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode([CustomFolder].self, from: decrypted)
    }
}

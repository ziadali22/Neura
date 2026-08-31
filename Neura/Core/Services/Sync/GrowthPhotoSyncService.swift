import Foundation
import FirebaseStorage
import FirebaseFirestore
import CryptoKit

actor GrowthPhotoSyncService {
    static let shared = GrowthPhotoSyncService()

    private init() {}

    func upload(entryID: UUID, uid: String, key: SymmetricKey) async throws {
        let filename = GrowthPhotoStore.shared.filename(for: entryID)
        let fileURL = GrowthPhotoStore.shared.resolveURL(for: filename)
        let fileData = try Data(contentsOf: fileURL)

        let (fileIV, encryptedFile) = try EncryptionService.encrypt(fileData, key: key)
        let storagePath = "users/\(uid)/growth/\(entryID.uuidString).enc"
        let ref = Storage.storage().reference(withPath: storagePath)
        let storageMeta = StorageMetadata()
        storageMeta.contentType = "application/octet-stream"
        _ = try await ref.putDataAsync(encryptedFile, metadata: storageMeta)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("growth").document(entryID.uuidString)
            .setData([
                "fileIV": fileIV,
                "storagePath": storagePath,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    func delete(entryID: UUID, uid: String) async throws {
        let storagePath = "users/\(uid)/growth/\(entryID.uuidString).enc"
        try? await Storage.storage().reference(withPath: storagePath).delete()
        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("growth").document(entryID.uuidString)
            .delete()
    }

    /// Downloads any growth photos that exist in the cloud but not on disk.
    func downloadMissing(uid: String, key: SymmetricKey) async throws {
        SyncLog.info("Downloading missing growth photos")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("growth")
            .getDocuments()

        let store = GrowthPhotoStore.shared
        var restored = 0

        for docSnapshot in snapshot.documents {
            guard let entryID = UUID(uuidString: docSnapshot.documentID),
                  let fileIV = docSnapshot.data()["fileIV"] as? Data,
                  let storagePath = docSnapshot.data()["storagePath"] as? String
            else { continue }

            guard !store.fileExists(for: entryID) else { continue }

            guard let encryptedFile = try? await Storage.storage()
                .reference(withPath: storagePath)
                .data(maxSize: 20 * 1024 * 1024),
                  let fileData = try? EncryptionService.decrypt(ciphertext: encryptedFile, iv: fileIV, key: key)
            else { continue }

            let url = store.resolveURL(for: store.filename(for: entryID))
            try? fileData.write(to: url, options: .atomic)
            restored += 1
        }

        SyncLog.success("Restored \(restored) growth photo(s)")
    }
}

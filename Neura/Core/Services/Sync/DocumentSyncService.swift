import Foundation
import FirebaseStorage
import FirebaseFirestore
import CryptoKit

// MARK: - Document Sync Service

actor DocumentSyncService {
    static let shared = DocumentSyncService()

    private init() {}

    // MARK: - Upload (file + metadata)

    func upload(document: Document, uid: String, key: SymmetricKey) async throws {
        // 1. Read file from disk
        let fileData = try Data(contentsOf: document.fileURL)

        // 2. Encrypt file bytes
        let (fileIV, encryptedFile) = try EncryptionService.encrypt(fileData, key: key)

        // 3. Upload ciphertext to Storage
        let storagePath = "users/\(uid)/documents/\(document.id.uuidString).enc"
        let ref = Storage.storage().reference(withPath: storagePath)
        let storageMeta = StorageMetadata()
        storageMeta.contentType = "application/octet-stream"
        _ = try await ref.putDataAsync(encryptedFile, metadata: storageMeta)

        // 4. Encrypt document metadata
        let syncMeta = DocumentSyncMetadata(from: document)
        let metaData = try JSONEncoder().encode(syncMeta)
        let (metaIV, encryptedMeta) = try EncryptionService.encrypt(metaData, key: key)

        // 5. Write encrypted metadata to Firestore
        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("documents").document(document.id.uuidString)
            .setData([
                "encryptedMetadata": encryptedMeta,
                "metadataIV": metaIV,
                "fileIV": fileIV,
                "storagePath": storagePath,
                "createdAt": Timestamp(date: document.createdAt),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Update Metadata Only (rename / notes change)

    func updateMetadata(document: Document, uid: String, key: SymmetricKey) async throws {
        let syncMeta = DocumentSyncMetadata(from: document)
        let metaData = try JSONEncoder().encode(syncMeta)
        let (metaIV, encryptedMeta) = try EncryptionService.encrypt(metaData, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("documents").document(document.id.uuidString)
            .updateData([
                "encryptedMetadata": encryptedMeta,
                "metadataIV": metaIV,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Delete

    func delete(documentID: UUID, uid: String) async throws {
        let storagePath = "users/\(uid)/documents/\(documentID.uuidString).enc"
        // Storage delete is best-effort — file might not exist yet if upload was in-flight
        try? await Storage.storage().reference(withPath: storagePath).delete()

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("documents").document(documentID.uuidString)
            .delete()
    }

    // MARK: - Download All (new device restore)

    /// Downloads and decrypts all documents from the cloud, saves missing files to disk,
    /// and returns the full list. Skips files that already exist locally.
    func downloadAll(uid: String, key: SymmetricKey) async throws -> [Document] {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("documents")
            .getDocuments()

        let fm = DocumentFileManager.shared
        var restored: [Document] = []

        for docSnapshot in snapshot.documents {
            let data = docSnapshot.data()
            guard let encryptedMeta = data["encryptedMetadata"] as? Data,
                  let metaIV        = data["metadataIV"] as? Data,
                  let fileIV        = data["fileIV"] as? Data,
                  let storagePath   = data["storagePath"] as? String else { continue }

            // Decrypt metadata
            guard let metaRaw  = try? EncryptionService.decrypt(ciphertext: encryptedMeta, iv: metaIV, key: key),
                  let syncMeta = try? JSONDecoder().decode(DocumentSyncMetadata.self, from: metaRaw) else { continue }

            let localURL = fm.resolveURL(for: syncMeta.filename)

            // Download & decrypt the file only when it's not already on disk
            if !FileManager.default.fileExists(atPath: localURL.path) {
                guard let encryptedFile = try? await Storage.storage()
                    .reference(withPath: storagePath)
                    .data(maxSize: 100 * 1024 * 1024),
                      let fileData = try? EncryptionService.decrypt(ciphertext: encryptedFile, iv: fileIV, key: key)
                else { continue }

                try? fileData.write(to: localURL, options: .atomic)
            }

            // Reconstruct the Document model
            let docID = UUID(uuidString: docSnapshot.documentID) ?? UUID()
            let doc = Document(
                id: docID,
                name: syncMeta.name,
                fileURL: localURL,
                createdAt: syncMeta.createdAt,
                documentType: DocumentType(rawValue: syncMeta.documentType) ?? .pdf,
                category: syncMeta.category.flatMap { DocumentCategory(rawValue: $0) },
                specialization: syncMeta.specialization.flatMap { MedicalSpecialization(rawValue: $0) },
                doctorName: syncMeta.doctorName,
                notes: syncMeta.notes,
                tags: syncMeta.tags
            )
            restored.append(doc)
        }

        return restored
    }
}

// MARK: - Encrypted Metadata Payload

private struct DocumentSyncMetadata: Codable {
    let name: String
    let filename: String
    let createdAt: Date
    let documentType: String
    let category: String?
    let specialization: String?
    let doctorName: String?
    let notes: String?
    let tags: [String]?

    init(from doc: Document) {
        name           = doc.name
        filename       = doc.filename
        createdAt      = doc.createdAt
        documentType   = doc.documentType.rawValue
        category       = doc.category?.rawValue
        specialization = doc.specialization?.rawValue
        doctorName     = doc.doctorName
        notes          = doc.notes
        tags           = doc.tags
    }
}

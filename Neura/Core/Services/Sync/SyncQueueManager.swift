import Foundation
import Combine
import CryptoKit
import FirebaseAuth

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case syncing
    case synced
    case failed
}

// MARK: - Sync Queue Manager

@MainActor
final class SyncQueueManager: ObservableObject {
    static let shared = SyncQueueManager()

    /// Per-document sync status — observe this for UI indicators.
    @Published private(set) var syncStatuses: [UUID: SyncStatus] = [:]

    private init() {}

    // MARK: - Upload

    func enqueueUpload(_ document: Document) {
        guard let uid = AuthService.shared.currentUser?.uid,
              let key = KeychainManager.shared.currentKey else { return }

        syncStatuses[document.id] = .syncing

        Task {
            do {
                try await DocumentSyncService.shared.upload(document: document, uid: uid, key: key)
                syncStatuses[document.id] = .synced
            } catch {
                syncStatuses[document.id] = .failed
            }
        }
    }

    // MARK: - Metadata Update (rename, notes)

    func enqueueMetadataUpdate(_ document: Document) {
        guard let uid = AuthService.shared.currentUser?.uid,
              let key = KeychainManager.shared.currentKey else { return }

        Task {
            try? await DocumentSyncService.shared.updateMetadata(document: document, uid: uid, key: key)
        }
    }

    // MARK: - Delete

    func enqueueDelete(_ documentID: UUID) {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        syncStatuses.removeValue(forKey: documentID)

        Task {
            try? await DocumentSyncService.shared.delete(documentID: documentID, uid: uid)
        }
    }

    // MARK: - Health Profile Upload

    func enqueueProfileUpload(_ profile: HealthProfile) {
        guard let uid = AuthService.shared.currentUser?.uid,
              let key = KeychainManager.shared.currentKey else { return }

        Task {
            try? await HealthProfileSyncService.shared.upload(profile: profile, uid: uid, key: key)
        }
    }

    // MARK: - Initial Restore (new device / reinstall)

    /// Downloads all cloud data for the user and saves it locally.
    /// Called once per sign-in; idempotent — skips files already on disk.
    func performInitialRestore(uid: String, key: SymmetricKey) {
        Task {
            // 1. Health profile
            if let profile = try? await HealthProfileSyncService.shared.download(uid: uid, key: key),
               let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: "health_profile_data")
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
            }

            // 2. Documents — download missing files, rebuild metadata
            if let restored = try? await DocumentSyncService.shared.downloadAll(uid: uid, key: key),
               !restored.isEmpty {
                // Merge with any existing local docs (avoid duplicates)
                let existing = DocumentFileManager.shared.loadMetadata()
                var merged = existing
                for doc in restored where !existing.contains(where: { $0.id == doc.id }) {
                    merged.append(doc)
                }
                try? DocumentFileManager.shared.saveMetadata(merged)

                // Notify DocumentsListViewModel to reload
                await MainActor.run {
                    NotificationCenter.default.post(name: .documentsRestored, object: nil)
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let documentsRestored = Notification.Name("com.neura.documentsRestored")
    static let healthProfileRestored = Notification.Name("com.neura.healthProfileRestored")
}

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

    private let pending = PendingSyncStore.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Drain whenever connectivity is (re)established.
        NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                if connected { self?.drainPending() }
            }
            .store(in: &cancellables)
    }

    private var uid: String? { AuthService.shared.currentUser?.uid }
    private var key: SymmetricKey? { KeychainManager.shared.currentKey }

    // MARK: - Upload

    func enqueueUpload(_ document: Document) {
        pending.add(PendingSyncOp(kind: .documentUpload, id: document.id.uuidString))
        attemptUpload(document)
    }

    private func attemptUpload(_ document: Document) {
        guard let uid, let key else {
            SyncLog.info("Upload deferred (no uid/key): \(document.id)")
            return
        }
        syncStatuses[document.id] = .syncing
        Task {
            do {
                try await DocumentSyncService.shared.upload(document: document, uid: uid, key: key)
                syncStatuses[document.id] = .synced
                pending.remove(PendingSyncOp(kind: .documentUpload, id: document.id.uuidString))
                SyncLog.success("Uploaded document \(document.id)")
            } catch {
                syncStatuses[document.id] = .failed
                SyncLog.failure("Upload failed \(document.id)", error: error)
            }
        }
    }

    // MARK: - Metadata Update (rename, notes)

    func enqueueMetadataUpdate(_ document: Document) {
        pending.add(PendingSyncOp(kind: .documentMetadata, id: document.id.uuidString))
        attemptMetadataUpdate(document)
    }

    private func attemptMetadataUpdate(_ document: Document) {
        guard let uid, let key else { return }
        Task {
            do {
                try await DocumentSyncService.shared.updateMetadata(document: document, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .documentMetadata, id: document.id.uuidString))
                SyncLog.success("Updated metadata \(document.id)")
            } catch {
                SyncLog.failure("Metadata update failed \(document.id)", error: error)
            }
        }
    }

    // MARK: - Delete

    func enqueueDelete(_ documentID: UUID) {
        syncStatuses.removeValue(forKey: documentID)
        pending.add(PendingSyncOp(kind: .documentDelete, id: documentID.uuidString))
        attemptDelete(documentID)
    }

    private func attemptDelete(_ documentID: UUID) {
        guard let uid else { return }
        Task {
            do {
                try await DocumentSyncService.shared.delete(documentID: documentID, uid: uid)
                pending.remove(PendingSyncOp(kind: .documentDelete, id: documentID.uuidString))
                SyncLog.success("Deleted document \(documentID)")
            } catch {
                SyncLog.failure("Delete failed \(documentID)", error: error)
            }
        }
    }

    // MARK: - Health Profile Upload

    func enqueueProfileUpload(_ profile: HealthProfile) {
        pending.add(PendingSyncOp(kind: .profileUpload, id: nil))
        attemptProfileUpload(profile)
    }

    private func attemptProfileUpload(_ profile: HealthProfile) {
        guard let uid, let key else { return }
        Task {
            do {
                try await HealthProfileSyncService.shared.upload(profile: profile, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .profileUpload, id: nil))
                SyncLog.success("Uploaded health profile")
            } catch {
                SyncLog.failure("Profile upload failed", error: error)
            }
        }
    }

    // MARK: - Preferences Upload

    func enqueuePreferencesUpload(_ prefs: UserPreferences) {
        pending.add(PendingSyncOp(kind: .preferencesUpload, id: nil))
        attemptPreferencesUpload(prefs)
    }

    private func attemptPreferencesUpload(_ prefs: UserPreferences) {
        guard let uid, let key else { return }
        Task {
            do {
                try await PreferencesSyncService.shared.upload(prefs, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .preferencesUpload, id: nil))
                SyncLog.success("Uploaded preferences")
            } catch {
                SyncLog.failure("Preferences upload failed", error: error)
            }
        }
    }

    // MARK: - Drain (retry everything pending)

    /// Re-attempts every queued operation. Payloads are reconstructed from local
    /// state (document metadata on disk, profile/preferences from UserDefaults).
    func drainPending() {
        guard uid != nil, key != nil else {
            SyncLog.info("Drain skipped (no uid/key yet)")
            return
        }
        let ops = pending.all
        guard !ops.isEmpty else { return }
        SyncLog.info("Draining \(ops.count) pending op(s)")

        let docs = DocumentFileManager.shared.loadMetadata()
        for op in ops {
            switch op.kind {
            case .documentUpload:
                if let id = op.id, let uuid = UUID(uuidString: id),
                   let doc = docs.first(where: { $0.id == uuid }) {
                    attemptUpload(doc)
                } else {
                    pending.remove(op)   // document no longer exists locally
                }
            case .documentMetadata:
                if let id = op.id, let uuid = UUID(uuidString: id),
                   let doc = docs.first(where: { $0.id == uuid }) {
                    attemptMetadataUpdate(doc)
                } else {
                    pending.remove(op)
                }
            case .documentDelete:
                if let id = op.id, let uuid = UUID(uuidString: id) {
                    attemptDelete(uuid)
                } else {
                    pending.remove(op)
                }
            case .profileUpload:
                if let data = UserDefaults.standard.data(forKey: "health_profile_data"),
                   let profile = try? JSONDecoder().decode(HealthProfile.self, from: data) {
                    attemptProfileUpload(profile)
                } else {
                    pending.remove(op)
                }
            case .preferencesUpload:
                let location = UserDefaults.standard.string(forKey: "user_location") ?? ""
                var areas: [String] = []
                if let areasData = UserDefaults.standard.data(forKey: "onboarding_medical_areas"),
                   let decoded = try? JSONDecoder().decode([String].self, from: areasData) {
                    areas = decoded
                }
                // Only sync real local preferences — never overwrite good cloud data
                // with empty values, and drop the op when there's nothing to sync.
                if location.isEmpty && areas.isEmpty {
                    pending.remove(op)
                } else {
                    attemptPreferencesUpload(UserPreferences(medicalAreas: areas, location: location))
                }
            }
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
                SyncLog.success("Restored health profile")
            }

            // 1b. Preferences (medical areas + location)
            if let prefs = try? await PreferencesSyncService.shared.download(uid: uid, key: key) {
                UserDefaults.standard.set(prefs.location, forKey: "user_location")
                if let areasData = try? JSONEncoder().encode(prefs.medicalAreas) {
                    UserDefaults.standard.set(areasData, forKey: "onboarding_medical_areas")
                }
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
                SyncLog.success("Restored preferences")
            }

            // 2. Documents — download missing files, rebuild metadata
            if let restored = try? await DocumentSyncService.shared.downloadAll(uid: uid, key: key),
               !restored.isEmpty {
                let existing = DocumentFileManager.shared.loadMetadata()
                var merged = existing
                for doc in restored where !existing.contains(where: { $0.id == doc.id }) {
                    merged.append(doc)
                }
                try? DocumentFileManager.shared.saveMetadata(merged)
                NotificationCenter.default.post(name: .documentsRestored, object: nil)
                SyncLog.success("Restored \(restored.count) document(s)")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let documentsRestored = Notification.Name("com.neura.documentsRestored")
    static let healthProfileRestored = Notification.Name("com.neura.healthProfileRestored")
}

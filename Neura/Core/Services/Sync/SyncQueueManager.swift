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

    func enqueueProfileUpload(_ profiles: [UUID: HealthProfile]) {
        pending.add(PendingSyncOp(kind: .profileUpload, id: nil))
        attemptProfileUpload(profiles)
    }

    private func attemptProfileUpload(_ profiles: [UUID: HealthProfile]) {
        guard let uid, let key else { return }
        Task {
            do {
                try await HealthProfileSyncService.shared.upload(profiles: profiles, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .profileUpload, id: nil))
                SyncLog.success("Uploaded health profile(s)")
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

    // MARK: - Calendar Upload

    func enqueueCalendarUpload(_ entries: [CalendarEntry]) {
        pending.add(PendingSyncOp(kind: .calendarUpload, id: nil))
        attemptCalendarUpload(entries)
    }

    private func attemptCalendarUpload(_ entries: [CalendarEntry]) {
        guard let uid, let key else { return }
        Task {
            do {
                try await CalendarEntrySyncService.shared.upload(entries, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .calendarUpload, id: nil))
                SyncLog.success("Uploaded calendar entries")
            } catch {
                SyncLog.failure("Calendar upload failed", error: error)
            }
        }
    }

    // MARK: - Custom Folders Upload

    func enqueueCustomFoldersUpload(_ folders: [CustomFolder]) {
        pending.add(PendingSyncOp(kind: .customFoldersUpload, id: nil))
        attemptCustomFoldersUpload(folders)
    }

    private func attemptCustomFoldersUpload(_ folders: [CustomFolder]) {
        guard let uid, let key else { return }
        // Never overwrite good cloud data with an empty list — this is the same
        // empty-clobber guard used for preferences/calendar. A freshly reinstalled
        // store starts empty until restore finishes; uploading [] here would wipe
        // the folders we're about to download.
        guard !folders.isEmpty else {
            pending.remove(PendingSyncOp(kind: .customFoldersUpload, id: nil))
            return
        }
        Task {
            do {
                try await CustomFolderSyncService.shared.upload(folders, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .customFoldersUpload, id: nil))
                SyncLog.success("Uploaded custom folders")
            } catch {
                SyncLog.failure("Custom folders upload failed", error: error)
            }
        }
    }

    // MARK: - Spaces Upload

    func enqueueSpacesUpload(_ spaces: [Space]) {
        pending.add(PendingSyncOp(kind: .spacesUpload, id: nil))
        attemptSpacesUpload(spaces)
    }

    private func attemptSpacesUpload(_ spaces: [Space]) {
        guard let uid, let key else { return }
        // Never overwrite good cloud data with an empty list (same guard as
        // custom folders). Spaces always has >=1 (the default), so this is
        // belt-and-suspenders.
        guard !spaces.isEmpty else {
            pending.remove(PendingSyncOp(kind: .spacesUpload, id: nil))
            return
        }
        Task {
            do {
                try await SpaceSyncService.shared.upload(spaces, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .spacesUpload, id: nil))
                SyncLog.success("Uploaded spaces")
            } catch {
                SyncLog.failure("Spaces upload failed", error: error)
            }
        }
    }

    // MARK: - Growth Photo Upload

    func enqueueGrowthPhotoUpload(_ entryID: UUID) {
        pending.add(PendingSyncOp(kind: .growthPhotoUpload, id: entryID.uuidString))
        attemptGrowthPhotoUpload(entryID)
    }

    private func attemptGrowthPhotoUpload(_ entryID: UUID) {
        guard let uid, let key else { return }
        Task {
            do {
                try await GrowthPhotoSyncService.shared.upload(entryID: entryID, uid: uid, key: key)
                pending.remove(PendingSyncOp(kind: .growthPhotoUpload, id: entryID.uuidString))
                SyncLog.success("Uploaded growth photo \(entryID)")
            } catch {
                SyncLog.failure("Growth photo upload failed \(entryID)", error: error)
            }
        }
    }

    func enqueueGrowthPhotoDelete(_ entryID: UUID) {
        pending.add(PendingSyncOp(kind: .growthPhotoDelete, id: entryID.uuidString))
        attemptGrowthPhotoDelete(entryID)
    }

    private func attemptGrowthPhotoDelete(_ entryID: UUID) {
        guard let uid else { return }
        Task {
            do {
                try await GrowthPhotoSyncService.shared.delete(entryID: entryID, uid: uid)
                pending.remove(PendingSyncOp(kind: .growthPhotoDelete, id: entryID.uuidString))
                SyncLog.success("Deleted growth photo \(entryID)")
            } catch {
                SyncLog.failure("Growth photo delete failed \(entryID)", error: error)
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
                if let data = UserDefaults.standard.data(forKey: "health_profiles_by_space"),
                   let profiles = try? JSONDecoder().decode([UUID: HealthProfile].self, from: data) {
                    attemptProfileUpload(profiles)
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
            case .calendarUpload:
                let entries = CalendarEntryStore.shared.loadEntriesFromDisk()
                if entries.isEmpty {
                    pending.remove(op)
                } else {
                    attemptCalendarUpload(entries)
                }
            case .customFoldersUpload:
                let folders = CustomFolderStore.shared.folders
                if folders.isEmpty {
                    pending.remove(op)
                } else {
                    attemptCustomFoldersUpload(folders)
                }
            case .spacesUpload:
                let spaces = ActiveSpaceManager.shared.spaces
                if spaces.isEmpty {
                    pending.remove(op)
                } else {
                    attemptSpacesUpload(spaces)
                }
            case .growthPhotoUpload:
                if let id = op.id, let uuid = UUID(uuidString: id),
                   GrowthPhotoStore.shared.fileExists(for: uuid) {
                    attemptGrowthPhotoUpload(uuid)
                } else {
                    pending.remove(op)
                }
            case .growthPhotoDelete:
                if let id = op.id, let uuid = UUID(uuidString: id) {
                    attemptGrowthPhotoDelete(uuid)
                } else {
                    pending.remove(op)
                }
            }
        }
    }

    // MARK: - Initial Restore (new device / reinstall)

    /// Downloads all cloud data for the user and saves it locally.
    /// Called once per sign-in; idempotent — skips files already on disk.
    func performInitialRestore(uid: String, key: SymmetricKey) {
        Task {
            // 1. Spaces — restored BEFORE everything else so the containers
            // that documents/entries/health profiles reference (via spaceID)
            // already exist locally when the rest of the restore runs.
            if let cloudSpaces = try? await SpaceSyncService.shared.download(uid: uid, key: key),
               !cloudSpaces.isEmpty {
                ActiveSpaceManager.shared.mergeFromCloud(cloudSpaces)
                SyncLog.success("Restored \(cloudSpaces.count) space(s)")
            }

            // 2. Health profile(s)
            if let profiles = try? await HealthProfileSyncService.shared.download(uid: uid, key: key),
               let data = try? JSONEncoder().encode(profiles) {
                UserDefaults.standard.set(data, forKey: "health_profiles_by_space")
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
                SyncLog.success("Restored \(profiles.count) health profile(s)")
            }

            // 2b. Preferences (medical areas + location)
            if let prefs = try? await PreferencesSyncService.shared.download(uid: uid, key: key) {
                UserDefaults.standard.set(prefs.location, forKey: "user_location")
                if let areasData = try? JSONEncoder().encode(prefs.medicalAreas) {
                    UserDefaults.standard.set(areasData, forKey: "onboarding_medical_areas")
                }
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
                SyncLog.success("Restored preferences")
            }

            // 2c. Custom folders — restore BEFORE documents so the folders that
            // documents reference (via the folder UUID in `tags`) already exist
            // when the grid rebuilds, and no duplicate "Other" is auto-created.
            if let cloudFolders = try? await CustomFolderSyncService.shared.download(uid: uid, key: key),
               !cloudFolders.isEmpty {
                CustomFolderStore.shared.merge(cloudFolders)
                SyncLog.success("Restored \(cloudFolders.count) custom folder(s)")
            }

            // 3. Documents — download missing files, rebuild metadata
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

            // 3b. Growth photos — after profiles so we know which measurements exist,
            // but listing the cloud collection is enough even if a local entry is stale.
            do {
                try await GrowthPhotoSyncService.shared.downloadMissing(uid: uid, key: key)
            } catch {
                SyncLog.failure("Growth photo restore failed", error: error)
            }

            // 4. Calendar entries (appointments / medication / medical events)
            if let cloudEntries = try? await CalendarEntrySyncService.shared.download(uid: uid, key: key),
               !cloudEntries.isEmpty {
                let local = CalendarEntryStore.shared.loadEntriesFromDisk()
                var merged = local
                for entry in cloudEntries where !local.contains(where: { $0.id == entry.id }) {
                    merged.append(entry)
                }
                CalendarEntryStore.shared.replaceAll(merged)
                NotificationCenter.default.post(name: .calendarEntriesRestored, object: nil)
                // Re-arm reminders now so notifications aren't missing until the
                // next foreground.
                CalendarReminderScheduler.shared.reschedule(for: merged)
                SyncLog.success("Restored \(cloudEntries.count) calendar entr(ies)")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let documentsRestored = Notification.Name("com.neura.documentsRestored")
    static let healthProfileRestored = Notification.Name("com.neura.healthProfileRestored")
    static let calendarEntriesRestored = Notification.Name("com.neura.calendarEntriesRestored")
    /// Posted after any local document mutation (add / update / delete) persists,
    /// so other screens holding a cached snapshot (e.g. Home's recent list) refresh.
    static let documentsChanged = Notification.Name("com.neura.documentsChanged")
}

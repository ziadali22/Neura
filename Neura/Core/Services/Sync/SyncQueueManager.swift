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
        mirrorDocumentToICloud(document)
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
        mirrorDocumentToICloud(document)
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
        Task { await CloudKitBackupService.shared.deleteDocument(documentID, uid: uid) }
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
        if let uid {
            Task { await CloudKitBackupService.shared.backupHealthProfiles(profiles, uid: uid) }
        }
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
        if let uid {
            Task { await CloudKitBackupService.shared.backupPreferences(prefs, uid: uid, force: true) }
        }
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
        if let uid {
            Task { await CloudKitBackupService.shared.backupCalendar(entries, uid: uid, force: true) }
        }
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
        if let uid, !folders.isEmpty {
            Task { await CloudKitBackupService.shared.backupFolders(folders, uid: uid, force: true) }
        }
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
        if let uid, !spaces.isEmpty {
            let userID = uid
            Task { await CloudKitBackupService.shared.backupSpaces(spaces, uid: userID, force: true) }
            let avatarIDs = spaces.compactMap { $0.avatarFilename == nil ? nil : $0.id }
            if !avatarIDs.isEmpty {
                Task { await CloudKitBackupService.shared.backupAvatars(avatarIDs, uid: userID, force: true) }
            }
        }
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
        if let uid {
            Task { await CloudKitBackupService.shared.backupGrowthPhoto(entryID, uid: uid) }
        }
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
        Task { await CloudKitBackupService.shared.deleteGrowthPhoto(entryID, uid: uid) }
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

    /// Downloads cloud data, then uploads anything that still exists only on
    /// this device. iCloud restore runs before this, so a Firebase failure
    /// still leaves the backup copy on the phone.
    /// Called on sign-in and on each cold launch while signed in.
    func performInitialRestore(uid: String, key: SymmetricKey) async {
        // 1. Spaces — restored BEFORE everything else so the containers
        // that documents/entries/health profiles reference (via spaceID)
        // already exist locally when the rest of the restore runs.
        await restoreSpaces(uid: uid, key: key)

        // 2. Health profile(s)
        await restoreHealthProfiles(uid: uid, key: key)

        // 2b. Preferences (medical areas + location)
        await restorePreferences(uid: uid, key: key)

        // 2c. Custom folders — restore BEFORE documents so the folders that
        // documents reference (via the folder UUID in `tags`) already exist
        // when the grid rebuilds, and no duplicate "Other" is auto-created.
        await restoreCustomFolders(uid: uid, key: key)

        // 3. Documents — download missing files, then upload device-only files.
        await restoreDocuments(uid: uid, key: key)

        // 3b. Growth photos — after profiles so measurement records exist,
        // then upload photos that never reached Storage.
        await restoreGrowthPhotos(uid: uid, key: key)

        // 4. Calendar entries (appointments / medication / medical events)
        await restoreCalendar(uid: uid, key: key)
    }

    // MARK: - Restore + backfill

    /// Records that exist on this device and not in Firebase. Field differences
    /// on a shared id are ignored so a backup upload cannot overwrite a copy
    /// another device already saved.
    private func recordsMissingFromCloud<T: Identifiable>(
        local: [T],
        cloud: [T]
    ) -> [T] where T.ID: Hashable {
        let cloudIDs = Set(cloud.map(\.id))
        return local.filter { !cloudIDs.contains($0.id) }
    }

    private func restoreSpaces(uid: String, key: SymmetricKey) async {
        let cloud: [Space]?
        do {
            cloud = try await SpaceSyncService.shared.download(uid: uid, key: key)
        } catch {
            SyncLog.failure("Space restore failed; local spaces left in place", error: error)
            return
        }

        if let cloud, !cloud.isEmpty {
            ActiveSpaceManager.shared.mergeFromCloud(cloud)
            SyncLog.success("Restored \(cloud.count) space(s)")
            let missing = recordsMissingFromCloud(local: ActiveSpaceManager.shared.spaces, cloud: cloud)
            guard !missing.isEmpty else { return }
            SyncLog.info("Backing up \(missing.count) space(s) missing from Firebase")
            // Cloud copies of shared accounts stay as saved; only the device-only ones are added.
            enqueueSpacesUpload(cloud + missing)
            return
        }

        let local = ActiveSpaceManager.shared.spaces
        guard !local.isEmpty else { return }
        SyncLog.info("Backing up \(local.count) space(s) that were never saved to Firebase")
        enqueueSpacesUpload(local)
    }

    private func restoreHealthProfiles(uid: String, key: SymmetricKey) async {
        let cloud: [UUID: HealthProfile]?
        do {
            cloud = try await HealthProfileSyncService.shared.download(uid: uid, key: key)
        } catch {
            SyncLog.failure("Health profile restore failed; local profile left in place", error: error)
            return
        }

        let local = localHealthProfiles()
        let (merged, shouldUpload) = mergedHealthProfiles(cloud: cloud, local: local)
        guard !merged.isEmpty else { return }

        if let data = try? JSONEncoder().encode(merged) {
            UserDefaults.standard.set(data, forKey: "health_profiles_by_space")
            NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
        }

        if shouldUpload {
            SyncLog.info("Backing up health profile that is newer or missing in Firebase")
            enqueueProfileUpload(merged)
        } else if cloud != nil {
            SyncLog.success("Restored \(merged.count) health profile(s)")
        }
    }

    /// Keeps the newer profile per space. A profile that exists only on the
    /// device (Firebase outage) is kept and flagged for upload.
    private func mergedHealthProfiles(
        cloud: [UUID: HealthProfile]?,
        local: [UUID: HealthProfile]
    ) -> (profiles: [UUID: HealthProfile], shouldUpload: Bool) {
        guard let cloud else {
            return (local, !local.isEmpty)
        }
        var merged = cloud
        var shouldUpload = false
        for (id, localProfile) in local {
            if let cloudProfile = merged[id] {
                if localProfile.lastUpdated > cloudProfile.lastUpdated {
                    merged[id] = localProfile
                    shouldUpload = true
                }
            } else {
                merged[id] = localProfile
                shouldUpload = true
            }
        }
        return (merged, shouldUpload)
    }

    /// Reads the on-disk profile, including the pre-Spaces single-profile key,
    /// so a user who never opened the profile screen still gets backed up.
    private func localHealthProfiles() -> [UUID: HealthProfile] {
        if let data = UserDefaults.standard.data(forKey: "health_profiles_by_space"),
           let profiles = try? JSONDecoder().decode([UUID: HealthProfile].self, from: data),
           !profiles.isEmpty {
            return profiles
        }
        if let legacyData = UserDefaults.standard.data(forKey: "health_profile_data"),
           let legacy = try? JSONDecoder().decode(HealthProfile.self, from: legacyData) {
            let migrated = [ActiveSpaceManager.defaultSpaceID: legacy]
            if let data = try? JSONEncoder().encode(migrated) {
                UserDefaults.standard.set(data, forKey: "health_profiles_by_space")
            }
            return migrated
        }
        return [:]
    }

    private func restorePreferences(uid: String, key: SymmetricKey) async {
        let cloud: UserPreferences?
        do {
            cloud = try await PreferencesSyncService.shared.download(uid: uid, key: key)
        } catch {
            SyncLog.failure("Preferences restore failed; local preferences left in place", error: error)
            return
        }

        if let cloud {
            UserDefaults.standard.set(cloud.location, forKey: "user_location")
            if let areasData = try? JSONEncoder().encode(cloud.medicalAreas) {
                UserDefaults.standard.set(areasData, forKey: "onboarding_medical_areas")
            }
            NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
            SyncLog.success("Restored preferences")
            return
        }

        let location = UserDefaults.standard.string(forKey: "user_location") ?? ""
        var areas: [String] = []
        if let areasData = UserDefaults.standard.data(forKey: "onboarding_medical_areas"),
           let decoded = try? JSONDecoder().decode([String].self, from: areasData) {
            areas = decoded
        }
        guard !location.isEmpty || !areas.isEmpty else { return }
        SyncLog.info("Backing up preferences that are missing from Firebase")
        enqueuePreferencesUpload(UserPreferences(medicalAreas: areas, location: location))
    }

    private func restoreCustomFolders(uid: String, key: SymmetricKey) async {
        let cloud: [CustomFolder]?
        do {
            cloud = try await CustomFolderSyncService.shared.download(uid: uid, key: key)
        } catch {
            SyncLog.failure("Custom folder restore failed; local folders left in place", error: error)
            return
        }

        if let cloud, !cloud.isEmpty {
            CustomFolderStore.shared.merge(cloud)
            SyncLog.success("Restored \(cloud.count) custom folder(s)")
            let missing = recordsMissingFromCloud(local: CustomFolderStore.shared.folders, cloud: cloud)
            guard !missing.isEmpty else { return }
            SyncLog.info("Backing up \(missing.count) custom folder(s) missing from Firebase")
            enqueueCustomFoldersUpload(cloud + missing)
            return
        }

        let local = CustomFolderStore.shared.folders
        guard !local.isEmpty else { return }
        SyncLog.info("Backing up \(local.count) custom folder(s) that were never saved to Firebase")
        enqueueCustomFoldersUpload(local)
    }

    private func restoreDocuments(uid: String, key: SymmetricKey) async {
        let restored: [Document]
        do {
            restored = try await DocumentSyncService.shared.downloadAll(uid: uid, key: key)
        } catch {
            SyncLog.failure("Document restore failed; local files left in place for the next launch", error: error)
            return
        }

        if !restored.isEmpty {
            let added = mergeRestoredDocuments(restored)
            if added > 0 {
                SyncLog.success("Restored \(added) document(s)")
            }
        }

        let cloudIDs = Set(restored.map(\.id))
        let localOnly = DocumentFileManager.shared.loadMetadata().filter {
            !cloudIDs.contains($0.id) && DocumentFileManager.shared.fileExists(for: $0)
        }
        guard !localOnly.isEmpty else { return }
        SyncLog.info("Backing up \(localOnly.count) document(s) that exist only on this device")
        for doc in localOnly {
            enqueueUpload(doc)
        }
    }

    private func restoreGrowthPhotos(uid: String, key: SymmetricKey) async {
        let cloudIDs: Set<UUID>
        do {
            cloudIDs = try await GrowthPhotoSyncService.shared.downloadMissing(uid: uid, key: key)
        } catch {
            SyncLog.failure("Growth photo restore failed; local photos left in place", error: error)
            return
        }

        let localOnly = GrowthPhotoStore.shared.localEntryIDs().filter { !cloudIDs.contains($0) }
        guard !localOnly.isEmpty else { return }
        SyncLog.info("Backing up \(localOnly.count) growth photo(s) that exist only on this device")
        for entryID in localOnly {
            enqueueGrowthPhotoUpload(entryID)
        }
    }

    private func restoreCalendar(uid: String, key: SymmetricKey) async {
        let cloud: [CalendarEntry]?
        do {
            cloud = try await CalendarEntrySyncService.shared.download(uid: uid, key: key)
        } catch {
            SyncLog.failure("Calendar restore failed; local entries left in place", error: error)
            return
        }

        let local = CalendarEntryStore.shared.loadEntriesFromDisk()
        var merged = local
        if let cloud, !cloud.isEmpty {
            for entry in cloud where !local.contains(where: { $0.id == entry.id }) {
                merged.append(entry)
            }
            CalendarEntryStore.shared.replaceAll(merged)
            NotificationCenter.default.post(name: .calendarEntriesRestored, object: nil)
            CalendarReminderScheduler.shared.reschedule(for: merged)
            SyncLog.success("Restored \(cloud.count) calendar entr(ies)")
            let missing = recordsMissingFromCloud(local: merged, cloud: cloud)
            guard !missing.isEmpty else { return }
            SyncLog.info("Backing up \(missing.count) calendar entr(ies) missing from Firebase")
            enqueueCalendarUpload(cloud + missing)
            return
        }

        guard !merged.isEmpty else { return }
        SyncLog.info("Backing up \(merged.count) calendar entr(ies) that were never saved to Firebase")
        enqueueCalendarUpload(merged)
    }

    // MARK: - iCloud backup

    /// Pulls the private iCloud copy onto this device. Runs even when Firebase
    /// cannot be reached, so a reinstall can recover files Firebase never stored.
    func restoreFromICloudBackup(uid: String) async {
        let snapshot = await CloudKitBackupService.shared.restoreSnapshot(uid: uid)

        if snapshot.documentsReadable {
            let added = mergeRestoredDocuments(snapshot.documents)
            if added > 0 {
                SyncLog.success("Restored \(added) document(s) from iCloud")
            }
        }
        if snapshot.growthPhotosRestored > 0 {
            SyncLog.success("Restored \(snapshot.growthPhotosRestored) growth photo(s) from iCloud")
        }
        if snapshot.avatarsRestored > 0 {
            SyncLog.success("Restored \(snapshot.avatarsRestored) account photo(s) from iCloud")
        }

        if let profiles = snapshot.profiles, !profiles.isEmpty {
            let (merged, _) = mergedHealthProfiles(cloud: profiles, local: localHealthProfiles())
            if let data = try? JSONEncoder().encode(merged) {
                UserDefaults.standard.set(data, forKey: "health_profiles_by_space")
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
                SyncLog.success("Restored health profile from iCloud")
            }
        }

        if let prefs = snapshot.preferences {
            let location = UserDefaults.standard.string(forKey: "user_location") ?? ""
            var areas: [String] = []
            if let areasData = UserDefaults.standard.data(forKey: "onboarding_medical_areas"),
               let decoded = try? JSONDecoder().decode([String].self, from: areasData) {
                areas = decoded
            }
            if location.isEmpty && areas.isEmpty && (!prefs.location.isEmpty || !prefs.medicalAreas.isEmpty) {
                UserDefaults.standard.set(prefs.location, forKey: "user_location")
                if let areasData = try? JSONEncoder().encode(prefs.medicalAreas) {
                    UserDefaults.standard.set(areasData, forKey: "onboarding_medical_areas")
                }
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
                SyncLog.success("Restored preferences from iCloud")
            }
        }

        if let folders = snapshot.folders, !folders.isEmpty {
            let before = CustomFolderStore.shared.folders.count
            CustomFolderStore.shared.merge(folders)
            if CustomFolderStore.shared.folders.count != before {
                SyncLog.success("Restored custom folders from iCloud")
            }
        }

        if let spaces = snapshot.spaces, !spaces.isEmpty {
            ActiveSpaceManager.shared.mergeBackup(spaces)
            SyncLog.success("Restored \(spaces.count) account(s) from iCloud")
        }

        if let entries = snapshot.calendar, !entries.isEmpty {
            let before = CalendarEntryStore.shared.loadEntriesFromDisk().count
            _ = mergeCalendar(entries)
            if CalendarEntryStore.shared.loadEntriesFromDisk().count != before {
                SyncLog.success("Restored calendar from iCloud")
            }
        }
    }

    /// Copies anything still only on this phone into iCloud. Safe to run when
    /// Firebase is down: it adds missing records and does not erase the backup.
    func mirrorLocalDataToICloud(uid: String) async {
        await CloudKitBackupService.shared.backupDocumentsIfMissing(
            DocumentFileManager.shared.loadMetadata(),
            uid: uid
        )
        await CloudKitBackupService.shared.backupGrowthPhotosIfMissing(
            GrowthPhotoStore.shared.localEntryIDs(),
            uid: uid
        )
        await CloudKitBackupService.shared.backupAvatars(
            AccountAvatarStore.shared.localSpaceIDs(),
            uid: uid,
            force: false
        )

        let profiles = localHealthProfiles()
        if !profiles.isEmpty {
            await CloudKitBackupService.shared.backupHealthProfiles(profiles, uid: uid)
        }

        let location = UserDefaults.standard.string(forKey: "user_location") ?? ""
        var areas: [String] = []
        if let areasData = UserDefaults.standard.data(forKey: "onboarding_medical_areas"),
           let decoded = try? JSONDecoder().decode([String].self, from: areasData) {
            areas = decoded
        }
        if !location.isEmpty || !areas.isEmpty {
            await CloudKitBackupService.shared.backupPreferences(
                UserPreferences(medicalAreas: areas, location: location),
                uid: uid,
                force: false
            )
        }

        await CloudKitBackupService.shared.backupFolders(CustomFolderStore.shared.folders, uid: uid, force: false)
        await CloudKitBackupService.shared.backupSpaces(ActiveSpaceManager.shared.spaces, uid: uid, force: false)
        await CloudKitBackupService.shared.backupCalendar(
            CalendarEntryStore.shared.loadEntriesFromDisk(),
            uid: uid,
            force: false
        )
    }

    private func mirrorDocumentToICloud(_ document: Document) {
        guard let uid else { return }
        Task { await CloudKitBackupService.shared.backupDocument(document, uid: uid) }
    }

    @discardableResult
    private func mergeRestoredDocuments(_ restored: [Document]) -> Int {
        guard !restored.isEmpty else { return 0 }
        let existing = DocumentFileManager.shared.loadMetadata()
        var merged = existing
        for doc in restored where !existing.contains(where: { $0.id == doc.id }) {
            merged.append(doc)
        }
        let added = merged.count - existing.count
        guard added > 0 else { return 0 }
        try? DocumentFileManager.shared.saveMetadata(merged)
        NotificationCenter.default.post(name: .documentsRestored, object: nil)
        return added
    }

    @discardableResult
    private func mergeCalendar(_ incoming: [CalendarEntry]) -> [CalendarEntry] {
        let local = CalendarEntryStore.shared.loadEntriesFromDisk()
        guard !incoming.isEmpty else { return local }
        var merged = local
        for entry in incoming where !local.contains(where: { $0.id == entry.id }) {
            merged.append(entry)
        }
        guard merged.count != local.count else { return local }
        CalendarEntryStore.shared.replaceAll(merged)
        NotificationCenter.default.post(name: .calendarEntriesRestored, object: nil)
        CalendarReminderScheduler.shared.reschedule(for: merged)
        return merged
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

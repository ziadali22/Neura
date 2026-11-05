import Foundation
import CloudKit

/// What an iCloud restore was able to read. `nil` blobs mean that record was
/// missing or unreadable — callers must not treat that as "the user has no data".
struct ICloudBackupSnapshot {
    var documents: [Document] = []
    var documentsReadable: Bool = false
    var growthPhotosRestored: Int = 0
    var avatarsRestored: Int = 0
    var profiles: [UUID: HealthProfile]?
    var preferences: UserPreferences?
    var calendar: [CalendarEntry]?
    var folders: [CustomFolder]?
    var spaces: [Space]?
}

/// Second copy of the user's data in their private iCloud database.
///
/// Firebase stays the primary sync path. This store exists so a Firebase
/// outage, or a reinstall while Firebase is empty, can still bring the files
/// back. Records live in a zone named for the Firebase user, so two accounts
/// on one Apple ID do not share a backup.
///
/// The backup never deletes an iCloud record just because this phone's list
/// is shorter. A fresh install must not wipe the copy it is about to restore.
@MainActor
final class CloudKitBackupService {
    static let shared = CloudKitBackupService()

    private let container = CKContainer(identifier: "iCloud.com.Neura.health")
    private var database: CKDatabase { container.privateCloudDatabase }

    private var activeZoneID: CKRecordZone.ID?
    private var manifestCache: Manifest?
    private var manifestZoneID: CKRecordZone.ID?
    private var didLogUnavailable = false

    private struct Manifest {
        var documentIDs: Set<String> = []
        var growthPhotoIDs: Set<String> = []
        var avatarIDs: Set<String> = []
    }

    private enum RecordType {
        static let manifest = "NeuraBackupManifest"
        static let document = "NeuraBackupDocument"
        static let growth = "NeuraBackupGrowthPhoto"
        static let avatar = "NeuraBackupAvatar"
        static let blob = "NeuraBackupBlob"
    }

    private init() {}

    // MARK: - Restore

    func restoreSnapshot(uid: String) async -> ICloudBackupSnapshot {
        var snapshot = ICloudBackupSnapshot()
        guard await prepare(uid: uid) else { return snapshot }

        do {
            let manifest = try await currentManifest()
            snapshot.documentsReadable = true
            snapshot.documents = try await restoreDocuments(ids: manifest.documentIDs)
            snapshot.growthPhotosRestored = try await restoreAssetFiles(
                ids: manifest.growthPhotoIDs,
                namePrefix: "growth-",
                fileExists: { GrowthPhotoStore.shared.fileExists(for: $0) },
                destination: { GrowthPhotoStore.shared.resolveURL(for: GrowthPhotoStore.shared.filename(for: $0)) }
            )
            snapshot.avatarsRestored = try await restoreAssetFiles(
                ids: manifest.avatarIDs,
                namePrefix: "avatar-",
                fileExists: {
                    FileManager.default.fileExists(
                        atPath: AccountAvatarStore.shared.resolveURL(for: "\($0.uuidString).jpg").path
                    )
                },
                destination: { AccountAvatarStore.shared.resolveURL(for: "\($0.uuidString).jpg") }
            )
        } catch {
            SyncLog.failure("iCloud file restore failed", error: error)
        }

        snapshot.profiles = await blob([UUID: HealthProfile].self, name: "profile")
        snapshot.preferences = await blob(UserPreferences.self, name: "preferences")
        snapshot.calendar = await blob([CalendarEntry].self, name: "calendar")
        snapshot.folders = await blob([CustomFolder].self, name: "folders")
        snapshot.spaces = await blob([Space].self, name: "spaces")
        return snapshot
    }

    // MARK: - Documents

    func backupDocument(_ document: Document, uid: String) async {
        guard document.fileExists else { return }
        guard await prepare(uid: uid) else { return }
        let modifiedAt = modificationDate(of: document.fileURL)
        do {
            var manifest = try await currentManifest()
            let id = document.id.uuidString
            if await documentBackupIsCurrent(document, id: id, modifiedAt: modifiedAt, knownIDs: manifest.documentIDs) {
                return
            }
            try await saveDocumentRecord(document, modifiedAt: modifiedAt)
            guard !manifest.documentIDs.contains(id) else { return }
            manifest.documentIDs.insert(id)
            try await saveManifest(manifest)
        } catch {
            SyncLog.failure("iCloud document backup failed \(document.id)", error: error)
        }
    }

    func backupDocumentsIfMissing(_ documents: [Document], uid: String) async {
        guard await prepare(uid: uid) else { return }
        do {
            var manifest = try await currentManifest()
            var added = 0
            for document in documents where document.fileExists && !manifest.documentIDs.contains(document.id.uuidString) {
                do {
                    try await saveDocumentRecord(document, modifiedAt: modificationDate(of: document.fileURL))
                    manifest.documentIDs.insert(document.id.uuidString)
                    added += 1
                } catch {
                    SyncLog.failure("iCloud document backup failed \(document.id)", error: error)
                }
            }
            guard added > 0 else { return }
            try await saveManifest(manifest)
            SyncLog.success("iCloud backed up \(added) document(s)")
        } catch {
            SyncLog.failure("iCloud document backup failed", error: error)
        }
    }

    func deleteDocument(_ id: UUID, uid: String) async {
        guard await prepare(uid: uid) else { return }
        await deleteRecord(named: "doc-\(id.uuidString)")
        do {
            var manifest = try await currentManifest()
            manifest.documentIDs.remove(id.uuidString)
            try await saveManifest(manifest)
        } catch {
            SyncLog.failure("iCloud manifest update after document delete failed", error: error)
        }
    }

    // MARK: - Growth photos and avatars

    func backupGrowthPhoto(_ entryID: UUID, uid: String) async {
        await backupAsset(
            id: entryID,
            uid: uid,
            namePrefix: "growth-",
            recordType: RecordType.growth,
            fileURL: GrowthPhotoStore.shared.resolveURL(for: GrowthPhotoStore.shared.filename(for: entryID)),
            manifestIDs: \.growthPhotoIDs,
            force: true
        )
    }

    func backupGrowthPhotosIfMissing(_ entryIDs: [UUID], uid: String) async {
        for entryID in entryIDs {
            await backupAsset(
                id: entryID,
                uid: uid,
                namePrefix: "growth-",
                recordType: RecordType.growth,
                fileURL: GrowthPhotoStore.shared.resolveURL(for: GrowthPhotoStore.shared.filename(for: entryID)),
                manifestIDs: \.growthPhotoIDs,
                force: false
            )
        }
    }

    func deleteGrowthPhoto(_ entryID: UUID, uid: String) async {
        guard await prepare(uid: uid) else { return }
        await deleteRecord(named: "growth-\(entryID.uuidString)")
        do {
            var manifest = try await currentManifest()
            manifest.growthPhotoIDs.remove(entryID.uuidString)
            try await saveManifest(manifest)
        } catch {
            SyncLog.failure("iCloud manifest update after growth photo delete failed", error: error)
        }
    }

    func backupAvatars(_ spaceIDs: [UUID], uid: String, force: Bool) async {
        for spaceID in spaceIDs {
            await backupAsset(
                id: spaceID,
                uid: uid,
                namePrefix: "avatar-",
                recordType: RecordType.avatar,
                fileURL: AccountAvatarStore.shared.resolveURL(for: "\(spaceID.uuidString).jpg"),
                manifestIDs: \.avatarIDs,
                force: force
            )
        }
    }

    // MARK: - Structured data

    func backupHealthProfiles(_ local: [UUID: HealthProfile], uid: String) async {
        guard !local.isEmpty else { return }
        guard await prepare(uid: uid) else { return }
        let existing: [UUID: HealthProfile]
        do {
            existing = try await loadBlob("profile") ?? [:]
        } catch {
            SyncLog.failure("iCloud profile backup skipped", error: error)
            return
        }
        var merged = existing
        var changed = false
        for (id, profile) in local {
            if let current = merged[id] {
                if profile.lastUpdated > current.lastUpdated {
                    merged[id] = profile
                    changed = true
                }
            } else {
                merged[id] = profile
                changed = true
            }
        }
        guard changed else { return }
        do {
            try await saveBlob("profile", value: merged)
            SyncLog.success("iCloud backed up health profile")
        } catch {
            SyncLog.failure("iCloud profile backup failed", error: error)
        }
    }

    func backupPreferences(_ prefs: UserPreferences, uid: String, force: Bool) async {
        guard !prefs.location.isEmpty || !prefs.medicalAreas.isEmpty else { return }
        guard await prepare(uid: uid) else { return }
        if !force {
            do {
                if try await loadBlob("preferences", as: UserPreferences.self) != nil { return }
            } catch {
                SyncLog.failure("iCloud preferences backup skipped", error: error)
                return
            }
        }
        do {
            try await saveBlob("preferences", value: prefs)
            SyncLog.success("iCloud backed up preferences")
        } catch {
            SyncLog.failure("iCloud preferences backup failed", error: error)
        }
    }

    func backupCalendar(_ local: [CalendarEntry], uid: String, force: Bool) async {
        await backupList(local, name: "calendar", uid: uid, force: force)
    }

    func backupFolders(_ local: [CustomFolder], uid: String, force: Bool) async {
        await backupList(local, name: "folders", uid: uid, force: force)
    }

    func backupSpaces(_ local: [Space], uid: String, force: Bool) async {
        await backupList(local, name: "spaces", uid: uid, force: force)
    }

    // MARK: - Account and zone

    private func prepare(uid: String) async -> Bool {
        guard await isAvailable() else { return false }
        return await ensureZone(for: uid) != nil
    }

    private func isAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                logUnavailable(accountStatusDescription(status))
                return false
            }
            return true
        } catch {
            if !didLogUnavailable {
                didLogUnavailable = true
                SyncLog.failure("iCloud account check failed", error: error)
            }
            return false
        }
    }

    private func logUnavailable(_ reason: String) {
        guard !didLogUnavailable else { return }
        didLogUnavailable = true
        SyncLog.info("iCloud backup unavailable (\(reason))")
    }

    private func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "available"
        case .noAccount: return "no iCloud account"
        case .restricted: return "restricted"
        case .couldNotDetermine: return "could not determine"
        case .temporarilyUnavailable: return "temporarily unavailable"
        @unknown default: return "unknown"
        }
    }

    private func zoneName(for uid: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let cleaned = String(uid.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return "neura_\(cleaned)"
    }

    private func ensureZone(for uid: String) async -> CKRecordZone.ID? {
        let zoneID = CKRecordZone.ID(zoneName: zoneName(for: uid))
        if activeZoneID == zoneID { return zoneID }
        do {
            _ = try await database.recordZone(for: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            do {
                _ = try await database.save(CKRecordZone(zoneID: zoneID))
            } catch {
                SyncLog.failure("Could not create iCloud backup zone", error: error)
                return nil
            }
        } catch {
            SyncLog.failure("Could not open iCloud backup zone", error: error)
            return nil
        }
        if activeZoneID != zoneID {
            manifestCache = nil
            manifestZoneID = nil
        }
        activeZoneID = zoneID
        return zoneID
    }

    private func recordID(_ name: String) -> CKRecord.ID {
        guard let activeZoneID else {
            preconditionFailure("iCloud backup zone used before it was opened")
        }
        return CKRecord.ID(recordName: name, zoneID: activeZoneID)
    }

    // MARK: - Manifest

    private func currentManifest() async throws -> Manifest {
        if manifestZoneID == activeZoneID, let manifestCache { return manifestCache }
        let loaded = try await fetchManifest()
        manifestCache = loaded
        manifestZoneID = activeZoneID
        return loaded
    }

    private func fetchManifest() async throws -> Manifest {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID("manifest"))
        } catch {
            if isUnknownItem(error) { return Manifest() }
            throw error
        }
        return Manifest(
            documentIDs: Set(record["documentIDs"] as? [String] ?? []),
            growthPhotoIDs: Set(record["growthPhotoIDs"] as? [String] ?? []),
            avatarIDs: Set(record["avatarIDs"] as? [String] ?? [])
        )
    }

    private func saveManifest(_ manifest: Manifest) async throws {
        let record = CKRecord(recordType: RecordType.manifest, recordID: recordID("manifest"))
        record.setObject(Array(manifest.documentIDs) as NSArray, forKey: "documentIDs")
        record.setObject(Array(manifest.growthPhotoIDs) as NSArray, forKey: "growthPhotoIDs")
        record.setObject(Array(manifest.avatarIDs) as NSArray, forKey: "avatarIDs")
        record.setObject(Date() as NSDate, forKey: "updatedAt")
        try await save(record)
        manifestCache = manifest
        manifestZoneID = activeZoneID
    }

    // MARK: - Records

    private func saveDocumentRecord(_ document: Document, modifiedAt: Date) async throws {
        let record = CKRecord(recordType: RecordType.document, recordID: recordID("doc-\(document.id.uuidString)"))
        record.setObject(try JSONEncoder().encode(document) as NSData, forKey: "metadata")
        record.setObject(CKAsset(fileURL: document.fileURL), forKey: "file")
        record.setObject(modifiedAt as NSDate, forKey: "fileModifiedAt")
        record.setObject(Date() as NSDate, forKey: "updatedAt")
        try await save(record)
    }

    private func documentBackupIsCurrent(_ document: Document, id: String, modifiedAt: Date, knownIDs: Set<String>) async -> Bool {
        guard knownIDs.contains(id),
              let existing = try? await database.record(for: recordID("doc-\(id)")),
              let saved = existing["fileModifiedAt"] as? Date,
              saved >= modifiedAt,
              let savedMeta = existing["metadata"] as? Data,
              savedMeta == (try? JSONEncoder().encode(document)) else { return false }
        return true
    }

    private func cloudCopyIsCurrent(recordName: String, modifiedAt: Date, knownIDs: Set<String>, id: String) async -> Bool {
        guard knownIDs.contains(id),
              let existing = try? await database.record(for: recordID(recordName)),
              let saved = existing["fileModifiedAt"] as? Date else { return false }
        return saved >= modifiedAt
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
    }

    private func restoreDocuments(ids: Set<String>) async throws -> [Document] {
        let records = try await fetchRecords(ids.map { recordID("doc-\($0)") })
        var restored: [Document] = []
        for record in records {
            guard let metadata = record["metadata"] as? Data,
                  let document = try? JSONDecoder().decode(Document.self, from: metadata) else { continue }
            let destination = DocumentFileManager.shared.resolveURL(for: document.filename)
            if !FileManager.default.fileExists(atPath: destination.path) {
                guard let source = (record["file"] as? CKAsset)?.fileURL else { continue }
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                } catch {
                    SyncLog.failure("iCloud document copy failed \(document.id)", error: error)
                    continue
                }
            }
            restored.append(document)
        }
        return restored
    }

    private func backupAsset(
        id: UUID,
        uid: String,
        namePrefix: String,
        recordType: String,
        fileURL: URL,
        manifestIDs: WritableKeyPath<Manifest, Set<String>>,
        force: Bool
    ) async {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard await prepare(uid: uid) else { return }
        let modifiedAt = modificationDate(of: fileURL)
        do {
            var manifest = try await currentManifest()
            let idString = id.uuidString
            var ids = manifest[keyPath: manifestIDs]
            if !force && ids.contains(idString) { return }
            if await cloudCopyIsCurrent(recordName: "\(namePrefix)\(idString)", modifiedAt: modifiedAt, knownIDs: ids, id: idString) {
                return
            }
            let record = CKRecord(recordType: recordType, recordID: recordID("\(namePrefix)\(idString)"))
            record.setObject(CKAsset(fileURL: fileURL), forKey: "file")
            record.setObject(modifiedAt as NSDate, forKey: "fileModifiedAt")
            record.setObject(Date() as NSDate, forKey: "updatedAt")
            try await save(record)
            if !ids.contains(idString) {
                ids.insert(idString)
                manifest[keyPath: manifestIDs] = ids
                try await saveManifest(manifest)
            }
        } catch {
            SyncLog.failure("iCloud file backup failed \(namePrefix)\(id.uuidString)", error: error)
        }
    }

    private func restoreAssetFiles(
        ids: Set<String>,
        namePrefix: String,
        fileExists: @MainActor (UUID) -> Bool,
        destination: @MainActor (UUID) -> URL
    ) async throws -> Int {
        let missing = ids.compactMap { UUID(uuidString: $0) }.filter { !fileExists($0) }
        guard !missing.isEmpty else { return 0 }
        let records = try await fetchRecords(missing.map { recordID("\(namePrefix)\($0.uuidString)") })
        var restored = 0
        for record in records {
            let raw = record.recordID.recordName.replacingOccurrences(of: namePrefix, with: "")
            guard let id = UUID(uuidString: raw),
                  let source = (record["file"] as? CKAsset)?.fileURL else { continue }
            let dest = destination(id)
            if FileManager.default.fileExists(atPath: dest.path) { continue }
            do {
                try FileManager.default.copyItem(at: source, to: dest)
                restored += 1
            } catch {
                SyncLog.failure("iCloud file copy failed \(record.recordID.recordName)", error: error)
            }
        }
        return restored
    }

    private func backupList<T: Identifiable & Codable>(
        _ local: [T],
        name: String,
        uid: String,
        force: Bool
    ) async where T.ID: Hashable {
        guard await prepare(uid: uid) else { return }
        let existing: [T]
        do {
            existing = try await loadBlob(name) ?? []
        } catch {
            SyncLog.failure("iCloud \(name) backup skipped", error: error)
            return
        }

        if !force {
            let existingIDs = Set(existing.map(\.id))
            let missing = local.filter { !existingIDs.contains($0.id) }
            guard !missing.isEmpty else { return }
            do {
                try await saveBlob(name, value: existing + missing)
                SyncLog.success("iCloud backed up \(missing.count) \(name) record(s)")
            } catch {
                SyncLog.failure("iCloud \(name) backup failed", error: error)
            }
            return
        }

        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        for item in local {
            byID[item.id] = item
        }
        let merged = Array(byID.values)
        guard !merged.isEmpty else { return }
        do {
            try await saveBlob(name, value: merged)
        } catch {
            SyncLog.failure("iCloud \(name) backup failed", error: error)
        }
    }

    private func blob<T: Decodable>(_ type: T.Type, name: String) async -> T? {
        do {
            return try await loadBlob(name, as: type)
        } catch {
            SyncLog.failure("iCloud \(name) restore failed", error: error)
            return nil
        }
    }

    private func loadBlob<T: Decodable>(_ name: String, as type: T.Type = T.self) async throws -> T? {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID(name))
        } catch {
            if isUnknownItem(error) { return nil }
            throw error
        }
        guard let source = (record["payload"] as? CKAsset)?.fileURL else { return nil }
        let data = try Data(contentsOf: source)
        return try JSONDecoder().decode(type, from: data)
    }

    private func saveBlob<T: Encodable>(_ name: String, value: T) async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("neura-backup-\(name)-\(UUID().uuidString).json")
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        let record = CKRecord(recordType: RecordType.blob, recordID: recordID(name))
        record.setObject(CKAsset(fileURL: url), forKey: "payload")
        record.setObject(Date() as NSDate, forKey: "updatedAt")
        try await save(record)
    }

    private func save(_ record: CKRecord) async throws {
        let outcome = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )
        if case .failure(let error) = outcome.saveResults[record.recordID] {
            throw error
        }
    }

    private func deleteRecord(named name: String) async {
        let id = recordID(name)
        do {
            let outcome = try await database.modifyRecords(
                saving: [],
                deleting: [id],
                savePolicy: .allKeys,
                atomically: true
            )
            if case .failure(let error) = outcome.deleteResults[id], !isUnknownItem(error) {
                SyncLog.failure("iCloud delete failed \(name)", error: error)
            }
        } catch {
            if !isUnknownItem(error) {
                SyncLog.failure("iCloud delete failed \(name)", error: error)
            }
        }
    }

    private func fetchRecords(_ ids: [CKRecord.ID]) async throws -> [CKRecord] {
        guard !ids.isEmpty else { return [] }
        var records: [CKRecord] = []
        var index = 0
        while index < ids.count {
            let end = min(index + 200, ids.count)
            let chunk = Array(ids[index..<end])
            let results = try await database.records(for: chunk)
            for id in chunk {
                if case .success(let record) = results[id] {
                    records.append(record)
                }
            }
            index = end
        }
        return records
    }

    private func isUnknownItem(_ error: Error) -> Bool {
        (error as? CKError)?.code == .unknownItem
    }
}

# Google-Drive-Style Cloud Sync Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make login-with-Apple/Google return all of a user's profile, preferences, and document files on any device after reinstall, with no data loss.

**Architecture:** Firebase security rules unlock per-user writes. The AES key becomes account-recoverable (stored at `users/{uid}/keys/master` in Firestore, cached in iCloud Keychain). A durable on-disk queue retries any upload that fails or is interrupted, draining on launch, sign-in, foreground, and network regain. All sync paths log via `SyncLog`.

**Tech Stack:** SwiftUI, Firebase Firestore + Storage, CryptoKit (AES-GCM), Network (NWPathMonitor), os.Logger.

**Note on testing:** This project has no test target (per CLAUDE.md). Each task is verified by a clean build (`xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17'`) plus the manual verification noted where behavior matters. Do not add a test target.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `firestore.rules` | Per-user Firestore access (repo copy; user pastes into Console) |
| Create | `storage.rules` | Per-user Storage access (repo copy; user pastes into Console) |
| Create | `Neura/Core/Services/Sync/SyncLog.swift` | os.Logger wrapper for the sync subsystem |
| Create | `Neura/Core/Services/Sync/NetworkMonitor.swift` | Publishes connectivity via NWPathMonitor |
| Create | `Neura/Core/Services/Sync/EncryptionKeyService.swift` | Canonical account key: resolve / migrate / create |
| Create | `Neura/Core/Services/Sync/PendingSyncStore.swift` | Durable on-disk queue of un-synced operations |
| Modify | `Neura/Core/Services/Encryption/KeychainManager.swift` | Add public `store(_:for:)` |
| Modify | `Neura/Core/Services/Sync/SyncQueueManager.swift` | Durable queue, logging, drain, network observation |
| Modify | `Neura/Core/Services/Auth/AuthService.swift` | Use EncryptionKeyService; drain after key resolves |
| Modify | `Neura/Features/Dashboard/Views/DashboardView.swift` | Drain queue on `scenePhase == .active` |
| Modify | `Neura/Core/Services/Sync/DocumentSyncService.swift` | Add SyncLog calls |
| Modify | `Neura/Core/Services/Sync/HealthProfileSyncService.swift` | Add SyncLog calls |
| Modify | `Neura/Core/Services/Sync/PreferencesSyncService.swift` | Add SyncLog calls |

Build command used throughout:
```bash
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD" | grep -v CardVideo
```
Expected: `** BUILD SUCCEEDED **`. (The `CardVideo.mp4` resource warning is pre-existing and unrelated.)

---

## Task 1: Security rules files

**Files:**
- Create: `firestore.rules`
- Create: `storage.rules`

- [ ] **Step 1: Create `firestore.rules`**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Each user can read/write only their own subtree.
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

- [ ] **Step 2: Create `storage.rules`**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Each user can read/write only their own files.
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add firestore.rules storage.rules
git commit -m "feat: add Firebase Firestore and Storage security rules"
```

- [ ] **Step 4: Hand the rules to the user for deployment**

These are deployed manually (not by the build). Tell the user:
1. Firebase Console → project `neura-42024` → **Storage** → enable it if not already (Get Started).
2. **Firestore Database → Rules** → paste `firestore.rules` → **Publish**.
3. **Storage → Rules** → paste `storage.rules` → **Publish**.

---

## Task 2: Sync infrastructure — SyncLog + NetworkMonitor

**Files:**
- Create: `Neura/Core/Services/Sync/SyncLog.swift`
- Create: `Neura/Core/Services/Sync/NetworkMonitor.swift`

- [ ] **Step 1: Create `SyncLog.swift`**

```swift
import Foundation
import os

/// Centralized logging for the cloud sync subsystem.
/// View in Console.app / Xcode by filtering subsystem "com.neura.sync".
enum SyncLog {
    private static let logger = Logger(subsystem: "com.neura.sync", category: "sync")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func success(_ message: String) {
        logger.info("✅ \(message, privacy: .public)")
    }

    static func failure(_ message: String, error: Error) {
        logger.error("❌ \(message, privacy: .public) — \(error.localizedDescription, privacy: .public)")
    }
}
```

- [ ] **Step 2: Create `NetworkMonitor.swift`**

```swift
import Foundation
import Network
import Combine

/// Publishes network connectivity so the sync layer can drain its queue when the network returns.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.neura.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}
```

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/Sync/SyncLog.swift Neura/Core/Services/Sync/NetworkMonitor.swift
git commit -m "feat: add SyncLog and NetworkMonitor sync infrastructure"
```

---

## Task 3: Account-recoverable key — KeychainManager.store + EncryptionKeyService

**Files:**
- Modify: `Neura/Core/Services/Encryption/KeychainManager.swift`
- Create: `Neura/Core/Services/Sync/EncryptionKeyService.swift`

- [ ] **Step 1: Add a public `store(_:for:)` to `KeychainManager`**

In `KeychainManager.swift`, immediately after the `clearKey()` method, add:

```swift
    /// Persists a key to the (synchronizable) Keychain and the in-memory cache,
    /// overwriting any existing entry. Used to cache a key downloaded from Firestore.
    func store(_ key: SymmetricKey, for uid: String) {
        saveKey(key, for: uid)
        cachedKey = key
    }
```

(`saveKey` and `cachedKey` already exist as private members; this exposes a safe public path.)

- [ ] **Step 2: Create `EncryptionKeyService.swift`**

```swift
import Foundation
import FirebaseFirestore
import CryptoKit

/// Owns the canonical AES key stored at users/{uid}/keys/master in Firestore.
/// Firestore is the source of truth; the iCloud Keychain is an offline cache.
@MainActor
final class EncryptionKeyService {
    static let shared = EncryptionKeyService()
    private init() {}

    /// Resolves the account's encryption key.
    ///
    /// Order: Firestore (source of truth) → migrate a local Keychain key → create new.
    /// Returns `nil` only when offline with no cached key — callers must then defer
    /// sync rather than risk creating a divergent key.
    func resolveKey(uid: String) async -> SymmetricKey? {
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("keys").document("master")

        do {
            let snapshot = try await ref.getDocument()

            // 1. Firestore has the canonical key — use it, refresh the local cache.
            if let b64 = snapshot.data()?["key"] as? String,
               let raw = Data(base64Encoded: b64) {
                let key = SymmetricKey(data: raw)
                KeychainManager.shared.store(key, for: uid)
                SyncLog.success("Key resolved from Firestore")
                return key
            }

            // 2. No cloud key yet — migrate an existing local key if present.
            if let local = KeychainManager.shared.tryLoadKey(for: uid) {
                try await upload(local, to: ref)
                SyncLog.success("Migrated local key to Firestore")
                return local
            }

            // 3. Genuinely new user — create, upload, cache.
            let fresh = SymmetricKey(size: .bits256)
            try await upload(fresh, to: ref)
            KeychainManager.shared.store(fresh, for: uid)
            SyncLog.success("Created new account key")
            return fresh
        } catch {
            // 4. Offline / fetch failed — fall back to cache; never mint a key blind.
            SyncLog.failure("Key fetch failed; using cached key if any", error: error)
            return KeychainManager.shared.tryLoadKey(for: uid)
        }
    }

    private func upload(_ key: SymmetricKey, to ref: DocumentReference) async throws {
        let raw = key.withUnsafeBytes { Data($0) }
        try await ref.setData([
            "key": raw.base64EncodedString(),
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
```

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/Encryption/KeychainManager.swift Neura/Core/Services/Sync/EncryptionKeyService.swift
git commit -m "feat: account-recoverable encryption key via Firestore"
```

---

## Task 4: Durable queue — PendingSyncStore

**Files:**
- Create: `Neura/Core/Services/Sync/PendingSyncStore.swift`

- [ ] **Step 1: Create `PendingSyncStore.swift`**

```swift
import Foundation

/// A single un-synced operation, durably recorded so it survives app termination.
struct PendingSyncOp: Codable, Hashable {
    enum Kind: String, Codable {
        case documentUpload
        case documentMetadata
        case documentDelete
        case profileUpload
        case preferencesUpload
    }
    let kind: Kind
    /// Document UUID string for document ops; nil for profile/preferences (single-doc).
    let id: String?
}

/// Persists pending sync operations to Application Support so failed or interrupted
/// uploads are retried on the next drain.
@MainActor
final class PendingSyncStore {
    static let shared = PendingSyncStore()

    private let fileURL: URL
    private var ops: Set<PendingSyncOp>

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("pending_sync.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Set<PendingSyncOp>.self, from: data) {
            ops = decoded
        } else {
            ops = []
        }
    }

    var all: [PendingSyncOp] { Array(ops) }

    func add(_ op: PendingSyncOp) {
        // A delete supersedes a pending upload/metadata for the same document.
        if op.kind == .documentDelete, let id = op.id {
            ops = ops.filter {
                !($0.id == id && ($0.kind == .documentUpload || $0.kind == .documentMetadata))
            }
        }
        ops.insert(op)
        persist()
    }

    func remove(_ op: PendingSyncOp) {
        ops.remove(op)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(ops) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/Services/Sync/PendingSyncStore.swift
git commit -m "feat: add durable PendingSyncStore for un-synced operations"
```

---

## Task 5: Rewire SyncQueueManager — durable, logged, network-aware

**Files:**
- Modify: `Neura/Core/Services/Sync/SyncQueueManager.swift`

This replaces the fire-and-forget body. Each enqueue records a `PendingSyncOp`, then attempts the network call; success removes the op, failure logs and leaves it for a later drain. A `drainPending()` retries everything; it is called on network regain (observed here) and by other triggers (Tasks 6 & 7). Public method **signatures are unchanged**, so existing callers keep working.

- [ ] **Step 1: Replace the entire contents of `SyncQueueManager.swift`**

```swift
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
                attemptPreferencesUpload(UserPreferences(medicalAreas: areas, location: location))
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
```

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/Services/Sync/SyncQueueManager.swift
git commit -m "feat: durable, logged, network-aware sync queue"
```

---

## Task 6: Rewire AuthService — server key resolution + drain

**Files:**
- Modify: `Neura/Core/Services/Auth/AuthService.swift`

Replace the racy `resolveKey` (added earlier) with a call into `EncryptionKeyService`, and drain the pending queue once the key is available.

- [ ] **Step 1: Replace the `restoreCloudData` and `resolveKey` methods**

In `AuthService.swift`, replace everything from `private func restoreCloudData(for uid: String) {` through the end of the `resolveKey(for:)` method with:

```swift
    private func restoreCloudData(for uid: String) {
        Task {
            guard let key = await EncryptionKeyService.shared.resolveKey(uid: uid) else {
                SyncLog.info("Key unavailable (offline); deferring restore and sync")
                return
            }
            // Key is now cached in KeychainManager. Pull cloud data down, then push
            // anything that failed to upload previously.
            SyncQueueManager.shared.performInitialRestore(uid: uid, key: key)
            SyncQueueManager.shared.drainPending()
        }
    }
```

The `import CryptoKit` line added previously stays (no longer strictly required here, but harmless). The `loadOrCreateKey`-based logic and the 15-second retry loop are fully removed.

- [ ] **Step 2: Confirm no other references to the removed `resolveKey`**

Run:
```bash
grep -n "resolveKey\|loadOrCreateKey" Neura/Core/Services/Auth/AuthService.swift
```
Expected: no matches (the only key resolution now lives in `EncryptionKeyService`).

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/Auth/AuthService.swift
git commit -m "feat: AuthService uses account-recoverable key and drains queue"
```

---

## Task 7: Drain triggers + sync-service logging

**Files:**
- Modify: `Neura/Features/Dashboard/Views/DashboardView.swift`
- Modify: `Neura/Core/Services/Sync/DocumentSyncService.swift`
- Modify: `Neura/Core/Services/Sync/HealthProfileSyncService.swift`
- Modify: `Neura/Core/Services/Sync/PreferencesSyncService.swift`

- [ ] **Step 1: Drain on foreground in `DashboardView`**

In `DashboardView.swift`, find the existing `.task(id: scenePhase)` block:

```swift
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await requestTrackingAfterSettling()
        }
```

Replace it with:

```swift
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            SyncQueueManager.shared.drainPending()
            await requestTrackingAfterSettling()
        }
```

- [ ] **Step 2: Add logging to `DocumentSyncService.downloadAll`**

In `DocumentSyncService.swift`, at the very start of `downloadAll(uid:key:)` (right after the function opening brace, before the `let snapshot` line), add:

```swift
        SyncLog.info("Downloading all documents for restore")
```

And immediately before `return restored` at the end of the function, add:

```swift
        SyncLog.success("downloadAll fetched \(restored.count) document(s)")
```

- [ ] **Step 3: Add logging to `HealthProfileSyncService`**

In `HealthProfileSyncService.swift`, at the start of `download(uid:key:)` (after the opening brace), add:

```swift
        SyncLog.info("Downloading health profile")
```

- [ ] **Step 4: Add logging to `PreferencesSyncService`**

In `PreferencesSyncService.swift`, at the start of `download(uid:key:)` (after the opening brace), add:

```swift
        SyncLog.info("Downloading preferences")
```

- [ ] **Step 5: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Neura/Features/Dashboard/Views/DashboardView.swift \
        Neura/Core/Services/Sync/DocumentSyncService.swift \
        Neura/Core/Services/Sync/HealthProfileSyncService.swift \
        Neura/Core/Services/Sync/PreferencesSyncService.swift
git commit -m "feat: drain queue on foreground; add sync-service logging"
```

---

## Final Verification (manual, after all tasks + rules deployed)

1. **Rules deployed** (Task 1, Step 4) and Storage enabled in Console.
2. **Fresh upload lands:** sign in, create a document. In Console: `users/{uid}/documents/{docId}` appears in Firestore and `users/{uid}/documents/{docId}.enc` in Storage. Also confirm `users/{uid}/keys/master` exists.
3. **Restore works:** delete the app, reinstall, sign in with the same account. Health profile, location, medical areas, and document files all return. `SyncLog` shows `Key resolved from Firestore` and `Restored N document(s)`.
4. **Offline durability:** turn on Airplane Mode, create a document (it queues), turn networking back on. `SyncLog` shows `Draining 1 pending op(s)` then `Uploaded document …`, and it appears in Firebase.
5. **Console filter:** in Console.app, filter subsystem `com.neura.sync` to watch the whole flow.

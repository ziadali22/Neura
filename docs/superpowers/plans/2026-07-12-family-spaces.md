# Family Spaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a parent create multiple Spaces (Me + one per child) under one Neura account, each with its own Health Profile, Documents, and Calendar entries, gated at 2 free / unlimited Pro.

**Architecture:** A new `Space` model + `ActiveSpaceManager` singleton (mirrors the existing `SubscriptionManager` pattern: `.shared`, `@StateObject` per consuming view, UserDefaults-persisted, cloud-synced via a new `SpaceSyncService`). `Document` and `CalendarEntry` gain an optional `spaceID: UUID?` field (nil = pre-Spaces data, treated as the default space). `HealthProfile` storage moves from a single blob to a `[UUID: HealthProfile]` dictionary keyed by space, behind the same public `HealthProfileViewModel.profile: HealthProfile` API so no health-profile view files change. No existing Firestore/Storage path changes except the health-profile blob's decoded shape.

**Tech Stack:** SwiftUI, Combine, Firebase (Firestore/Storage/Auth), CryptoKit, no XCTest target (per `CLAUDE.md`: "No test target exists yet").

## Global Constraints

- No XCTest target exists in this project. Every task's verification is: (1) the project builds via `xcodebuild`, (2) a concrete manual check in iOS Simulator, using the LLDB console (`po <expression>`) to exercise plumbing that has no UI yet (e.g. before Task 6 ships the space switcher).
- Follow existing design tokens (`Color.accent`, `.textPrimary`, `.surfaceWhite`, etc.) — no raw hex except where the codebase already stores hex strings as domain data (e.g. `Space.colorHex`, matching `DocumentCategory.color`'s existing `Color(hex:)` usage).
- Xcode uses filesystem-synced groups — new Swift files placed in the right folder are auto-detected, no `.pbxproj` editing needed.
- One commit per task, after its build + manual verification pass.
- Custom folders (`CustomFolder`/`CustomFolderStore`) are explicitly **out of scope** — they stay global/unscoped across all Spaces (confirmed decision). Do not touch `CustomFolder.swift`, `CustomFolderStore`, or `CustomFolderSyncService`.
- The free-tier document upload limit (`SubscriptionManager.canUpload`/`freeUploadLimit`) stays counted across **all** Spaces combined, unchanged — this plan only adds a separate, new **Space-count** limit (`canCreateSpace`). Do not modify `refreshDocumentCount()`/`canUpload`.
- `DocsViewModel` (`Neura/Features/Documents/ViewModel/DocsViewModel.swift`) is legacy, self-labeled ("Legacy ViewModel kept for CategoryDetailView/CategoryFolderGrid compatibility. New document pipeline uses DocumentsListViewModel"), hardcodes `count: 0`, and never reads `DocumentFileManager`. Before skipping it in Task 3, grep the codebase for `CategoryFolderGrid(` / `CategoryDetailView(` call sites to confirm neither is reachable from any live `NavigationStack` destination; if one is, flag it rather than silently leaving it unscoped.
- Known accepted limitation: `HealthProfileSyncService`'s Firestore document changes decoded shape (`HealthProfile` → `[UUID: HealthProfile]`) at the same path. An un-updated app build on another of the user's devices would fail to *read* the new shape (harmless, `try?`-guarded) but would *overwrite* it with a flat profile if it saves before updating. Acceptable for this app's scale; not solved by this plan.

---

### Task 1: `Space` model, `ActiveSpaceManager`, and cloud sync

**Files:**
- Create: `Neura/Core/Models/Space.swift`
- Create: `Neura/Core/Services/ActiveSpaceManager.swift`
- Create: `Neura/Core/Services/Sync/SpaceSyncService.swift`
- Modify: `Neura/Core/Services/Sync/PendingSyncStore.swift`
- Modify: `Neura/Core/Services/Sync/SyncQueueManager.swift`

**Interfaces:**
- Produces: `Space` (`Identifiable, Codable, Equatable`, fields `id, name, colorHex, createdAt, isDefault, isArchived`). `ActiveSpaceManager.shared: ActiveSpaceManager`, `.spaces: [Space]` (published), `.visibleSpaces: [Space]`, `.currentSpaceID: UUID` (published), `.setActive(_ spaceID: UUID)`, `.createSpace(name:colorHex:) -> Space`, `.archiveSpace(id:)`, `.mergeFromCloud(_:)`, `.resetForSignOut()`, static `ActiveSpaceManager.defaultSpaceID: UUID`. `SpaceSyncService.shared.upload(_:uid:key:)` / `.download(uid:key:) -> [Space]?`. `SyncQueueManager.shared.enqueueSpacesUpload(_:)`.
- Consumes: `EncryptionService.encrypt`/`decrypt`, `SyncLog`, existing `PendingSyncOp`/`PendingSyncStore` machinery.

- [ ] **Step 1: Create the `Space` model**

```swift
// Neura/Core/Models/Space.swift
import Foundation

struct Space: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var isDefault: Bool
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        createdAt: Date = Date(),
        isDefault: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.isArchived = isArchived
    }
}
```

- [ ] **Step 2: Create `ActiveSpaceManager`**

```swift
// Neura/Core/Services/ActiveSpaceManager.swift
import Foundation
import Combine

@MainActor
final class ActiveSpaceManager: ObservableObject {
    static let shared = ActiveSpaceManager()

    /// Every account's default space uses this exact id — never a freshly
    /// generated one. A random default id would produce two "default" spaces
    /// after a cloud restore merge (local-fresh vs. cloud-original), and the
    /// HealthProfile dictionary (keyed by whichever id was used when the
    /// profile was saved) would fail to resolve, silently falling back to the
    /// `.sample` demo profile instead of the user's real data.
    static let defaultSpaceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Published private(set) var spaces: [Space]
    @Published var currentSpaceID: UUID {
        didSet {
            guard currentSpaceID != oldValue else { return }
            UserDefaults.standard.set(currentSpaceID.uuidString, forKey: Self.currentSpaceIDKey)
        }
    }

    private static let spacesKey = "neura_spaces"
    private static let currentSpaceIDKey = "neura_current_space_id"

    /// Non-archived spaces, in creation order, for the switcher UI.
    var visibleSpaces: [Space] {
        spaces.filter { !$0.isArchived }
    }

    private init() {
        var loaded = Self.loadFromDisk()
        if loaded.isEmpty {
            loaded = [Self.makeDefaultSpace()]
            Self.persist(loaded)
        }
        self.spaces = loaded

        if let savedIDString = UserDefaults.standard.string(forKey: Self.currentSpaceIDKey),
           let savedID = UUID(uuidString: savedIDString),
           loaded.contains(where: { $0.id == savedID && !$0.isArchived }) {
            self.currentSpaceID = savedID
        } else {
            self.currentSpaceID = Self.defaultSpaceID
        }
    }

    private static func makeDefaultSpace() -> Space {
        Space(id: defaultSpaceID, name: "Me", colorHex: "FF5A00", isDefault: true)
    }

    // MARK: - Actions

    func setActive(_ spaceID: UUID) {
        guard spaces.contains(where: { $0.id == spaceID }) else { return }
        currentSpaceID = spaceID
    }

    @discardableResult
    func createSpace(name: String, colorHex: String) -> Space {
        let space = Space(name: name, colorHex: colorHex)
        spaces.append(space)
        save()
        return space
    }

    func archiveSpace(id: UUID) {
        guard let index = spaces.firstIndex(where: { $0.id == id }), !spaces[index].isDefault else { return }
        spaces[index].isArchived = true
        save()
        if currentSpaceID == id {
            currentSpaceID = Self.defaultSpaceID
        }
    }

    // MARK: - Cloud restore

    /// Merges cloud spaces into the local list (by id) after a reinstall/new
    /// device restore and persists locally — WITHOUT re-enqueuing an upload of
    /// data we just downloaded. Local spaces win on id conflict (mirrors
    /// CustomFolderStore.merge). Because the default space always uses the
    /// same fixed id, it naturally de-dupes instead of creating a second one.
    func mergeFromCloud(_ cloudSpaces: [Space]) {
        var byID = Dictionary(spaces.map { ($0.id, $0) }, uniquingKeysWith: { local, _ in local })
        for space in cloudSpaces where byID[space.id] == nil {
            byID[space.id] = space
            spaces.append(space)
        }
        Self.persist(spaces)
    }

    /// Wipes all local space state — called on logout/account deletion so the
    /// next signed-in user (on a shared device) never sees the previous
    /// account's spaces.
    func resetForSignOut() {
        UserDefaults.standard.removeObject(forKey: Self.spacesKey)
        UserDefaults.standard.removeObject(forKey: Self.currentSpaceIDKey)
        spaces = [Self.makeDefaultSpace()]
        currentSpaceID = Self.defaultSpaceID
        Self.persist(spaces)
    }

    // MARK: - Persistence

    private func save() {
        Self.persist(spaces)
        SyncQueueManager.shared.enqueueSpacesUpload(spaces)
    }

    private static func loadFromDisk() -> [Space] {
        guard let data = UserDefaults.standard.data(forKey: spacesKey),
              let saved = try? JSONDecoder().decode([Space].self, from: data) else { return [] }
        return saved
    }

    private static func persist(_ spaces: [Space]) {
        if let data = try? JSONEncoder().encode(spaces) {
            UserDefaults.standard.set(data, forKey: spacesKey)
        }
    }
}
```

- [ ] **Step 3: Create `SpaceSyncService`** (mirrors `CalendarEntrySyncService`'s single-blob pattern exactly)

```swift
// Neura/Core/Services/Sync/SpaceSyncService.swift
import Foundation
import FirebaseFirestore
import CryptoKit

/// Encrypted sync of the user's Space list to `users/{uid}/spaces/data`, mirroring
/// CalendarEntrySyncService/CustomFolderSyncService. The whole list is stored as a
/// single last-write-wins blob.
actor SpaceSyncService {
    static let shared = SpaceSyncService()

    private init() {}

    func upload(_ spaces: [Space], uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(spaces)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("spaces").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    func download(uid: String, key: SymmetricKey) async throws -> [Space]? {
        SyncLog.info("Downloading spaces")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("spaces").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode([Space].self, from: decrypted)
    }
}
```

- [ ] **Step 4: Add `.spacesUpload` to `PendingSyncOp.Kind`**

In `Neura/Core/Services/Sync/PendingSyncStore.swift`, change:

```swift
    enum Kind: String, Codable {
        case documentUpload
        case documentMetadata
        case documentDelete
        case profileUpload
        case preferencesUpload
        case calendarUpload
        case customFoldersUpload
    }
```

to:

```swift
    enum Kind: String, Codable {
        case documentUpload
        case documentMetadata
        case documentDelete
        case profileUpload
        case preferencesUpload
        case calendarUpload
        case customFoldersUpload
        case spacesUpload
    }
```

- [ ] **Step 5: Wire `SyncQueueManager`** — add upload methods, a `drainPending` case, and a restore step

Add these methods to `Neura/Core/Services/Sync/SyncQueueManager.swift`, right after the existing `enqueueCustomFoldersUpload`/`attemptCustomFoldersUpload` pair (before `// MARK: - Drain`):

```swift
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
```

In `drainPending()`'s `switch op.kind`, add a case (anywhere in the switch, e.g. after `.customFoldersUpload`):

```swift
            case .spacesUpload:
                let spaces = ActiveSpaceManager.shared.spaces
                if spaces.isEmpty {
                    pending.remove(op)
                } else {
                    attemptSpacesUpload(spaces)
                }
```

In `performInitialRestore(uid:key:)`, add a **new first step**, before the existing `// 1. Health profile` comment (renumber the existing comments 1/1b/1c/2/3 to 2/2b/2c/3/4 so the ordering stays legible):

```swift
            // 1. Spaces — restored BEFORE everything else so the containers
            // that documents/entries/health profiles reference (via spaceID)
            // already exist locally when the rest of the restore runs.
            if let cloudSpaces = try? await SpaceSyncService.shared.download(uid: uid, key: key),
               !cloudSpaces.isEmpty {
                ActiveSpaceManager.shared.mergeFromCloud(cloudSpaces)
                SyncLog.success("Restored \(cloudSpaces.count) space(s)")
            }
```

- [ ] **Step 6: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Manual verification (no UI yet — use LLDB)**

Launch the app in Simulator (fresh install: delete the app first if already installed, to exercise `ActiveSpaceManager`'s first-run path). Sign in. Pause execution (Xcode's pause button in the debug bar) and in the LLDB console run:

```
po ActiveSpaceManager.shared.spaces
```

Expected: exactly one `Space` named `"Me"`, `isDefault: true`, `id: 00000000-0000-0000-0000-000000000001`.

```
po ActiveSpaceManager.shared.currentSpaceID
```

Expected: matches the same id.

- [ ] **Step 8: Commit**

```bash
git add Neura/Core/Models/Space.swift Neura/Core/Services/ActiveSpaceManager.swift Neura/Core/Services/Sync/SpaceSyncService.swift Neura/Core/Services/Sync/PendingSyncStore.swift Neura/Core/Services/Sync/SyncQueueManager.swift
git commit -m "feat: add Space model, ActiveSpaceManager, and Space cloud sync"
```

---

### Task 2: Space-count gating and sign-out cleanup

**Files:**
- Modify: `Neura/Core/Services/SubscriptionManager.swift`
- Modify: `Neura/Features/Profile/Views/ProfileView.swift`

**Interfaces:**
- Consumes: `ActiveSpaceManager.shared.visibleSpaces`, `.resetForSignOut()` (Task 1).
- Produces: `SubscriptionManager.shared.canCreateSpace: Bool` (used by Task 6's UI).

- [ ] **Step 1: Add the space-count gate to `SubscriptionManager`**

In `Neura/Core/Services/SubscriptionManager.swift`, add a new private constant next to `freeShareLimit` (line 25):

```swift
    private let freeShareLimit = 1
    private let freeSpaceLimit = 2
```

Add a new computed property next to `canShareViaQR` (after line 76):

```swift
    var canShareViaQR: Bool {
        isPro || shareCount < freeShareLimit
    }

    var canCreateSpace: Bool {
        isPro || ActiveSpaceManager.shared.visibleSpaces.count < freeSpaceLimit
    }
```

- [ ] **Step 2: Clear Space state on logout/account deletion**

In `Neura/Features/Profile/Views/ProfileView.swift`, in `clearLocalUserData()` (line 295), add a call after the existing `DocumentFileManager` cleanup:

```swift
    func clearLocalUserData() {
        let keys = [
            "health_profile_data",
            "hasCompletedOnboarding",
            "user_location",
            "onboarding_medical_areas",
            "neura_biometric_lock_enabled",
            "neura_document_upload_count",
            "neura_share_count",
            "neura_is_pro"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        try? DocumentFileManager.shared.deleteAllLocalDocuments()
        ActiveSpaceManager.shared.resetForSignOut()
    }
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Launch the app, sign in. Pause and in LLDB create two more spaces to hit the free limit:

```
expression -l swift -- ActiveSpaceManager.shared.createSpace(name: "Test1", colorHex: "3498DB")
expression -l swift -- ActiveSpaceManager.shared.createSpace(name: "Test2", colorHex: "9B59B6")
po SubscriptionManager.shared.canCreateSpace
```

Expected: `false` (Me + Test1 + Test2 = 3 ≥ `freeSpaceLimit` of 2 — wait, the limit counts from 2 total, so after creating just **one** more (Me + Test1 = 2) `canCreateSpace` should already read `false`; creating `Test2` is to confirm it stays `false`, not that it's what trips the gate). Then in the running app, tap **Log Out** in the Profile tab, confirm the alert, and once back on the onboarding/sign-in screen, sign back in and check:

```
po ActiveSpaceManager.shared.spaces
```

Expected: exactly one `Space` again (`"Me"`, `id: 00000000-0000-0000-0000-000000000001`) — the two test spaces are gone.

- [ ] **Step 5: Commit**

```bash
git add Neura/Core/Services/SubscriptionManager.swift Neura/Features/Profile/Views/ProfileView.swift
git commit -m "feat: gate Space creation behind the free-tier limit, clear Spaces on sign-out"
```

---

### Task 3: Scope Documents by Space

**Files:**
- Modify: `Neura/Core/Models/Document.swift`
- Modify: `Neura/Core/Services/Sync/DocumentSyncService.swift`
- Modify: `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`

**Interfaces:**
- Consumes: `ActiveSpaceManager.shared.currentSpaceID`, `ActiveSpaceManager.defaultSpaceID` (Task 1).
- Produces: `Document.spaceID: UUID?` (nil = pre-Spaces data, belongs to the default space).

- [ ] **Step 1: Add `spaceID` to `Document`**

In `Neura/Core/Models/Document.swift`, add the stored property after `expiryDate` (line 164):

```swift
    var expiryDate: Date?
    /// Which Space this document belongs to. `nil` means it predates Spaces
    /// and is treated as belonging to the default space.
    var spaceID: UUID?
```

Add the parameter to the designated initializer (line 171-195):

```swift
    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        createdAt: Date = Date(),
        documentType: DocumentType,
        category: DocumentCategory? = nil,
        specialization: MedicalSpecialization? = nil,
        doctorName: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil,
        expiryDate: Date? = nil,
        spaceID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.filename = fileURL.lastPathComponent
        self.createdAt = createdAt
        self.documentType = documentType
        self.category = category
        self.specialization = specialization
        self.doctorName = doctorName
        self.notes = notes
        self.tags = tags
        self.expiryDate = expiryDate
        self.spaceID = spaceID
    }
```

Add to `CodingKeys` (line 199-203):

```swift
    private enum CodingKeys: String, CodingKey {
        case id, name, filename, createdAt, documentType, category, specialization, doctorName, notes, tags, expiryDate, spaceID
        // Legacy key for backward compatibility
        case fileURL
    }
```

In `init(from decoder:)`, add after the `expiryDate` line (217):

```swift
        expiryDate = try container.decodeIfPresent(Date.self, forKey: .expiryDate)
        spaceID = try container.decodeIfPresent(UUID.self, forKey: .spaceID)
```

In `encode(to:)`, add after the `expiryDate` line (240):

```swift
        try container.encodeIfPresent(expiryDate, forKey: .expiryDate)
        try container.encodeIfPresent(spaceID, forKey: .spaceID)
```

- [ ] **Step 2: Carry `spaceID` through `DocumentSyncService`**

In `Neura/Core/Services/Sync/DocumentSyncService.swift`, add to `DocumentSyncMetadata` (line 140-149):

```swift
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
    let spaceID: UUID?

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
        spaceID        = doc.spaceID
    }
}
```

In `downloadAll(uid:key:)`'s document reconstruction (line 118-129), add the new argument:

```swift
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
                tags: syncMeta.tags,
                spaceID: syncMeta.spaceID
            )
```

- [ ] **Step 3: Scope `DocumentsListViewModel`'s visible lists by active Space**

In `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`, add a property next to `fileManager` (line 72):

```swift
    private let fileManager = DocumentFileManager.shared
    private let activeSpaceManager = ActiveSpaceManager.shared
```

Change `filteredDocuments` (line 87-116) to filter by space **first**, so every derived list (`groupedDocuments` builds on `filteredDocuments`) inherits the scoping automatically. `documents` itself stays the full, unfiltered, all-Spaces array — it's what `persistMetadata()` writes back to disk, so it must never be narrowed:

```swift
    var filteredDocuments: [Document] {
        var result = documents.filter {
            ($0.spaceID ?? ActiveSpaceManager.defaultSpaceID) == activeSpaceManager.currentSpaceID
        }

        // Category filter
        if let category = selectedCategoryFilter {
            result = result.filter { $0.category == category }
        }
```

(the rest of the function — specialization filter, search, sort, return — is unchanged)

Change `allFilesSorted` (line 119-121):

```swift
    // All documents in the active space, sorted newest-first (no category/specialisation filter applied).
    var allFilesSorted: [Document] {
        documents
            .filter { ($0.spaceID ?? ActiveSpaceManager.defaultSpaceID) == activeSpaceManager.currentSpaceID }
            .sorted { $0.createdAt > $1.createdAt }
    }
```

`lockedDocumentIDs` (subscription-lock logic) and `SubscriptionManager.refreshDocumentCount()` are intentionally left reading the full unscoped `documents` list — the free-tier upload count stays account-wide, not per-Space (see Global Constraints).

- [ ] **Step 4: Stamp new documents with the active Space**

In `saveDocument(metadata:preview:)` (line 430-496), capture the active space id on the main actor before hopping to the detached task, then stamp it onto the new document:

```swift
    func saveDocument(metadata: DocumentMetadata, preview: DocumentPreviewContent) {
        isProcessing = true

        let metadata = resolveFolder(for: metadata)
        let spaceID = activeSpaceManager.currentSpaceID

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let fm = DocumentFileManager.shared

            do {
                var document: Document
                let source: String

                switch preview {
                case .scannedImages(let images):
                    document = try fm.savePDF(from: images, name: metadata.name)
                    source = "scan"

                case .importedFile(let url):
                    document = try fm.importFile(from: url, name: metadata.name)
                    source = "import"
                }

                // Apply metadata
                document.createdAt = metadata.documentDate
                document.category = metadata.category
                document.specialization = metadata.specialization
                if !metadata.doctorName.isEmpty { document.doctorName = metadata.doctorName }
                if !metadata.notes.isEmpty { document.notes = metadata.notes }
                document.expiryDate = metadata.expiryDate
                document.spaceID = spaceID
                if let folderId = metadata.customFolderId {
                    document.tags = (document.tags ?? []) + [folderId.uuidString]
                }
```

(everything after this — the `await MainActor.run { ... }` block — is unchanged)

- [ ] **Step 5: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual verification**

Launch the app, sign in, go to Docs tab. Add 2 documents (any source) — confirm they still appear (existing default-space behavior, unaffected). Pause and in LLDB:

```
expression -l swift -- let s = ActiveSpaceManager.shared.createSpace(name: "Emma", colorHex: "27AE60")
expression -l swift -- ActiveSpaceManager.shared.setActive(ActiveSpaceManager.shared.spaces.last!.id)
```

Resume the app, reopen the Docs tab (pull to refresh or re-enter the tab if it doesn't live-update yet — the switcher UI lands in Task 6). Expected: Docs list is now empty (0 documents — the 2 originals belong to the default space, not "Emma"). Add a new document while in "Emma" — confirm only that 1 document shows. Then in LLDB:

```
expression -l swift -- ActiveSpaceManager.shared.setActive(ActiveSpaceManager.defaultSpaceID)
```

Re-enter the Docs tab. Expected: the original 2 documents are back, the "Emma" document is not shown.

- [ ] **Step 7: Commit**

```bash
git add Neura/Core/Models/Document.swift Neura/Core/Services/Sync/DocumentSyncService.swift Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift
git commit -m "feat: scope Documents by active Space"
```

---

### Task 4: Scope Calendar entries by Space

**Files:**
- Modify: `Neura/Features/Calendar/Models/CalendarEntry.swift`
- Modify: `Neura/Features/Calendar/ViewModel/CalendarViewModel.swift`

**Interfaces:**
- Consumes: `ActiveSpaceManager.shared`/`.defaultSpaceID` (Task 1).
- Produces: `CalendarEntry.spaceID: UUID?`. No other Calendar view files change — `CalendarViewModel.entries` is filtered at the source, so every consumer (`entries(on:)`, `daysWithEntries`, `agendaItems`, `upcomingItems`, `timelineEntries`) is scoped for free.

- [ ] **Step 1: Add `spaceID` to `CalendarEntry`**

`CalendarEntry` uses **synthesized** Codable (confirmed — no custom `init(from:)`), so an `Optional` field decodes safely against old persisted/synced data with zero extra code, exactly like the existing `isAllDay: Bool?` field. In `Neura/Features/Calendar/Models/CalendarEntry.swift`, add the property after `completedDates` (line 132):

```swift
    /// Occurrence dates the user has marked complete (per-occurrence for recurring entries).
    var completedDates: [Date]
    /// Which Space this entry belongs to. `nil` means it predates Spaces and
    /// is treated as belonging to the default space.
    var spaceID: UUID?
```

Add the parameter to the initializer (line 134-160):

```swift
    init(
        id: UUID = UUID(),
        type: CalendarEntryType,
        title: String,
        date: Date,
        isAllDay: Bool? = nil,
        notes: String? = nil,
        linkedDocumentID: UUID? = nil,
        reminder: ReminderRule? = nil,
        recurrence: RecurrenceRule = RecurrenceRule(),
        doctor: String? = nil,
        specialization: MedicalSpecialization? = nil,
        completedDates: [Date] = [],
        spaceID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.notes = notes
        self.linkedDocumentID = linkedDocumentID
        self.reminder = reminder
        self.recurrence = recurrence
        self.doctor = doctor
        self.specialization = specialization
        self.completedDates = completedDates
        self.spaceID = spaceID
    }
```

- [ ] **Step 2: Filter `CalendarViewModel.entries` by active Space at the source**

In `Neura/Features/Calendar/ViewModel/CalendarViewModel.swift`, change the `init` (line 16-23) to combine the store's entries with the active space, and stamp `spaceID` on new entries in `save(_:)` (line 118-126):

```swift
    private let store: CalendarEntryStore
    private let activeSpaceManager: ActiveSpaceManager
    private let scheduler = CalendarReminderScheduler.shared
    private var cancellable: AnyCancellable?

    /// Mirror of the store's entries, already filtered to the active space, so
    /// SwiftUI re-renders on either a data change or a space switch.
    @Published private(set) var entries: [CalendarEntry] = []

    init(store: CalendarEntryStore = .shared, activeSpaceManager: ActiveSpaceManager = .shared) {
        self.store = store
        self.activeSpaceManager = activeSpaceManager
        let today = Calendar.current.startOfDay(for: Date())
        self.visibleMonth = today
        self.selectedDay = today
        self.entries = store.entries.filter {
            ($0.spaceID ?? ActiveSpaceManager.defaultSpaceID) == activeSpaceManager.currentSpaceID
        }
        cancellable = Publishers.CombineLatest(store.$entries, activeSpaceManager.$currentSpaceID)
            .map { entries, spaceID in
                entries.filter { ($0.spaceID ?? ActiveSpaceManager.defaultSpaceID) == spaceID }
            }
            .sink { [weak self] filtered in self?.entries = filtered }
    }
```

```swift
    func save(_ entry: CalendarEntry) {
        var entry = entry
        let isNew = store.entry(id: entry.id) == nil
        if isNew {
            entry.spaceID = activeSpaceManager.currentSpaceID
        }
        store.update(entry)            // update() inserts if id is new
        scheduler.reschedule(for: store.entries)
        AnalyticsManager.shared.track(
            isNew ? .calendarEntryCreated : .calendarEntryUpdated,
            properties: ["type": entry.type.rawValue]
        )
    }
```

(`delete(_:)` and `toggleCompletion(_:on:)` are unchanged — they operate on an existing entry's `id`, which already carries the right `spaceID`.)

- [ ] **Step 3: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Launch the app, sign in, go to Calendar tab. Add an appointment — confirm it shows (default space, unaffected). Pause, in LLDB:

```
expression -l swift -- ActiveSpaceManager.shared.setActive(ActiveSpaceManager.shared.spaces.first(where: { $0.name == "Emma" })!.id)
```

(reuse the "Emma" space created in Task 3's verification, or create one first). Re-enter the Calendar tab. Expected: the appointment is gone (calendar is empty for "Emma"). Add a new entry while in "Emma" — confirm only that 1 shows. Switch back to the default space via LLDB (`ActiveSpaceManager.shared.setActive(ActiveSpaceManager.defaultSpaceID)`), re-enter the tab. Expected: original appointment is back, "Emma"'s entry is not shown.

- [ ] **Step 5: Commit**

```bash
git add Neura/Features/Calendar/Models/CalendarEntry.swift Neura/Features/Calendar/ViewModel/CalendarViewModel.swift
git commit -m "feat: scope Calendar entries by active Space"
```

---

### Task 5: Scope Health Profile by Space

**Files:**
- Modify: `Neura/Features/HealthProfile/ViewModel/HealthProfileViewModel.swift`
- Modify: `Neura/Core/Services/Sync/HealthProfileSyncService.swift`
- Modify: `Neura/Core/Services/Sync/SyncQueueManager.swift`
- Modify: `Neura/App/NeuraApp.swift`
- Modify: `Neura/Features/Profile/Views/ProfileView.swift`

**Interfaces:**
- Consumes: `ActiveSpaceManager.shared`/`.defaultSpaceID` (Task 1).
- Produces: `HealthProfileViewModel.profile: HealthProfile` keeps its existing public type and behavior for every consumer in `Features/HealthProfile/Views/*` — nothing there changes. Internally, storage becomes `[UUID: HealthProfile]` under a new key `"health_profiles_by_space"`; the old `"health_profile_data"` key is read once for a one-time migration and left in place (harmless) afterward.

- [ ] **Step 1: Restructure `HealthProfileViewModel`'s persistence**

Replace the top of `Neura/Features/HealthProfile/ViewModel/HealthProfileViewModel.swift` (lines 1-31) with:

```swift
import Foundation
import UIKit
import Combine

@MainActor
final class HealthProfileViewModel: ObservableObject {
    @Published var profile: HealthProfile

    private static let storageKey = "health_profiles_by_space"
    /// Legacy single-profile key from before Spaces existed — read once for migration.
    private static let legacyStorageKey = "health_profile_data"

    private let activeSpaceManager: ActiveSpaceManager
    private var spaceObserver: AnyCancellable?
    private var restoreObserver: NSObjectProtocol?

    init(activeSpaceManager: ActiveSpaceManager = .shared) {
        self.activeSpaceManager = activeSpaceManager
        let all = Self.loadAllFromDisk()
        self.profile = Self.profile(for: activeSpaceManager.currentSpaceID, in: all)

        spaceObserver = activeSpaceManager.$currentSpaceID.sink { [weak self] _ in
            self?.reload()
        }
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .healthProfileRestored, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reload() }
        }
    }

    func reload() {
        let all = Self.loadAllFromDisk()
        profile = Self.profile(for: activeSpaceManager.currentSpaceID, in: all)
    }

    /// A space with no stored profile yet gets an empty `.default` profile —
    /// EXCEPT the original default space, which keeps showing the `.sample`
    /// demo data on first launch (existing pre-Spaces behavior, preserved so
    /// new users aren't regressed). A newly created child space must never
    /// show demo or another space's data.
    private static func profile(for spaceID: UUID, in all: [UUID: HealthProfile]) -> HealthProfile {
        if let existing = all[spaceID] { return existing }
        return spaceID == ActiveSpaceManager.defaultSpaceID ? .sample : .default
    }

    private static func loadAllFromDisk() -> [UUID: HealthProfile] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([UUID: HealthProfile].self, from: data) {
            return saved
        }
        // One-time migration: wrap the pre-Spaces single profile under the default space.
        if let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey),
           let legacyProfile = try? JSONDecoder().decode(HealthProfile.self, from: legacyData) {
            let migrated = [ActiveSpaceManager.defaultSpaceID: legacyProfile]
            if let data = try? JSONEncoder().encode(migrated) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            return migrated
        }
        return [:]
    }
```

Leave every method between `// MARK: - General Data` and `// MARK: - PDF Generation` (lines 33-108 in the original file) **unchanged** — they all mutate `profile` then call `save()`, which is the only remaining method to update.

Replace the `// MARK: - Persistence` section at the bottom (original lines 373-383) with:

```swift
    // MARK: - Persistence

    private func save() {
        profile.lastUpdated = Date()
        var all = Self.loadAllFromDisk()
        all[activeSpaceManager.currentSpaceID] = profile
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        SyncQueueManager.shared.enqueueProfileUpload(all)
        updateNotifications()
        AnalyticsManager.shared.track(.healthProfileSaved)
    }
```

(`updateNotifications()` below it is unchanged.)

- [ ] **Step 2: Change `HealthProfileSyncService` to sync the dictionary**

Replace `Neura/Core/Services/Sync/HealthProfileSyncService.swift` in full:

```swift
import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Health Profile Sync Service

actor HealthProfileSyncService {
    static let shared = HealthProfileSyncService()

    private init() {}

    // MARK: - Upload

    func upload(profiles: [UUID: HealthProfile], uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(profiles)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("profile").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> [UUID: HealthProfile]? {
        SyncLog.info("Downloading health profiles")
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("profile").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode([UUID: HealthProfile].self, from: decrypted)
    }
}
```

- [ ] **Step 3: Update `SyncQueueManager` for the new profile shape**

In `Neura/Core/Services/Sync/SyncQueueManager.swift`, replace `enqueueProfileUpload`/`attemptProfileUpload` (lines 108-124):

```swift
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
```

In `drainPending()`, replace the `.profileUpload` case (lines 230-236):

```swift
            case .profileUpload:
                if let data = UserDefaults.standard.data(forKey: "health_profiles_by_space"),
                   let profiles = try? JSONDecoder().decode([UUID: HealthProfile].self, from: data) {
                    attemptProfileUpload(profiles)
                } else {
                    pending.remove(op)
                }
```

In `performInitialRestore(uid:key:)`, replace the health-profile block (originally step "1", now step "2" after Task 1 added the Spaces restore step ahead of it):

```swift
            // 2. Health profile(s)
            if let profiles = try? await HealthProfileSyncService.shared.download(uid: uid, key: key),
               let data = try? JSONEncoder().encode(profiles) {
                UserDefaults.standard.set(data, forKey: "health_profiles_by_space")
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
                SyncLog.success("Restored \(profiles.count) health profile(s)")
            }
```

- [ ] **Step 4: Update the launch-time notification-scheduling read in `NeuraApp.swift`**

This notification nudges the account owner to complete *their own* profile, so it always reads the default space specifically, not whichever space happens to be active. In `Neura/App/NeuraApp.swift`, replace `scheduleProfileNotificationIfNeeded()` (lines 162-177):

```swift
    /// Reads the default space's saved profile from UserDefaults and asks the
    /// notification manager to schedule (or cancel) reminders based on current
    /// fill state. Always the default (account-owner) space, regardless of
    /// which space is currently active — this nudge is about the owner's own
    /// profile completeness.
    func scheduleProfileNotificationIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: "health_profiles_by_space"),
              let profiles = try? JSONDecoder().decode([UUID: HealthProfile].self, from: data),
              let profile = profiles[ActiveSpaceManager.defaultSpaceID] else {
            // No profile saved yet — schedule a gentle first-time nudge
            ProfileNotificationManager.shared.requestPermissionAndScheduleIfNeeded(filledCount: 0, total: 8)
            return
        }
        let g = profile.generalData
        let fields = [g.fullName, g.dateOfBirth, g.gender, g.height, g.weight,
                      g.bloodType, g.insuranceStatus, g.myPhoneNumber, g.emergencyContactName, g.emergencyContactNumber]
        let filled = fields.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        ProfileNotificationManager.shared.requestPermissionAndScheduleIfNeeded(filledCount: filled, total: fields.count)
    }
```

Do **not** touch the earlier onboarding-skip check in `init()` (`if !UserDefaults.standard.bool(forKey: key), UserDefaults.standard.data(forKey: "health_profile_data") != nil`) — it specifically detects pre-migration legacy data to skip onboarding for upgrading users, and must keep reading the legacy key.

- [ ] **Step 5: Clear the new storage key on sign-out**

In `Neura/Features/Profile/Views/ProfileView.swift`, add `"health_profiles_by_space"` to the `keys` array in `clearLocalUserData()` (from Task 2's edit):

```swift
    func clearLocalUserData() {
        let keys = [
            "health_profile_data",
            "health_profiles_by_space",
            "hasCompletedOnboarding",
            "user_location",
            "onboarding_medical_areas",
            "neura_biometric_lock_enabled",
            "neura_document_upload_count",
            "neura_share_count",
            "neura_is_pro"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        try? DocumentFileManager.shared.deleteAllLocalDocuments()
        ActiveSpaceManager.shared.resetForSignOut()
    }
```

- [ ] **Step 6: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Manual verification**

Launch the app, sign in, go to Profile → Health Profile, fill in a couple of fields (e.g. full name, blood type), confirm they save (unaffected default-space behavior). Pause, in LLDB switch to a child space (reuse "Emma" or create one):

```
expression -l swift -- ActiveSpaceManager.shared.setActive(ActiveSpaceManager.shared.spaces.first(where: { $0.name == "Emma" })!.id)
```

Re-open Health Profile. Expected: **empty** fields (not the sample "Elena Rossi" demo data, and not the values just entered for the default space). Fill in different values for "Emma", switch back to the default space via LLDB, re-open Health Profile. Expected: the original default-space values are intact and unaffected by what was entered for "Emma".

- [ ] **Step 8: Commit**

```bash
git add Neura/Features/HealthProfile/ViewModel/HealthProfileViewModel.swift Neura/Core/Services/Sync/HealthProfileSyncService.swift Neura/Core/Services/Sync/SyncQueueManager.swift Neura/App/NeuraApp.swift Neura/Features/Profile/Views/ProfileView.swift
git commit -m "feat: scope Health Profile by active Space"
```

---

### Task 6: Spaces switcher UI in the Profile tab

**Files:**
- Create: `Neura/Features/Profile/Views/Components/SpacesSection.swift`
- Create: `Neura/Features/Profile/Views/Components/AddSpaceSheet.swift`
- Modify: `Neura/Features/Profile/Views/ProfileView.swift`
- Modify: `Neura/Core/L10n/L10n.swift`
- Modify: `Neura/Core/L10n/en.lproj/Localizable.strings`
- Modify: `Neura/Core/L10n/ar.lproj/Localizable.strings`
- Modify: `Neura/Core/L10n/ro.lproj/Localizable.strings`

**Interfaces:**
- Consumes: `ActiveSpaceManager.shared` (Task 1), `SubscriptionManager.shared.canCreateSpace` (Task 2), `PaywallView(subscriptionManager:)` (existing), `Color(hex:)` (existing).

- [ ] **Step 1: Add L10n keys**

In `Neura/Core/L10n/L10n.swift`, change the `Profile.Section` enum (line 696-701):

```swift
        enum Section {
            static var profile: String { "profile.section.profile".l10n() }
            static var spaces: String { "profile.section.spaces".l10n() }
            static var preferences: String { "profile.section.preferences".l10n() }
            static var support: String { "profile.section.support".l10n() }
            static var account: String { "profile.section.account".l10n() }
        }
```

Add a new nested enum right after it:

```swift
        enum Spaces {
            static var addSpaceTitle: String { "profile.spaces.addSpaceTitle".l10n() }
            static var namePlaceholder: String { "profile.spaces.namePlaceholder".l10n() }
            static var removeTitle: String { "profile.spaces.removeTitle".l10n() }
            static var removeMessage: String { "profile.spaces.removeMessage".l10n() }
        }
```

Add to `Neura/Core/L10n/en.lproj/Localizable.strings` (near the existing `"profile.section.*"` entries):

```
"profile.section.spaces" = "Spaces";
"profile.spaces.addSpaceTitle" = "Add Space";
"profile.spaces.namePlaceholder" = "Name";
"profile.spaces.removeTitle" = "Remove Space";
"profile.spaces.removeMessage" = "This space's documents, calendar entries, and health profile stay saved but hidden. Contact support to restore access later.";
```

Add to `Neura/Core/L10n/ro.lproj/Localizable.strings`:

```
"profile.section.spaces" = "Spații";
"profile.spaces.addSpaceTitle" = "Adaugă spațiu";
"profile.spaces.namePlaceholder" = "Nume";
"profile.spaces.removeTitle" = "Elimină spațiul";
"profile.spaces.removeMessage" = "Documentele, evenimentele din calendar și profilul medical ale acestui spațiu rămân salvate, dar ascunse. Contactează asistența pentru a restaura accesul mai târziu.";
```

Add to `Neura/Core/L10n/ar.lproj/Localizable.strings`:

```
"profile.section.spaces" = "المساحات";
"profile.spaces.addSpaceTitle" = "إضافة مساحة";
"profile.spaces.namePlaceholder" = "الاسم";
"profile.spaces.removeTitle" = "إزالة المساحة";
"profile.spaces.removeMessage" = "تبقى مستندات هذه المساحة وأحداث التقويم والملف الصحي محفوظة لكنها مخفية. تواصل مع الدعم لاستعادة الوصول لاحقًا.";
```

- [ ] **Step 2: Create `AddSpaceSheet`**

```swift
// Neura/Features/Profile/Views/Components/AddSpaceSheet.swift
import SwiftUI

struct AddSpaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColorHex = AddSpaceSheet.colorPalette[0]

    let onCreate: (String, String) -> Void

    static let colorPalette = ["FF5A00", "3498DB", "9B59B6", "27AE60", "E74C3C", "1ABC9C"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.Profile.Spaces.namePlaceholder, text: $name)
                }

                Section {
                    HStack(spacing: 12) {
                        ForEach(Self.colorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.textPrimary, lineWidth: selectedColorHex == hex ? 2 : 0)
                                        .padding(-3)
                                )
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Profile.Spaces.addSpaceTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.create) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed, selectedColorHex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create `SpacesSection`**

```swift
// Neura/Features/Profile/Views/Components/SpacesSection.swift
import SwiftUI

struct SpacesSection: View {
    @StateObject private var activeSpaceManager = ActiveSpaceManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showAddSpace = false
    @State private var showPaywall = false
    @State private var spaceToRemove: Space?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activeSpaceManager.visibleSpaces) { space in
                    SpaceChip(
                        space: space,
                        isActive: space.id == activeSpaceManager.currentSpaceID,
                        onTap: { activeSpaceManager.setActive(space.id) },
                        onRemove: space.isDefault ? nil : { spaceToRemove = space }
                    )
                }

                Button {
                    if subscriptionManager.canCreateSpace {
                        showAddSpace = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.surfaceWhite)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAddSpace) {
            AddSpaceSheet { name, colorHex in
                activeSpaceManager.createSpace(name: name, colorHex: colorHex)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .alert(
            L10n.Profile.Spaces.removeTitle,
            isPresented: Binding(
                get: { spaceToRemove != nil },
                set: { if !$0 { spaceToRemove = nil } }
            )
        ) {
            Button(L10n.Common.delete, role: .destructive) {
                if let space = spaceToRemove {
                    activeSpaceManager.archiveSpace(id: space.id)
                }
                spaceToRemove = nil
            }
            Button(L10n.Common.cancel, role: .cancel) { spaceToRemove = nil }
        } message: {
            Text(L10n.Profile.Spaces.removeMessage)
        }
    }
}

private struct SpaceChip: View {
    let space: Space
    let isActive: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: space.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(space.name.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.accent, lineWidth: isActive ? 2 : 0)
                        .padding(-3)
                )

            Text(space.name)
                .font(.captionS)
                .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label(L10n.Profile.Spaces.removeTitle, systemImage: "trash")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Wire `SpacesSection` into `ProfileView`**

In `Neura/Features/Profile/Views/ProfileView.swift`, insert a new section between the existing "Profile" section and the "Preferences" section (after line 63's `.padding(.bottom, 24)`, before line 66's `// Preferences section` comment):

```swift
                        // Profile section
                        ProfileSectionHeader(title: L10n.Profile.Section.profile)
                        VStack(spacing: 11) {
                            SettingsRow(icon: "profile", title: L10n.Profile.healthProfile) {
                                router.push(.healthProfile)
                            }
                            SettingsRow(icon: "sub", title: L10n.Profile.subscription) {
                                handleSubscriptionTap()
                            }
                        }
                        .padding(.bottom, 24)

                        // Spaces section
                        ProfileSectionHeader(title: L10n.Profile.Section.spaces)
                        SpacesSection()
                            .padding(.bottom, 24)

                        // Preferences section
                        ProfileSectionHeader(title: L10n.Profile.Section.preferences)
```

- [ ] **Step 5: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual verification (full end-to-end, via the real UI)**

Launch the app in Simulator, sign in, go to Profile tab. Expected: a "Spaces" section shows one chip labeled "M" / "Me", highlighted as active, plus a "+" button.

Tap "+". Expected: the Add Space sheet opens. Enter "Emma", pick a color, tap Create. Expected: sheet dismisses, a new "Emma" chip appears next to "Me".

Tap the "Emma" chip. Expected: it becomes highlighted/active. Go to Docs tab — expected empty (no documents). Go to Calendar tab — expected empty. Go to Profile → Health Profile — expected empty fields (not the sample demo data). Add one document, one calendar entry, and fill in one health-profile field while in "Emma".

Tap back to the "Me" chip in Profile tab. Expected: Docs/Calendar/Health Profile all show the original pre-existing data, with nothing from "Emma" mixed in.

Tap "+" again to add a third space. Since the free limit is 2 total (`freeSpaceLimit = 2`, and Me + Emma already = 2), expected: the Paywall screen opens instead of the Add Space sheet.

Dismiss the paywall. Long-press (or tap-and-hold to trigger the context menu on) the "Emma" chip, tap "Remove Space" in the context menu, confirm the alert. Expected: "Emma" disappears from the switcher, active space falls back to "Me". Tap "+" once more — expected: the Add Space sheet now opens again (back under the free limit).

- [ ] **Step 7: Commit**

```bash
git add Neura/Features/Profile/Views/Components/SpacesSection.swift Neura/Features/Profile/Views/Components/AddSpaceSheet.swift Neura/Features/Profile/Views/ProfileView.swift Neura/Core/L10n/L10n.swift Neura/Core/L10n/en.lproj/Localizable.strings Neura/Core/L10n/ar.lproj/Localizable.strings Neura/Core/L10n/ro.lproj/Localizable.strings
git commit -m "feat: add Spaces switcher UI to the Profile tab"
```

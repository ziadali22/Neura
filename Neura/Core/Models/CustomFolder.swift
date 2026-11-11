import Foundation
import Combine

// MARK: - Custom Folder

struct CustomFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /// Account this folder belongs to. Nil means it predates multi-account
    /// support and belongs to the default (account-owner) space — same
    /// convention as `Document.spaceID`, so old persisted/synced folders decode
    /// safely and stay with the owner instead of leaking into every account.
    var spaceID: UUID?

    init(id: UUID = UUID(), name: String, spaceID: UUID? = nil) {
        self.id = id
        self.name = name
        self.spaceID = spaceID
    }

    /// Whether this folder belongs to the given account.
    func belongsToSpace(_ spaceID: UUID) -> Bool {
        (self.spaceID ?? ActiveSpaceManager.defaultSpaceID) == spaceID
    }

    /// The auto-created catch-all folder is stored under a fixed English name
    /// (so cross-device matching and sync stay stable across locales) but
    /// should read in the user's language.
    var displayName: String {
        name.caseInsensitiveCompare(CustomFolderStore.otherFolderName) == .orderedSame
            ? L10n.Documents.otherFolderName
            : name
    }

    /// SF Symbols assigned to custom folders so each one looks distinct.
    static let iconPalette: [String] = [
        "heart.fill", "cross.case.fill", "pills.fill", "stethoscope",
        "bandage.fill", "waveform.path.ecg", "lungs.fill", "eye.fill",
        "drop.fill", "syringe.fill", "brain.head.profile", "facemask.fill",
        "allergens", "bolt.heart.fill", "staroflife.fill", "cross.fill"
    ]

    /// A symbol derived from the folder's id — stable across launches (UUID
    /// bytes, not Swift's per-process `hashValue`) yet varied per folder.
    var iconSymbol: String {
        let b = id.uuid
        let seed = Int(b.0) &+ Int(b.4) &+ Int(b.8) &+ Int(b.12) &+ Int(b.15)
        return Self.iconPalette[seed % Self.iconPalette.count]
    }

    /// Stable index used to pick a tint colour for the icon (see the grid card).
    var colorSeed: Int {
        let b = id.uuid
        return Int(b.1) &+ Int(b.5) &+ Int(b.9) &+ Int(b.13)
    }
}

// MARK: - Custom Folder Store

@MainActor
final class CustomFolderStore: ObservableObject {
    static let shared = CustomFolderStore()

    /// Name of the auto-created catch-all folder used for documents saved
    /// without a category or custom folder.
    static let otherFolderName = "Other"

    /// Every folder across all accounts. Only sync and migration should read
    /// this — UI must use `foldersForActiveSpace` so one account never shows
    /// another's folders.
    @Published private(set) var folders: [CustomFolder] = []
    private let key = "customFolders_v1"

    private let activeSpaceManager = ActiveSpaceManager.shared
    private var spaceObserver: AnyCancellable?

    private init() {
        load()
        // `folders` doesn't change when the active account switches, so without
        // this, views observing this store keep rendering the previous account's
        // folders until some unrelated change republishes.
        spaceObserver = activeSpaceManager.$currentSpaceID
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    /// Folders belonging to the active account only.
    var foldersForActiveSpace: [CustomFolder] {
        folders(for: activeSpaceManager.currentSpaceID)
    }

    func folders(for spaceID: UUID) -> [CustomFolder] {
        folders.filter { $0.belongsToSpace(spaceID) }
    }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders.append(CustomFolder(name: trimmed, spaceID: activeSpaceManager.currentSpaceID))
        save()
    }

    /// Returns the existing folder matching `name` (case-insensitive) **within
    /// the active account**, or creates and persists a new one for it. Used to
    /// auto-file documents saved without a category or folder — each account
    /// therefore gets its own "Other" folder rather than sharing one.
    @discardableResult
    func findOrCreate(name: String) -> CustomFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = foldersForActiveSpace.first(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return existing
        }
        let folder = CustomFolder(name: trimmed, spaceID: activeSpaceManager.currentSpaceID)
        folders.append(folder)
        save()
        return folder
    }

    // MARK: - Legacy (pre-multi-account) folders

    /// Folders saved before folders became account-scoped. They carry no
    /// `spaceID`, so until they're adopted by an account they would show up in
    /// every account's grid.
    var legacyFolders: [CustomFolder] {
        folders.filter { $0.spaceID == nil }
    }

    /// Hands a legacy folder to a single account.
    func assign(_ folder: CustomFolder, to spaceID: UUID) {
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].spaceID = spaceID
        save()
    }

    /// Creates an account's own copy of a folder. Used when a legacy folder held
    /// documents from more than one account: each account keeps its structure
    /// instead of continuing to share a single folder.
    @discardableResult
    func clone(_ folder: CustomFolder, for spaceID: UUID) -> CustomFolder {
        let copy = CustomFolder(name: folder.name, spaceID: spaceID)
        folders.append(copy)
        save()
        return copy
    }

    func rename(_ folder: CustomFolder, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].name = trimmed
        save()
    }

    func delete(_ folder: CustomFolder) {
        folders.removeAll { $0.id == folder.id }
        save()
    }

    /// Merges cloud folders into the local list (by id) after a reinstall/new
    /// device restore and persists locally — WITHOUT re-enqueuing an upload of
    /// data we just downloaded. Local folders win on id conflict.
    func merge(_ cloudFolders: [CustomFolder]) {
        var byID = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { local, _ in local })
        for folder in cloudFolders where byID[folder.id] == nil {
            byID[folder.id] = folder
            folders.append(folder)
        }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomFolder].self, from: data) else { return }
        folders = decoded
    }

    /// Persists locally and queues an encrypted cloud upload so custom folders
    /// survive an app reinstall (recovered via `performInitialRestore`).
    private func save() {
        persist()
        SyncQueueManager.shared.enqueueCustomFoldersUpload(folders)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

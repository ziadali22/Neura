import Foundation
import Combine

// MARK: - Custom Folder

struct CustomFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
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

    @Published private(set) var folders: [CustomFolder] = []
    private let key = "customFolders_v1"

    private init() { load() }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders.append(CustomFolder(name: trimmed))
        save()
    }

    /// Returns the existing folder matching `name` (case-insensitive) or
    /// creates and persists a new one. Used to auto-file documents that the
    /// user saved without choosing a category or folder.
    @discardableResult
    func findOrCreate(name: String) -> CustomFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = folders.first(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return existing
        }
        let folder = CustomFolder(name: trimmed)
        folders.append(folder)
        save()
        return folder
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

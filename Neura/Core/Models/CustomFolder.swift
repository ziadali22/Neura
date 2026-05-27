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
}

// MARK: - Custom Folder Store

final class CustomFolderStore: ObservableObject {
    static let shared = CustomFolderStore()

    @Published private(set) var folders: [CustomFolder] = []
    private let key = "customFolders_v1"

    private init() { load() }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders.append(CustomFolder(name: trimmed))
        save()
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

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomFolder].self, from: data) else { return }
        folders = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

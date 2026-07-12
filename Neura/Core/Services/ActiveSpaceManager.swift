import Foundation
import Combine
import UIKit

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
        Space(id: defaultSpaceID, name: "Me", isDefault: true)
    }

    // MARK: - Actions

    func setActive(_ spaceID: UUID) {
        guard spaces.contains(where: { $0.id == spaceID }) else { return }
        currentSpaceID = spaceID
    }

    @discardableResult
    func createSpace(name: String, avatarImage: UIImage?) -> Space {
        var space = Space(name: name)
        if let avatarImage {
            space.avatarFilename = AccountAvatarStore.shared.save(avatarImage, for: space.id)
        }
        spaces.append(space)
        save()
        return space
    }

    /// Renames an account and optionally replaces its photo (nil = leave the
    /// existing photo, or lack thereof, unchanged).
    func updateSpace(id: UUID, name: String, avatarImage: UIImage?) {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { return }
        spaces[index].name = name
        if let avatarImage {
            spaces[index].avatarFilename = AccountAvatarStore.shared.save(avatarImage, for: id)
        }
        save()
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

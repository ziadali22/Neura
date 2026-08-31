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
            // DIAGNOSTIC (missing-docs-on-launch): catches any runtime flip of the
            // active space, which would filter every document out of the lists.
            SyncLog.info("currentSpaceID changed \(oldValue.uuidString.prefix(8)) -> \(currentSpaceID.uuidString.prefix(8))")
        }
    }

    private static let spacesKey = "neura_spaces"
    private static let currentSpaceIDKey = "neura_current_space_id"

    /// Non-archived spaces, in creation order, for the switcher UI.
    var visibleSpaces: [Space] {
        spaces.filter { !$0.isArchived }
    }

    /// The currently active (non-archived) space, if it still exists in the list.
    var currentSpace: Space? {
        spaces.first { $0.id == currentSpaceID && !$0.isArchived }
    }

    /// Account names keyed by space id, so surfaces that legitimately span
    /// accounts (expiry reminders, for example) can say which account a piece
    /// of data belongs to instead of showing it unlabelled.
    var namesBySpaceID: [UUID: String] {
        Dictionary(spaces.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private init() {
        var loaded = Self.loadFromDisk()
        if loaded.isEmpty {
            loaded = [Self.makeDefaultSpace()]
            Self.persist(loaded)
        } else {
            let (canonical, didChange) = Self.canonicalizeRelationships(loaded)
            loaded = canonical
            if didChange {
                Self.persist(loaded)
                Task { SyncQueueManager.shared.enqueueSpacesUpload(canonical) }
            }
        }
        self.spaces = loaded

        let savedIDString = UserDefaults.standard.string(forKey: Self.currentSpaceIDKey)
        if let savedIDString,
           let savedID = UUID(uuidString: savedIDString),
           loaded.contains(where: { $0.id == savedID && !$0.isArchived }) {
            self.currentSpaceID = savedID
        } else {
            self.currentSpaceID = Self.defaultSpaceID
        }

        // DIAGNOSTIC (missing-docs-on-launch): shows whether the persisted active
        // space was found among the locally-loaded spaces at launch. A `saved` id
        // that isn't in `loaded` means the fallback to default fired — after which
        // every document tagged to the saved space is filtered out of the lists
        // until the next cold launch (once its space has been merged to disk).
        SyncLog.info("ActiveSpaceManager init — spaces=\(loaded.count) saved=\(savedIDString?.prefix(8).description ?? "nil") resolved=\(currentSpaceID.uuidString.prefix(8))")
    }

    private static func makeDefaultSpace() -> Space {
        Space(id: defaultSpaceID, name: "Me", isDefault: true)
    }

    // MARK: - Actions

    func setActive(_ spaceID: UUID) {
        guard spaces.contains(where: { $0.id == spaceID && !$0.isArchived }) else { return }
        currentSpaceID = spaceID
    }

    /// Applies relationship backfill for spaces created before the field existed.
    /// Safe to call from views — no-ops when everything is already canonical.
    func ensureRelationshipsCanonical() {
        let (canonical, didChange) = Self.canonicalizeRelationships(spaces)
        guard didChange else { return }
        spaces = canonical
        save()
    }

    @discardableResult
    func createSpace(name: String, avatarImage: UIImage?, relationship: String? = nil) -> Space {
        var space = Space(name: name, relationship: relationship)
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
        let before = spaces.count
        for space in cloudSpaces where byID[space.id] == nil {
            byID[space.id] = space
            spaces.append(space)
        }
        Self.persist(spaces)
        // If launch fell back to default because the preferred space wasn't in
        // the local list yet, re-resolve once cloud spaces land. Property observers
        // don't run during init, so UserDefaults still holds the preferred id.
        if let savedIDString = UserDefaults.standard.string(forKey: Self.currentSpaceIDKey),
           let savedID = UUID(uuidString: savedIDString),
           spaces.contains(where: { $0.id == savedID && !$0.isArchived }),
           currentSpaceID != savedID {
            currentSpaceID = savedID
        }
        // DIAGNOSTIC (missing-docs-on-launch): if spaces are appended here AFTER
        // init already fell back to default, that's the race window — the active
        // space existed only in the cloud at launch time.
        SyncLog.info("mergeFromCloud — cloud=\(cloudSpaces.count) localBefore=\(before) localAfter=\(spaces.count) current=\(currentSpaceID.uuidString.prefix(8))")
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

    /// Rewrites legacy localized relationship labels to canonical raw values,
    /// and tags obviously-named child accounts that were created before
    /// relationship was stored.
    private static func canonicalizeRelationships(_ spaces: [Space]) -> ([Space], Bool) {
        var didChange = false
        let updated = spaces.map { space -> Space in
            var space = space
            if let stored = space.relationship,
               let kind = Space.Relationship.canonicalize(stored),
               kind.rawValue != stored {
                space.relationship = kind.rawValue
                didChange = true
            }
            if space.relationship == nil, !space.isDefault, Space.nameSuggestsChild(space.name) {
                space.relationship = Space.Relationship.child.rawValue
                didChange = true
            }
            return space
        }
        return (updated, didChange)
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

import Foundation
import UIKit

/// JPEG storage for account avatar photos, one file per Space id
/// (fixed filename, so re-saving a new photo for the same account overwrites
/// the old one automatically — no orphaned files to clean up). The filename
/// reference travels through Space sync. The image itself is copied to the
/// iCloud backup, not to Firebase.
final class AccountAvatarStore {
    static let shared = AccountAvatarStore()

    private let fileManager = FileManager.default

    private var avatarsDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AccountAvatars", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func resolveURL(for filename: String) -> URL {
        avatarsDirectory.appendingPathComponent(filename)
    }

    @discardableResult
    func save(_ image: UIImage, for spaceID: UUID) -> String? {
        let filename = "\(spaceID.uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: resolveURL(for: filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    func loadImage(filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: resolveURL(for: filename)) else { return nil }
        return UIImage(data: data)
    }

    func delete(filename: String) {
        try? fileManager.removeItem(at: resolveURL(for: filename))
    }

    /// Space ids that have an avatar JPEG on this device.
    func localSpaceIDs() -> [UUID] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: avatarsDirectory.path) else {
            return []
        }
        return names.compactMap { name in
            guard name.lowercased().hasSuffix(".jpg") else { return nil }
            return UUID(uuidString: String(name.dropLast(4)))
        }
    }
}

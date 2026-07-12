import Foundation
import UIKit

/// Local-only JPEG storage for account avatar photos, one file per Space id
/// (fixed filename, so re-saving a new photo for the same account overwrites
/// the old one automatically — no orphaned files to clean up). Mirrors
/// CardBackground's custom-photo storage pattern. Not synced to the cloud —
/// only the filename reference travels through SpaceSyncService.
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
}

import Foundation
import UIKit

/// Local JPEG storage for growth-check photos, one file per measurement id.
final class GrowthPhotoStore {
    static let shared = GrowthPhotoStore()

    private let fileManager = FileManager.default
    private let maxDimension: CGFloat = 1200

    private var photosDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GrowthPhotos", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func filename(for entryID: UUID) -> String {
        "\(entryID.uuidString).jpg"
    }

    func resolveURL(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    func fileExists(for entryID: UUID) -> Bool {
        fileManager.fileExists(atPath: resolveURL(for: filename(for: entryID)).path)
    }

    @discardableResult
    func save(_ image: UIImage, for entryID: UUID) -> String? {
        let resized = resizedImage(image)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let name = filename(for: entryID)
        do {
            try data.write(to: resolveURL(for: name), options: .atomic)
            return name
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

    func delete(for entryID: UUID) {
        delete(filename: filename(for: entryID))
    }

    private func resizedImage(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

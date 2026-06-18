import SwiftUI
import UIKit
import ImageIO

/// Renders a pre-decoded animated GIF image.
/// Pass a `UIImage` decoded off the main thread via `GifImageView.decode(named:)`.
/// Automatically sizes itself to the image's native aspect ratio via sizeThatFits.
struct GifImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.image = image
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image !== image { uiView.image = image }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let ratio = size.height / size.width
        let availableWidth  = proposal.width  ?? UIScreen.main.bounds.width
        let availableHeight = proposal.height ?? .infinity

        let heightIfFitWidth = availableWidth * ratio
        if heightIfFitWidth <= availableHeight {
            return CGSize(width: availableWidth, height: heightIfFitWidth)
        } else {
            return CGSize(width: availableHeight / ratio, height: availableHeight)
        }
    }

    // MARK: - Off-main-thread decoding

    /// Decodes a GIF asset by name on a background thread.
    /// Call from an async context before showing the view.
    static func decode(named name: String) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let data = NSDataAsset(name: name)?.data else { return nil }
            return decodeFrames(from: data)
        }.value
    }

    /// Decodes a GIF from raw Data on whichever thread the caller is on.
    static func decode(data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            decodeFrames(from: data)
        }.value
    }

    // MARK: - Private

    private static func decodeFrames(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }

        var frames: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))

            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gifProps = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gifProps?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                ?? gifProps?[kCGImagePropertyGIFDelayTime] as? Double
                ?? 0.1
            totalDuration += delay
        }

        return UIImage.animatedImage(with: frames, duration: max(totalDuration, 0.1))
    }
}

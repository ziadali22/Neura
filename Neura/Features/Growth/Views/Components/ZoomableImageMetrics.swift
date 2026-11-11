import CoreGraphics

/// Geometry behind `ZoomableImageView`, kept free of UIKit so it can be reasoned about
/// and exercised on its own. Getting `centeredOrigin` wrong is what produces an image
/// you can magnify but never pan to the edges of.
enum ZoomableImageMetrics {
    /// How far past fit scale pinching and double-tap may go.
    static let zoomMultiplier: CGFloat = 3

    /// The scale at which the whole image is visible inside `viewport`.
    ///
    /// Returns nil for degenerate inputs rather than a scale of zero or infinity, so
    /// callers skip configuring the scroll view instead of wedging it.
    static func fitScale(imageSize: CGSize, viewport: CGSize) -> CGFloat? {
        guard imageSize.width > 0, imageSize.height > 0,
              viewport.width > 0, viewport.height > 0 else { return nil }
        return min(viewport.width / imageSize.width, viewport.height / imageSize.height)
    }

    /// Where the image should sit: centred on any axis where it is smaller than the
    /// viewport, flush at zero on any axis where it is larger.
    ///
    /// Pinning to zero once the image overflows is the part that matters — leaving it
    /// centred would offset the content away from the scroll view's pannable range and
    /// make the far edges unreachable.
    static func centeredOrigin(contentSize: CGSize, viewport: CGSize) -> CGPoint {
        CGPoint(
            x: contentSize.width < viewport.width ? (viewport.width - contentSize.width) / 2 : 0,
            y: contentSize.height < viewport.height ? (viewport.height - contentSize.height) / 2 : 0
        )
    }

    /// The rect to zoom to when double-tapping at `point`, expressed in the image's own
    /// unzoomed coordinate space, which is what `UIScrollView.zoom(to:)` expects.
    static func zoomTarget(around point: CGPoint, viewport: CGSize, scale: CGFloat) -> CGRect {
        guard scale > 0 else { return CGRect(origin: point, size: .zero) }
        let size = CGSize(width: viewport.width / scale, height: viewport.height / scale)
        return CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

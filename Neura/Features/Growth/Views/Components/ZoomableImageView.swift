import SwiftUI
import UIKit

/// A pinch-zoomable, pannable image backed by `UIScrollView`.
///
/// UIKit is doing the work deliberately: `UIScrollView` gives bounded panning, edge
/// bouncing and re-centring for free. Driving zoom from SwiftUI gestures instead means
/// reimplementing all of that, and getting it wrong produces an image you can magnify
/// but never pan to the edges of.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    /// Reports whether the image is magnified past its fit scale, so the presenter can
    /// stand down gestures that would otherwise fight with panning.
    @Binding var isZoomed: Bool

    func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.setImage(image)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.report = { $isZoomed.wrappedValue = $0 }
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableScrollView, context: Context) {
        // Only re-seed on a genuine image change. Re-seeding on every SwiftUI update
        // would snap the photo back to fit scale mid-pinch.
        if scrollView.displayedImage !== image {
            scrollView.setImage(image)
        }
        context.coordinator.report = { $isZoomed.wrappedValue = $0 }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var report: ((Bool) -> Void)?
        private var lastReported: Bool?

        /// Deferred to the next runloop turn: these fire from inside scroll-view layout,
        /// and writing SwiftUI state there trips "modifying state during view update".
        fileprivate func reportZoom(_ zoomed: Bool) {
            guard lastReported != zoomed else { return }
            lastReported = zoomed
            let report = report
            DispatchQueue.main.async { report?(zoomed) }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomableScrollView)?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let zoomable = scrollView as? ZoomableScrollView else { return }
            zoomable.centerImage()
            reportZoom(zoomable.isMagnified)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? ZoomableScrollView else { return }
            scrollView.toggleZoom(at: gesture.location(in: scrollView.imageView))
            reportZoom(scrollView.isMagnified)
        }
    }
}

// MARK: - Scroll view

/// Sizes its image view to the image's own pixel dimensions and uses the scroll view's
/// zoom scale to fit it, which is what keeps panning bounded to the actual photo.
final class ZoomableScrollView: UIScrollView {
    let imageView = UIImageView()
    private(set) var displayedImage: UIImage?
    private var lastBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var isMagnified: Bool {
        zoomScale > minimumZoomScale * 1.01
    }

    func setImage(_ image: UIImage) {
        displayedImage = image
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size
        lastBoundsSize = .zero  // force the fit scale to be recomputed on next layout
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastBoundsSize, bounds.width > 0, bounds.height > 0 else {
            centerImage()
            return
        }
        lastBoundsSize = bounds.size
        applyFitScale()
    }

    /// Recomputes the scale at which the whole photo is visible, and snaps to it.
    private func applyFitScale() {
        guard let size = displayedImage?.size,
              let fit = ZoomableImageMetrics.fitScale(imageSize: size, viewport: bounds.size)
        else { return }
        minimumZoomScale = fit
        maximumZoomScale = fit * ZoomableImageMetrics.zoomMultiplier
        zoomScale = fit
        centerImage()
    }

    func centerImage() {
        var frame = imageView.frame
        frame.origin = ZoomableImageMetrics.centeredOrigin(
            contentSize: frame.size,
            viewport: bounds.size
        )
        imageView.frame = frame
    }

    func toggleZoom(at point: CGPoint) {
        guard !isMagnified else {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        zoom(
            to: ZoomableImageMetrics.zoomTarget(
                around: point,
                viewport: bounds.size,
                scale: maximumZoomScale
            ),
            animated: true
        )
    }
}

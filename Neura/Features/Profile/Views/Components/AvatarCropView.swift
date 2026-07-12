import SwiftUI

struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 300
    private let outputSize: CGFloat = 400
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropDiameter, height: cropDiameter)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .gesture(
                            SimultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in lastOffset = offset },
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = min(max(lastScale * value, minScale), maxScale)
                                    }
                                    .onEnded { _ in lastScale = scale }
                            )
                        )
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel, action: onCancel)
                        .tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { onConfirm(renderCroppedImage()) }
                        .tint(.white)
                }
            }
        }
    }

    /// Replicates the on-screen `.scaledToFill()` + gesture scale/offset math
    /// against a fixed-size output, so what the user sees inside the circle
    /// is what gets saved.
    private func renderCroppedImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { _ in
            let clipPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
            clipPath.addClip()

            let ratio = outputSize / cropDiameter
            let imageSize = image.size
            let baseFillScale = max(cropDiameter / imageSize.width, cropDiameter / imageSize.height)
            let drawSize = CGSize(
                width: imageSize.width * baseFillScale * scale * ratio,
                height: imageSize.height * baseFillScale * scale * ratio
            )
            let drawOrigin = CGPoint(
                x: outputSize / 2 - drawSize.width / 2 + offset.width * ratio,
                y: outputSize / 2 - drawSize.height / 2 + offset.height * ratio
            )
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }
}

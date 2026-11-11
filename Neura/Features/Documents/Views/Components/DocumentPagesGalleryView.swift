import SwiftUI

/// Full-screen pager for scanned document pages, matching the growth photo gallery:
/// pinch to zoom, swipe between pages, drag down to close.
struct DocumentPagesGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    let pages: [ScannedPage]
    @State private var selectedID: UUID
    /// Which page is magnified, rather than a shared flag. One `isZoomed` for the whole
    /// gallery lets a page scrolling away reset the flag for the page arriving, which
    /// re-arms drag-to-dismiss on a photo that is still zoomed in.
    @State private var zoomedID: UUID?
    @State private var dragOffset: CGFloat = 0

    /// Vertical travel that commits to a dismissal.
    private let dismissThreshold: CGFloat = 120

    /// Only the page on screen can be zoomed, so pages left magnified behind you keep
    /// their state without arming or disarming anything here.
    private var isZoomed: Bool { zoomedID == selectedID }

    init(pages: [ScannedPage], initialID: UUID) {
        self.pages = pages
        let fallback = pages.first?.id ?? initialID
        self._selectedID = State(
            initialValue: pages.contains(where: { $0.id == initialID }) ? initialID : fallback
        )
    }

    var body: some View {
        ZStack {
            // The backdrop stays put and stays opaque. Offsetting or fading it would
            // expose the cover's own system background, not the form underneath.
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedID) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    DocumentPhotoPage(
                        page: page,
                        pageNumber: index + 1,
                        pageCount: pages.count,
                        zoomedID: $zoomedID
                    )
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .offset(y: dragOffset)
            .opacity(draggedOpacity)

            overlay
                .offset(y: dragOffset)
                .opacity(draggedOpacity)
        }
        // Simultaneous, so the pager keeps its own horizontal gesture. Vertical intent
        // is filtered inside the handler rather than by excluding the pager's gesture.
        .simultaneousGesture(dismissDrag)
        .statusBarHidden()
    }

    /// Dims the photo as it travels, so a partial drag reads as "this is closing".
    private var draggedOpacity: Double {
        max(0.4, 1 - Double(abs(dragOffset)) / 500)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isZoomed else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    dragOffset = 0
                    return
                }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                guard !isZoomed, abs(value.translation.height) > abs(value.translation.width) else {
                    resetDrag()
                    return
                }
                if abs(value.translation.height) > dismissThreshold {
                    dismiss()
                } else {
                    resetDrag()
                }
            }
    }

    private func resetDrag() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
    }

    @ViewBuilder
    private var overlay: some View {
        VStack {
            HStack {
                closeButton
                Spacer()
            }
            Spacer()
            caption
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(isZoomed ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: isZoomed)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.45), in: Circle())
        }
        .accessibilityLabel(L10n.Common.close)
    }

    @ViewBuilder
    private var caption: some View {
        VStack(spacing: 12) {
            if let index = pages.firstIndex(where: { $0.id == selectedID }) {
                Text(L10n.Documents.Metadata.pageOf(index + 1, pages.count))
                    .font(.headingXS)
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                    .accessibilityHidden(true)
            }

            if pages.count > 1 {
                pageIndicator
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
    }

    /// Dots while they stay countable at a glance, a counter once they don't.
    @ViewBuilder
    private var pageIndicator: some View {
        if pages.count <= 8 {
            HStack(spacing: 8) {
                ForEach(pages) { page in
                    Circle()
                        .fill(page.id == selectedID ? Color.accent : Color.white.opacity(0.4))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
        } else if let index = pages.firstIndex(where: { $0.id == selectedID }) {
            Text("\(index + 1) / \(pages.count)")
                .font(.captionS)
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Page

private struct DocumentPhotoPage: View {
    let page: ScannedPage
    let pageNumber: Int
    let pageCount: Int
    @Binding var zoomedID: UUID?

    /// Reports zoom under this page's own identity, so it can never speak for another.
    private var isZoomed: Binding<Bool> {
        Binding(
            get: { zoomedID == page.id },
            set: { zoomed in
                if zoomed {
                    zoomedID = page.id
                } else if zoomedID == page.id {
                    zoomedID = nil
                }
            }
        )
    }

    var body: some View {
        ZoomableImageView(image: page.image, isZoomed: isZoomed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(L10n.Documents.Metadata.pageOf(pageNumber, pageCount))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Multiple pages") {
    let pages = [
        ScannedPage(image: UIImage(systemName: "doc.fill")!),
        ScannedPage(image: UIImage(systemName: "photo")!)
    ]
    return DocumentPagesGalleryView(pages: pages, initialID: pages[1].id)
}

#Preview("Single page") {
    let page = ScannedPage(image: UIImage(systemName: "doc.fill")!)
    return DocumentPagesGalleryView(pages: [page], initialID: page.id)
}
#endif

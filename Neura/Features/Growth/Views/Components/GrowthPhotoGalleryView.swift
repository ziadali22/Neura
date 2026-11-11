import SwiftUI

/// Full-screen photo viewer for growth entries, paged oldest to newest so swiping
/// forward reads as the child growing.
struct GrowthPhotoGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    let entries: [GrowthEntry]
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

    init(entries: [GrowthEntry], initialID: UUID) {
        self.entries = entries
        self._selectedID = State(initialValue: initialID)
    }

    var body: some View {
        ZStack {
            // The backdrop stays put and stays opaque. Offsetting or fading it would
            // expose the cover's own system background, not the card underneath.
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedID) {
                ForEach(entries) { entry in
                    GrowthPhotoPage(entry: entry, zoomedID: $zoomedID)
                        .tag(entry.id)
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
                // Zoomed in, every drag belongs to panning the photo.
                guard !isZoomed else { return }
                // Drags the pager owns: hand the photo back rather than leaving it
                // stranded at whatever offset a vertical start had already applied.
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
        // Chrome recedes while zoomed so it doesn't sit on top of the detail being examined.
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
            if let entry = entries.first(where: { $0.id == selectedID }) {
                Text(entry.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.headingXS)
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
            }

            if entries.count > 1 {
                pageIndicator
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
    }

    /// Dots while they stay countable at a glance, a counter once they don't.
    @ViewBuilder
    private var pageIndicator: some View {
        if entries.count <= 8 {
            HStack(spacing: 8) {
                ForEach(entries) { entry in
                    Circle()
                        .fill(entry.id == selectedID ? Color.accent : Color.white.opacity(0.4))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
        } else if let index = entries.firstIndex(where: { $0.id == selectedID }) {
            Text("\(index + 1) / \(entries.count)")
                .font(.captionS)
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
        }
    }
}

// MARK: - Page

/// One photo. Loads off the main thread so paging doesn't stutter on JPEG decode.
private struct GrowthPhotoPage: View {
    let entry: GrowthEntry
    @Binding var zoomedID: UUID?

    @State private var image: UIImage?
    @State private var didFail = false

    /// Reports zoom under this page's own identity, so it can never speak for another.
    private var isZoomed: Binding<Bool> {
        Binding(
            get: { zoomedID == entry.id },
            set: { zoomed in
                if zoomed {
                    zoomedID = entry.id
                } else if zoomedID == entry.id {
                    zoomedID = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            if let image {
                ZoomableImageView(image: image, isZoomed: isZoomed)
            } else if didFail {
                Image(systemName: "photo")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .accessibilityLabel(L10n.Growth.photo)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: entry.id) { await load() }
    }

    private func load() async {
        guard image == nil, let filename = entry.photoFilename else {
            if entry.photoFilename == nil { didFail = true }
            return
        }
        let url = GrowthPhotoStore.shared.resolveURL(for: filename)
        let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value

        guard !Task.isCancelled else { return }
        if let loaded {
            image = loaded
        } else {
            didFail = true
        }
    }
}

// MARK: - Previews

#if DEBUG
private func galleryPreviewEntry(_ day: Int, _ cm: Int, _ kg: Double) -> GrowthEntry {
    let date = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: day)) ?? Date()
    return GrowthEntry(date: date, heightCm: cm, weightKg: kg, photoFilename: "missing-\(day).jpg")
}

// Photo files are absent in previews, so these exercise chrome, paging and the
// failed-load state rather than real images.
#Preview("Multiple photos") {
    let entries = [galleryPreviewEntry(3, 50, 24), galleryPreviewEntry(22, 55, 26.5)]
    return GrowthPhotoGalleryView(entries: entries, initialID: entries[1].id)
}

#Preview("Single photo") {
    let entries = [galleryPreviewEntry(22, 55, 26.5)]
    return GrowthPhotoGalleryView(entries: entries, initialID: entries[0].id)
}

#Preview("Counter instead of dots") {
    let entries = (1...10).map { galleryPreviewEntry($0, 50 + $0, 24) }
    return GrowthPhotoGalleryView(entries: entries, initialID: entries[4].id)
}
#endif

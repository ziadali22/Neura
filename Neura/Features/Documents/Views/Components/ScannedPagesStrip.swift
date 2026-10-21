import SwiftUI
import UniformTypeIdentifiers

/// Horizontal thumbnail strip on Document Details: tap to preview, hold to reorder.
struct ScannedPagesStrip: View {
    @Binding var pages: [ScannedPage]
    var onPreview: (UUID) -> Void
    var onAdd: () -> Void

    @State private var draggingID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    ScannedPageThumbnail(
                        page: page,
                        index: index,
                        pageCount: pages.count,
                        isDragging: draggingID == page.id,
                        onPreview: { onPreview(page.id) },
                        onDelete: { delete(page) },
                        onMoveEarlier: { move(page, later: false) },
                        onMoveLater: { move(page, later: true) }
                    )
                    .modifier(PageReorderDrag(
                        enabled: pages.count > 1,
                        page: page,
                        pages: $pages,
                        draggingID: $draggingID
                    ))
                }

                addButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 6) // room for the close button's negative offset
        }
        .padding(.horizontal, -20)
        .onDrop(
            of: [UTType.text],
            delegate: ScannedPageDragEndDelegate(draggingID: $draggingID)
        )
    }

    private var addButton: some View {
        Button(action: onAdd) {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accent, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accent.opacity(0.06))
                )
                .frame(width: 90, height: 120)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.accent)
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n.Documents.Metadata.addPage)
        .onDrop(
            of: [UTType.text],
            delegate: ScannedPageAppendDropDelegate(pages: $pages, draggingID: $draggingID)
        )
    }

    private func delete(_ page: ScannedPage) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pages.removeAll { $0.id == page.id }
        }
        if draggingID == page.id { draggingID = nil }
    }

    private func move(_ page: ScannedPage, later: Bool) {
        guard let from = pages.firstIndex(where: { $0.id == page.id }) else { return }
        let to = later ? from + 1 : from - 1
        guard pages.indices.contains(to) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pages.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
        HapticManager.selection()
    }
}

// MARK: - Thumbnail

private struct ScannedPageThumbnail: View {
    let page: ScannedPage
    let index: Int
    let pageCount: Int
    let isDragging: Bool
    var onPreview: () -> Void
    var onDelete: () -> Void
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onPreview) {
                Image(uiImage: page.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.stroke, lineWidth: 1)
                    }
                    .overlay(alignment: .bottomLeading) {
                        pageBadge
                    }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(L10n.Documents.Naming.page(index + 1))
            .accessibilityHint(
                pageCount > 1
                    ? L10n.Documents.Metadata.reorderHint
                    : L10n.Documents.Metadata.previewHint
            )
            .modifier(PageReorderAccessibility(
                canMoveEarlier: index > 0,
                canMoveLater: index < pageCount - 1,
                onMoveEarlier: onMoveEarlier,
                onMoveLater: onMoveLater
            ))

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .zIndex(1)
            .accessibilityLabel(L10n.Documents.Metadata.deletePage(index + 1))
        }
        .opacity(isDragging ? 0.45 : 1)
        .accessibilityElement(children: .contain)
    }

    private var pageBadge: some View {
        Text("\(index + 1)")
            .font(.captionS)
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(6)
            .accessibilityHidden(true)
    }
}

private struct PageReorderAccessibility: ViewModifier {
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        switch (canMoveEarlier, canMoveLater) {
        case (true, true):
            content
                .accessibilityAction(named: L10n.Documents.Metadata.moveEarlier, onMoveEarlier)
                .accessibilityAction(named: L10n.Documents.Metadata.moveLater, onMoveLater)
        case (true, false):
            content.accessibilityAction(named: L10n.Documents.Metadata.moveEarlier, onMoveEarlier)
        case (false, true):
            content.accessibilityAction(named: L10n.Documents.Metadata.moveLater, onMoveLater)
        case (false, false):
            content
        }
    }
}

/// Hold-to-drag is only armed when there are at least two pages, so a single
/// thumbnail still opens on a short tap without waiting out the drag delay.
private struct PageReorderDrag: ViewModifier {
    let enabled: Bool
    let page: ScannedPage
    @Binding var pages: [ScannedPage]
    @Binding var draggingID: UUID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingID = page.id
                    return NSItemProvider(object: page.id.uuidString as NSString)
                } preview: {
                    Image(uiImage: page.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ScannedPageDropDelegate(
                        targetID: page.id,
                        pages: $pages,
                        draggingID: $draggingID
                    )
                )
        } else {
            content
        }
    }
}

// MARK: - Drop delegates

/// Live-reorders as the drag hovers each thumbnail.
private struct ScannedPageDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var pages: [ScannedPage]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID,
              let from = pages.firstIndex(where: { $0.id == draggingID }),
              let to = pages.firstIndex(where: { $0.id == targetID }),
              from != to
        else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pages.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
        HapticManager.selection()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// Dropping on the add-page tile sends the dragged page to the end.
private struct ScannedPageAppendDropDelegate: DropDelegate {
    @Binding var pages: [ScannedPage]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              let from = pages.firstIndex(where: { $0.id == draggingID }),
              from != pages.count - 1
        else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pages.move(fromOffsets: IndexSet(integer: from), toOffset: pages.count)
        }
        HapticManager.selection()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// Clears drag chrome if the session ends over the strip rather than a tile.
private struct ScannedPageDragEndDelegate: DropDelegate {
    @Binding var draggingID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

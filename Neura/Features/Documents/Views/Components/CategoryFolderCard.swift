import SwiftUI

// MARK: - Expandable Folder Card

struct CategoryFolderCard: View {
    let category: DocumentCategory
    let documents: [Document]

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spring: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.15)
            : .spring(response: 0.35, dampingFraction: 0.82)
    }

    var body: some View {
        VStack(spacing: 0) {
            FolderCardHeader(
                category: category,
                count: documents.count,
                isExpanded: isExpanded
            ) {
                withAnimation(spring) { isExpanded.toggle() }
            }

            if isExpanded {
                if documents.isEmpty {
                    FolderCardEmptyState()
                        .transition(.opacity)
                } else {
                    FolderCardDocumentList(documents: documents)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .move(edge: .top))
                        )
                }
            }
        }
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isExpanded ? category.color.opacity(0.35) : Color.stroke,
                    lineWidth: 1
                )
        }
        .shadow(
            color: isExpanded ? category.color.opacity(0.10) : .black.opacity(0.04),
            radius: isExpanded ? 14 : 6,
            x: 0,
            y: isExpanded ? 6 : 2
        )
        .animation(spring, value: isExpanded)
    }
}

// MARK: - Header

private struct FolderCardHeader: View {
    let category: DocumentCategory
    let count: Int
    let isExpanded: Bool
    let onTap: () -> Void

    @ScaledMetric private var iconSize: CGFloat = 52

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                categoryIcon
                    .frame(width: iconSize, height: iconSize)
                    .background(category.color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: iconSize * 0.27))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.localizedName)
                        .font(.headingXS)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("^[\(count) document](inflect: true)")
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                "\(category.localizedName), ^[\(count) document](inflect: true), \(isExpanded ? "collapse" : "expand")"
            )
        )
    }

    private var categoryIcon: some View {
        Image(category.gridIcon)
            .resizable()
            .scaledToFit()
            .padding(10)
    }
}

// MARK: - Document List

private struct FolderCardDocumentList: View {
    let documents: [Document]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            ForEach(documents) { document in
                NavigationLink(value: document) {
                    FolderDocumentRow(document: document)
                }
                .buttonStyle(.plain)

                if document.id != documents.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
    }
}

// MARK: - Document Row

private struct FolderDocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.isImage ? "photo.fill" : "doc.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(document.name)
                    .font(.captionS)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(document.createdAt, format: .dateTime.day().month(.abbreviated).year())
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
        .accessibilityLabel(
            Text(
                "\(document.name), \(document.createdAt, format: .dateTime.day().month(.abbreviated).year())"
            )
        )
    }
}

// MARK: - Empty State

private struct FolderCardEmptyState: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            Text(L10n.Documents.Category.noDocumentsYet)
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)
                .padding(16)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            ForEach(DocumentCategory.allCases) { cat in
                CategoryFolderCard(category: cat, documents: [])
            }
        }
        .padding(20)
    }
    .background(Color.backgroundPrimary)
}

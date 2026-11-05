import SwiftUI

struct DocsFilesView<TopContent: View>: View {
    @ObservedObject var viewModel: DocumentsListViewModel
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Binding var isSelecting: Bool
    @Binding var selectedDocuments: Set<UUID>
    @Binding var showFilters: Bool
    let onAddDocument: () -> Void
    private let topContent: TopContent

    init(
        viewModel: DocumentsListViewModel,
        isSelecting: Binding<Bool>,
        selectedDocuments: Binding<Set<UUID>>,
        showFilters: Binding<Bool>,
        onAddDocument: @escaping () -> Void,
        @ViewBuilder topContent: () -> TopContent
    ) {
        self.viewModel = viewModel
        self._isSelecting = isSelecting
        self._selectedDocuments = selectedDocuments
        self._showFilters = showFilters
        self.onAddDocument = onAddDocument
        self.topContent = topContent()
    }

    var body: some View {
        if viewModel.spaceScopedDocuments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                topContent
                DocsEmptyState(onAddDocument: onAddDocument)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topContent

                    if !isSelecting {
                        filterBar
                    }

                    documentsList
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 10) {
            Button { showFilters = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .medium))
                    Text(L10n.Documents.Filter.button)
                        .font(.labelM)
                    if viewModel.activeFilterCount > 0 {
                        Text("\(viewModel.activeFilterCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.accent)
                            .clipShape(Circle())
                    }
                }
                .foregroundStyle(viewModel.activeFilterCount > 0 ? Color.accent : Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.activeFilterCount > 0 ? Color.accent.opacity(0.1) : Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 8))
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            }

            if let category = viewModel.selectedCategoryFilter {
                HStack(spacing: 4) {
                    Text(category.localizedName)
                        .font(.labelM)
                    Button {
                        withAnimation { viewModel.selectedCategoryFilter = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.stroke, lineWidth: 1)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelecting = true
                }
            } label: {
                Text(L10n.Documents.select)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Documents List

    @ViewBuilder
    private var documentsList: some View {
        let sections = viewModel.groupedDocuments
        if sections.isEmpty {
            ContentUnavailableView {
                VStack(spacing: 16) {
                    Image("search")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)

                    Text(viewModel.activeFilterCount > 0 ? L10n.Documents.noMatchingTitle : L10n.Documents.noDocumentsTitle)
                        .font(.headingS)
                        .foregroundStyle(Color.textPrimary)
                }
            } description: {
                Text(
                    viewModel.activeFilterCount > 0
                        ? L10n.Documents.noMatchingMessage
                        : L10n.Documents.noDocumentsMessage
                )
                .font(.bodyS)
            }
        } else {
            LazyVStack(spacing: 20) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            ForEach(section.documents) { document in
                                let locked = viewModel.isLocked(document)

                                if isSelecting {
                                    if locked {
                                        // Locked docs are visible but not selectable
                                        DocumentListRow(
                                            document: document,
                                            isLocked: true,
                                            onUnlock: { viewModel.showPaywall = true }
                                        )
                                    } else {
                                        Button { toggleSelection(document) } label: {
                                            DocumentListRow(
                                                document: document,
                                                isSelecting: true,
                                                isSelected: selectedDocuments.contains(document.id)
                                            )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                } else {
                                    if locked {
                                        DocumentListRow(
                                            document: document,
                                            isLocked: true,
                                            onUnlock: { viewModel.showPaywall = true }
                                        )
                                    } else {
                                        NavigationLink(value: document) {
                                            DocumentListRow(document: document)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Selection Helpers

    private func toggleSelection(_ document: Document) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if selectedDocuments.contains(document.id) {
                selectedDocuments.remove(document.id)
            } else {
                selectedDocuments.insert(document.id)
            }
        }
    }
}

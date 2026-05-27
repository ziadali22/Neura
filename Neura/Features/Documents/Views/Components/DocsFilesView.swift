import SwiftUI

struct DocsFilesView: View {
    @ObservedObject var viewModel: DocumentsListViewModel
    @Binding var isSelecting: Bool
    @Binding var selectedDocuments: Set<UUID>
    @Binding var showFilters: Bool
    let onAddDocument: () -> Void

    var body: some View {
        if viewModel.documents.isEmpty {
            DocsEmptyState(onAddDocument: onAddDocument)
        } else {
            VStack(spacing: 0) {
                // Show selected count row when in selection mode
                if isSelecting {
                    selectedCountRow
                }

                // Filter bar only when not selecting
                if !isSelecting {
                    filterBar
                }

                documentsList
            }
        }
    }

    // MARK: - Selected Count Row

    private var selectedCountRow: some View {
        HStack {
            Text(selectedDocuments.isEmpty
                 ? "None Selected"
                 : "\(selectedDocuments.count) Selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 10) {
            Button { showFilters = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .medium))
                    Text("Filter")
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
                    Image(systemName: category.icon)
                        .font(.system(size: 12))
                    Text(category.localizedName)
                        .font(.labelM)
                    Button {
                        withAnimation { viewModel.selectedCategoryFilter = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accent.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelecting = true
                }
            } label: {
                Text("Select")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Documents List

    @ViewBuilder
    private var documentsList: some View {
        let sections = viewModel.groupedDocuments
        if sections.isEmpty {
            ContentUnavailableView(
                viewModel.activeFilterCount > 0 ? "No Matching Documents" : "No Documents",
                systemImage: viewModel.activeFilterCount > 0 ? "doc.text.magnifyingglass" : "doc.badge.plus",
                description: Text(
                    viewModel.activeFilterCount > 0
                        ? "Try adjusting your filters."
                        : "Scan or upload your first medical document."
                )
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 8) {
                                ForEach(section.documents) { document in
                                    if isSelecting {
                                        Button { toggleSelection(document) } label: {
                                            DocumentListRow(
                                                document: document,
                                                isSelecting: true,
                                                isSelected: selectedDocuments.contains(document.id)
                                            )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
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
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
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

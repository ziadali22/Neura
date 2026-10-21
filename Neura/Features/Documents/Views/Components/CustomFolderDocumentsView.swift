import SwiftUI

struct CustomFolderDocumentsView: View {
    let folder: CustomFolder
    @ObservedObject var viewModel: DocumentsListViewModel
    @ObservedObject private var folderStore = CustomFolderStore.shared

    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedDocuments: Set<UUID> = []
    @State private var showDeleteAlert = false

    private var documents: [Document] {
        viewModel.spaceScopedDocuments
            .filter { $0.tags?.contains(folder.id.uuidString) == true }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty else { return documents }
        let query = searchText.lowercased()
        return documents.filter { $0.name.lowercased().contains(query) }
    }

    private var monthSections: [MonthSection] {
        let calendar = Calendar.current
        var groups: [Date: [Document]] = [:]
        for doc in filteredDocuments {
            let comps = calendar.dateComponents([.year, .month], from: doc.createdAt)
            if let monthStart = calendar.date(from: comps) {
                groups[monthStart, default: []].append(doc)
            }
        }
        return groups.map { date, docs in
            MonthSection(
                date: date,
                title: date.formatted(.dateTime.month(.wide).year()),
                documents: docs.sorted { $0.createdAt > $1.createdAt }
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var currentName: String {
        folderStore.folders.first(where: { $0.id == folder.id })?.displayName ?? folder.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSelecting {
                selectionHeader
            }

            if documents.isEmpty {
                folderEmptyState
            } else {
                VStack(spacing: 0) {
                    searchBar

                    if isSelecting {
                        selectedCountRow
                    }

                    documentsList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(isSelecting ? "" : currentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !documents.isEmpty && !isSelecting {
                toolbarContent
            }
        }
        .overlay(alignment: .bottom) {
            if isSelecting && !selectedDocuments.isEmpty {
                DocsSelectionBar(
                    onDelete: { showDeleteAlert = true },
                    onShare: shareSelected
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSelecting)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedDocuments.isEmpty)
        .onAppear { viewModel.folderContext = .customFolder(folder.id) }
        .onDisappear {
            if viewModel.folderContext == .customFolder(folder.id) {
                viewModel.folderContext = nil
            }
        }
        .alert(
            L10n.Documents.deleteAlertTitle(selectedDocuments.count),
            isPresented: $showDeleteAlert
        ) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive, action: deleteSelected)
        } message: {
            Text(L10n.Common.thisActionCannotBeUndone)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                viewModel.showAddOptions(destination: .customFolder(folder.id))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accent)
            }
            .accessibilityLabel(L10n.Documents.addDocument)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelecting = true
                }
            } label: {
                Text(L10n.Documents.select)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accent)
            }
        }
    }

    // MARK: - Selection Header (replaces nav bar in selection mode)

    private var selectionHeader: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    let allIDs = Set(filteredDocuments
                        .filter { !viewModel.isLocked($0) }
                        .map(\.id))
                    if !allIDs.isEmpty && allIDs.isSubset(of: selectedDocuments) {
                        selectedDocuments.removeAll()
                    } else {
                        selectedDocuments = allIDs
                    }
                }
            } label: {
                Text(L10n.Documents.selectAll)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.surfaceWhite)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Text(selectedDocuments.isEmpty ? currentName : L10n.Documents.selectedCount(selectedDocuments.count))
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedDocuments.count)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelecting = false
                    selectedDocuments.removeAll()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
            .accessibilityLabel(L10n.Documents.done)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
                .font(.system(size: 15))
            TextField(L10n.Documents.searchPlaceholder, text: $searchText)
                .font(.bodyL)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Selected Count Row

    private var selectedCountRow: some View {
        HStack {
            Text(selectedDocuments.isEmpty ? L10n.Documents.noneSelected : L10n.Documents.selected(selectedDocuments.count))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Documents List

    private var documentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(monthSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headingXS)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            ForEach(section.documents) { document in
                                documentRow(document)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private func documentRow(_ document: Document) -> some View {
        let locked = viewModel.isLocked(document)

        if isSelecting {
            if locked {
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
        } else if locked {
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

    // MARK: - Empty State

    private var folderEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "folder.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accent)

            VStack(spacing: 8) {
                Text(L10n.Documents.Folder.noDocuments)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Documents.Folder.emptyDescriptionFormat(currentName))
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                viewModel.showAddOptions(destination: .customFolder(folder.id))
            } label: {
                Text(L10n.Documents.addDocument)
                    .font(.buttonM)
                    .foregroundStyle(.white)
                    .frame(width: 190)
                    .padding(.vertical, 14)
                    .background(Color.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ document: Document) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if selectedDocuments.contains(document.id) {
                selectedDocuments.remove(document.id)
            } else {
                selectedDocuments.insert(document.id)
            }
        }
    }

    private func deleteSelected() {
        let toDelete = viewModel.spaceScopedDocuments.filter { selectedDocuments.contains($0.id) }
        for doc in toDelete { viewModel.deleteDocument(doc) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            selectedDocuments.removeAll()
            isSelecting = false
        }
    }

    private func shareSelected() {
        let urls = viewModel.spaceScopedDocuments
            .filter { selectedDocuments.contains($0.id) && $0.fileExists }
            .map(\.fileURL)
        guard !urls.isEmpty else { return }
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let root = windowScene.keyWindow?.rootViewController {
            var topVC = root
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Month Section

private struct MonthSection: Identifiable {
    var id: Date { date }
    let date: Date
    let title: String
    let documents: [Document]
}

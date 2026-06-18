import SwiftUI

struct CategoryDocumentsView: View {
    let category: DocumentCategory
    @ObservedObject var viewModel: DocumentsListViewModel
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedDocuments: Set<UUID> = []
    @State private var showDeleteAlert = false

    private var documents: [Document] {
        viewModel.documents
            .filter { $0.category == category }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty else { return documents }
        let query = searchText.lowercased()
        return documents.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSelecting {
                selectionHeader
            }

            if documents.isEmpty {
                categoryEmptyState
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
        .navigationTitle(isSelecting ? "" : category.localizedName)
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
        .alert(
            "Delete \(selectedDocuments.count) Document\(selectedDocuments.count == 1 ? "" : "s")?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteSelected)
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelecting = true
                }
            } label: {
                Text("Select")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accent)
            }
        }
    }

    // MARK: - Selection Header (replaces nav bar in selection mode)

    private var selectionHeader: some View {
        HStack {
            // Select All
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    // Exclude locked documents from bulk selection
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
                Text("Select All")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.surfaceWhite)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Text(selectedDocuments.isEmpty ? category.localizedName : "\(selectedDocuments.count) Items")
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedDocuments.count)

            Spacer()

            // Done
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
            TextField("Search documents", text: $searchText)
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

    // MARK: - Selected Count Row (selection mode)

    private var selectedCountRow: some View {
        HStack {
            Text(selectedDocuments.isEmpty ? "None Selected" : "\(selectedDocuments.count) Selected")
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
            LazyVStack(spacing: 10) {
                ForEach(filteredDocuments) { document in
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
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State

    private var categoryEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            if let assetName = category.assetIcon {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
            } else {
                Image(systemName: category.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(category.color)
            }

            VStack(spacing: 8) {
                Text("No \(category.localizedName)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Scan or upload a document and tag it as \(category.localizedName).")
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                viewModel.showAddOptions()
            } label: {
                Text("Add document")
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
        let toDelete = viewModel.documents.filter { selectedDocuments.contains($0.id) }
        for doc in toDelete { viewModel.deleteDocument(doc) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDocuments.removeAll()
            isSelecting = false
        }
    }

    private func shareSelected() {
        let urls = viewModel.documents
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

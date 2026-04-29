import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - View Mode

private enum DocViewMode: CaseIterable {
    case all, folders

    var label: String {
        switch self {
        case .folders: "Folders"
        case .all: "All"
        }
    }
}

// MARK: - DocsView

struct DocsView: View {
    @StateObject private var viewModel = DocumentsListViewModel()
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var viewMode: DocViewMode = .all
    @State private var showFilters = false
    @State private var isSelecting = false
    @State private var selectedDocuments: Set<UUID> = []
    @State private var showDeleteSelectedAlert = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Inline header: title + selection buttons
                HStack(alignment: .center) {
                    Text("Documents")
                        .font(.displayXL)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    if isSelecting {
                        Button(allSelected ? "Deselect All" : "Select All", action: toggleSelectAll)
                            .foregroundStyle(Color.accent)
                            .font(.system(size: 15, weight: .medium))
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    if isSelecting || (viewMode == .all && !viewModel.filteredDocuments.isEmpty) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelecting.toggle()
                                if !isSelecting { selectedDocuments.removeAll() }
                            }
                        }
                        .foregroundStyle(Color.accent)
                        .font(.system(size: 15, weight: .medium))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelecting)

                segmentControl

                // Mode content

                ZStack {
                    if viewMode == .folders {
                        categoriesGrid
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 0) {

                            searchBar
                            if !viewModel.documents.isEmpty {
                                filterBar
                            }
                            documentsList
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: viewMode)
            }
            .background(Color.backgroundPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DocumentCategory.self) { category in
                CategoryDocumentsView(category: category, viewModel: viewModel)
            }
            .navigationDestination(for: Document.self) { document in
                DocumentViewerView(document: document, onDelete: {
                    viewModel.deleteDocument(document)
                }, onRename: { newName in
                    viewModel.renameDocument(document, to: newName)
                })
            }
            .overlay { ScanProcessingView(isProcessing: viewModel.isProcessing) }
            .sheet(isPresented: $viewModel.showSourcePicker) {
                AddDocumentSheet(
                    onScan: { viewModel.startScanning() },
                    onPhoto: { viewModel.startPhotoUpload() },
                    onFile: { viewModel.startFileImport() }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $viewModel.showScanner) {
                DocumentScanner { result in viewModel.handleScanResult(result) }
                    .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $viewModel.showPhotoPicker,
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            )
            .onChange(of: viewModel.selectedPhotoItem) { _, item in
                viewModel.handlePhotoSelection(item)
            }
            .fileImporter(
                isPresented: $viewModel.showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { viewModel.handleFileImport(.success(url)) }
                case .failure(let error):
                    viewModel.handleFileImport(.failure(error))
                }
            }
            .sheet(isPresented: $viewModel.showMetadataForm) {
                if let preview = viewModel.pendingPreview {
                    DocumentMetadataView(preview: preview) { metadata, updatedPreview in
                        viewModel.saveDocument(metadata: metadata, preview: updatedPreview)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(
                    selectedCategory: $viewModel.selectedCategoryFilter,
                    selectedSpecialization: $viewModel.selectedSpecializationFilter,
                    sortOption: $viewModel.sortOption,
                    resultCount: viewModel.filteredDocuments.count,
                    onClear: { viewModel.clearFilters() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView(subscriptionManager: .shared)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
            .alert(
                "Delete \(selectedDocuments.count) Document\(selectedDocuments.count == 1 ? "" : "s")?",
                isPresented: $showDeleteSelectedAlert
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteSelectedDocuments)
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                viewModel.loadDocuments()
                if coordinator.showAddDocument {
                    viewModel.showAddOptions()
                    coordinator.showAddDocument = false
                }
            }
            .onChange(of: coordinator.showAddDocument) { _, shouldAdd in
                if shouldAdd {
                    viewModel.showAddOptions()
                    coordinator.showAddDocument = false
                }
            }
            .onChange(of: isSelecting) { _, selecting in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    coordinator.isSelectingDocs = selecting
                }
            }
            .onDisappear {
                coordinator.isSelectingDocs = false
            }
            .overlay(alignment: .bottom) {
                if isSelecting && !selectedDocuments.isEmpty {
                    selectionBottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedDocuments.isEmpty)
        }
    }

    // MARK: - Segment Control

    private var segmentControl: some View {
        HStack(spacing: 2) {
            ForEach(DocViewMode.allCases, id: \.label) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = mode
                        if mode == .folders { isSelecting = false; selectedDocuments.removeAll() }
                    }
                } label: {
                    Text(mode.label)
                        .font(.labelM)
                        .fontWeight(viewMode == mode ? .semibold : .regular)
                        .foregroundStyle(viewMode == mode ? Color.textPrimary : Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if viewMode == mode {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.surfaceWhite)
                                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            }
                        }
                }
            }
        }
        .padding(3)
        .background(Color.backgroundCard)
        .clipShape(.rect(cornerRadius: 13))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        let docsByCategory = Dictionary(grouping: viewModel.documents, by: { $0.category ?? .other })
        return ScrollView {
            LazyVGrid(columns: [GridItem(.flexible())], alignment: .leading, spacing: 12) {
                ForEach(DocumentCategory.allCases) { category in
                    CategoryFolderCard(
                        category: category,
                        documents: docsByCategory[category] ?? []
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
            TextField("Search documents", text: $viewModel.searchText)
                .font(.bodyL)
        }
        .padding(12)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
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

            Text("\(viewModel.filteredDocuments.count) docs")
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Documents List

    @ViewBuilder
    private var documentsList: some View {
        let sections = viewModel.groupedDocuments
        if sections.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headingXS)
                                .foregroundStyle(Color.textSecondary)
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

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            viewModel.activeFilterCount > 0 ? "No Matching Documents" : "No Documents",
            systemImage: viewModel.activeFilterCount > 0 ? "doc.text.magnifyingglass" : "doc.badge.plus",
            description: Text(
                viewModel.activeFilterCount > 0
                    ? "Try adjusting your filters."
                    : "Scan or upload your first medical document."
            )
        )
    }

    // MARK: - Selection Bottom Bar

    private var selectionBottomBar: some View {
        HStack {
            Button {
                showDeleteSelectedAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.surfaceWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.stroke, lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }

            Spacer()

            Button {
                shareSelectedDocuments()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accent)
                    .clipShape(Capsule())
                    .shadow(color: Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Selection Actions

    private var allSelected: Bool {
        let allIDs = Set(viewModel.filteredDocuments.map(\.id))
        return !allIDs.isEmpty && allIDs.isSubset(of: selectedDocuments)
    }

    private func toggleSelection(_ document: Document) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if selectedDocuments.contains(document.id) {
                selectedDocuments.remove(document.id)
            } else {
                selectedDocuments.insert(document.id)
            }
        }
    }

    private func toggleSelectAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if allSelected {
                selectedDocuments.removeAll()
            } else {
                selectedDocuments = Set(viewModel.filteredDocuments.map(\.id))
            }
        }
    }

    private func shareSelectedDocuments() {
        let urls = viewModel.documents
            .filter { selectedDocuments.contains($0.id) && $0.fileExists }
            .map(\.fileURL)
        guard !urls.isEmpty else { return }
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topVC = root
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    private func deleteSelectedDocuments() {
        let toDelete = viewModel.documents.filter { selectedDocuments.contains($0.id) }
        for doc in toDelete { viewModel.deleteDocument(doc) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDocuments.removeAll()
            isSelecting = false
        }
    }
}

// MARK: - Add Document Sheet

private struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: () -> Void
    let onPhoto: () -> Void
    let onFile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Document")
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 24)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                sourceOption(icon: "doc.viewfinder", title: "Scan Document",
                             subtitle: "Use camera to scan pages", color: Color.accent) {
                    dismiss(); onScan()
                }
                sourceOption(icon: "photo.on.rectangle", title: "Upload from Photos",
                             subtitle: "Choose an image from your library", color: Color.blue) {
                    dismiss(); onPhoto()
                }
                sourceOption(icon: "folder", title: "Import File",
                             subtitle: "Select a PDF or image file", color: Color.green) {
                    dismiss(); onFile()
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Color.backgroundPrimary)
    }

    private func sourceOption(
        icon: String, title: String, subtitle: String, color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


#Preview {
    DocsView()
}

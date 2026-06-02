import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - DocsView

struct DocsView: View {
    @StateObject private var viewModel = DocumentsListViewModel()
    @StateObject private var folderStore = CustomFolderStore.shared
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var navigationPath = NavigationPath()
    @State private var showFilters = false
    @State private var isSelecting = false
    @State private var selectedDocuments: Set<UUID> = []
    @State private var showDeleteSelectedAlert = false
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack(path: $navigationPath) {
            navigationContent
        }
        .onChange(of: navigationPath.count) { _, count in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                coordinator.isInDetailView = count > 0
            }
        }
        .sheet(isPresented: $viewModel.showSourcePicker) {
            AddDocumentSheet(
                onScan: { viewModel.startScanning() },
                onPhoto: { viewModel.startPhotoUpload() },
                onFile: { viewModel.startFileImport() }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.surfaceWhite)
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
        .fullScreenCover(isPresented: $viewModel.showPaywall) {
            PaywallView(subscriptionManager: .shared)
        }
        .alert("Photos Access Required", isPresented: $viewModel.showPhotoPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Neura needs access to your photo library to upload images. Please allow access in Settings.")
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
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                folderStore.add(name: trimmed)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for your new folder.")
        }
        .onAppear {
            viewModel.loadDocuments()
            if let action = coordinator.pendingAddAction {
                coordinator.pendingAddAction = nil
                handlePendingAction(action)
            }
        }
        .onChange(of: coordinator.pendingAddAction) { _, action in
            if let action {
                coordinator.pendingAddAction = nil
                handlePendingAction(action)
            }
        }
        .onChange(of: isSelecting) { _, selecting in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                coordinator.isSelectingDocs = selecting
            }
        }
        .onDisappear { coordinator.isSelectingDocs = false }
    }

    // MARK: - Navigation Content

    private var navigationContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchBar
            contentArea
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
        .navigationDestination(for: CustomFolder.self) { folder in
            CustomFolderDocumentsView(folder: folder, viewModel: viewModel)
        }
        .overlay { ScanProcessingView(isProcessing: viewModel.isProcessing) }
        .overlay(alignment: .bottom) {
            if isSelecting && !selectedDocuments.isEmpty {
                DocsSelectionBar(
                    onDelete: { showDeleteSelectedAlert = true },
                    onShare: shareSelectedDocuments
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedDocuments.isEmpty)
    }

    // MARK: - Header

    private var header: some View {
        Group {
            if viewModel.displayMode == .files && isSelecting {
                // Selection mode: Select All pill (left) + count/title (center) + Done ✓ (right)
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            // Exclude locked documents from bulk selection
                            let allIDs = Set(viewModel.filteredDocuments
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.surfaceWhite)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    Text(selectedDocuments.isEmpty ? "Documents" : "\(selectedDocuments.count) Items")
                        .font(.displayXL)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceWhite)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
            } else {
                // Normal mode
                HStack(alignment: .center) {
                    Text("Documents")
                        .font(.displayXL)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.displayMode = viewModel.displayMode == .folders ? .files : .folders
                            isSelecting = false
                            selectedDocuments.removeAll()
                        }
                    } label: {
                        Image(systemName: viewModel.displayMode == .folders ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceWhite)
                            .clipShape(.rect(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelecting)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.displayMode)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
                .font(.system(size: 15))
            TextField("Search documents", text: $viewModel.searchText)
                .font(.bodyL)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ZStack {
            if viewModel.displayMode == .folders {
                DocsFoldersGrid(
                    viewModel: viewModel,
                    folderStore: folderStore,
                    showNewFolderAlert: $showNewFolderAlert,
                    newFolderName: $newFolderName
                )
                .transition(.opacity)
            } else {
                DocsFilesView(
                    viewModel: viewModel,
                    isSelecting: $isSelecting,
                    selectedDocuments: $selectedDocuments,
                    showFilters: $showFilters,
                    onAddDocument: { viewModel.showAddOptions() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.displayMode)
    }

    // MARK: - Actions

    private func handlePendingAction(_ action: AppCoordinator.AddDocumentAction) {
        switch action {
        case .scan:  viewModel.startScanning()
        case .photo: viewModel.startPhotoUpload()
        case .file:  viewModel.startFileImport()
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

// MARK: - Preview

#Preview {
    DocsView()
        .environmentObject(AppCoordinator())
}

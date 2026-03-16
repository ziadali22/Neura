import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DocsView: View {
    @StateObject private var viewModel = DocumentsListViewModel()
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                filterBar
                documentsList
            }
            .background(Color.backgroundPrimary)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { viewModel.showAddOptions() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.accent)
                    }
                }
            }
            .navigationDestination(for: Document.self) { document in
                DocumentViewerView(document: document, onDelete: {
                    viewModel.deleteDocument(document)
                }, onRename: { newName in
                    viewModel.renameDocument(document, to: newName)
                })
            }
            .overlay {
                ScanProcessingView(isProcessing: viewModel.isProcessing)
            }

            // Custom source picker
            .sheet(isPresented: $viewModel.showSourcePicker) {
                AddDocumentSheet(
                    onScan: { viewModel.startScanning() },
                    onPhoto: { viewModel.startPhotoUpload() },
                    onFile: { viewModel.startFileImport() }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }

            // Scanner
            .fullScreenCover(isPresented: $viewModel.showScanner) {
                DocumentScanner { result in
                    viewModel.handleScanResult(result)
                }
                .ignoresSafeArea()
            }

            // Photo picker
            .photosPicker(
                isPresented: $viewModel.showPhotoPicker,
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            )
            .onChange(of: viewModel.selectedPhotoItem) { _, item in
                viewModel.handlePhotoSelection(item)
            }

            // File importer
            .fileImporter(
                isPresented: $viewModel.showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.handleFileImport(.success(url))
                    }
                case .failure(let error):
                    viewModel.handleFileImport(.failure(error))
                }
            }

            // Metadata form
            .sheet(isPresented: $viewModel.showMetadataForm) {
                if let preview = viewModel.pendingPreview {
                    DocumentMetadataView(preview: preview) { metadata, updatedPreview in
                        viewModel.saveDocument(metadata: metadata, preview: updatedPreview)
                    }
                }
            }

            // Filter sheet
            .sheet(isPresented: $showFilters) {
                FilterSheet(
                    selectedCategory: $viewModel.selectedCategoryFilter,
                    sortOption: $viewModel.sortOption,
                    onClear: { viewModel.clearFilters() }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }

            // Paywall
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView(subscriptionManager: .shared)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }

            // Error alert
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                viewModel.loadDocuments()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textTertiary)

            TextField("Search documents", text: $viewModel.searchText)
                .font(.bodyL)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .shadow(radius: 1)
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
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.accent)
                            .clipShape(Circle())
                    }
                }
                .foregroundColor(viewModel.activeFilterCount > 0 ? .accent : .textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    viewModel.activeFilterCount > 0
                    ? Color.accent.opacity(0.1)
                    : Color.white
                )
                .shadow(radius: 1)
                .cornerRadius(8)
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
                .foregroundColor(.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accent.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            Text("\(viewModel.filteredDocuments.count) docs")
                .font(.captionS)
                .foregroundColor(.textTertiary)
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
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headingXS)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 8) {
                                ForEach(section.documents) { document in
                                    NavigationLink(value: document) {
                                        DocumentRow(document: document)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
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
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(.textTertiary.opacity(0.5))

            Text(viewModel.activeFilterCount > 0 ? "No Matching Documents" : "No Documents")
                .font(.headingS)
                .foregroundColor(.textPrimary)

            Text(viewModel.activeFilterCount > 0
                 ? "Try adjusting your filters"
                 : "Scan or upload your first document")
                .font(.bodyS)
                .foregroundColor(.textSecondary)

            if viewModel.activeFilterCount > 0 {
                Button {
                    withAnimation { viewModel.clearFilters() }
                } label: {
                    Text("Clear Filters")
                        .font(.buttonM)
                        .foregroundColor(.accent)
                }
            } else {
                Button {
                    viewModel.showAddOptions()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Document")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.black)
                    .cornerRadius(14)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

// MARK: - Document Row

private struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 14) {
            documentIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = document.category {
                        Text(category.localizedName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accent.opacity(0.1))
                            .cornerRadius(4)
                    }

                    Text(formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)

                    if document.isPDF && document.pageCount > 1 {
                        Text("·")
                            .foregroundColor(.textTertiary)
                        Text("\(document.pageCount) pages")
                            .font(.system(size: 13))
                            .foregroundColor(.textTertiary)
                    }
                }

                if let doctor = document.doctorName, !doctor.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 11))
                        Text(doctor)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.textTertiary)
        }
        .padding(14)
        .background(Color.surfaceWhite)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accent.opacity(0.12))
                .frame(width: 44, height: 44)

            Image(systemName: document.isPDF ? "doc.fill" : "photo.fill")
                .font(.system(size: 18))
                .foregroundColor(.accent)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: document.createdAt)
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
                .foregroundColor(.textPrimary)
                .padding(.top, 24)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                sourceOption(
                    icon: "doc.viewfinder",
                    title: "Scan Document",
                    subtitle: "Use camera to scan pages",
                    color: Color.accent
                ) {
                    dismiss()
                    onScan()
                }

                sourceOption(
                    icon: "photo.on.rectangle",
                    title: "Upload from Photos",
                    subtitle: "Choose an image from your library",
                    color: Color(hex: "456990")
                ) {
                    dismiss()
                    onPhoto()
                }

                sourceOption(
                    icon: "folder",
                    title: "Import File",
                    subtitle: "Select a PDF or image file",
                    color: Color(hex: "6B9080")
                ) {
                    dismiss()
                    onFile()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.backgroundPrimary)
    }

    private func sourceOption(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
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
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textTertiary)
            }
            .padding(14)
            .background(Color.surfaceWhite)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Filter Sheet

private struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: DocumentCategory?
    @Binding var sortOption: DocumentSortOption

    let onClear: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Sort
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sort By")
                            .font(.bodyS)
                            .fontWeight(.semibold)
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(DocumentSortOption.allCases) { option in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        sortOption = option
                                    }
                                } label: {
                                    Text(option.localizedName)
                                        .font(.labelM)
                                        .foregroundColor(sortOption == option ? .white : .textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            sortOption == option
                                            ? Color.accent
                                            : Color.backgroundCard
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.bodyS)
                            .fontWeight(.semibold)
                            .foregroundColor(.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(DocumentCategory.allCases) { cat in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedCategory = (selectedCategory == cat) ? nil : cat
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 14))

                                        Text(cat.localizedName)
                                            .font(.labelM)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedCategory == cat
                                        ? Color.accent.opacity(0.12)
                                        : Color.backgroundCard
                                    )
                                    .foregroundColor(
                                        selectedCategory == cat
                                        ? .accent
                                        : .textSecondary
                                    )
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedCategory == cat ? Color.accent : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        withAnimation { onClear() }
                    }
                    .foregroundColor(.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }
}

#Preview {
    DocsView()
}

import SwiftUI
import PhotosUI

// MARK: - Document Metadata

struct DocumentMetadata {
    var name: String = ""
    var category: DocumentCategory?
    var customFolderId: UUID?
    var specialization: MedicalSpecialization = .other
    var doctorName: String = ""
    var notes: String = ""
    var documentDate: Date = Date()
    var expiryDate: Date?
}

// MARK: - Preview Content

enum DocumentPreviewContent {
    case scannedImages([UIImage])
    case importedFile(URL)
}

// MARK: - Document Metadata View

struct DocumentMetadataView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: DocumentPreviewContent
    let onSave: (DocumentMetadata, DocumentPreviewContent) -> Void
    /// Non-nil when editing an existing document (pre-fills the form).
    let editingDocument: Document?

    @ObservedObject private var folderStore = CustomFolderStore.shared
    @State private var metadata = DocumentMetadata()
    @State private var scannedPages: [ScannedPage] = []
    @State private var previewingPage: ScannedPage?
    @State private var showScanner = false
    @State private var showAddImageOptions = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showSpecializationPicker = false
    @State private var hasExpiry = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, doctor, notes
    }

    init(
        preview: DocumentPreviewContent,
        editingDocument: Document? = nil,
        initialCategory: DocumentCategory? = nil,
        initialCustomFolderId: UUID? = nil,
        onSave: @escaping (DocumentMetadata, DocumentPreviewContent) -> Void
    ) {
        self.preview = preview
        self.editingDocument = editingDocument
        self.onSave = onSave

        if let doc = editingDocument {
            var meta = DocumentMetadata()
            meta.name = doc.name
            meta.category = doc.category
            meta.customFolderId = doc.tags?
                .compactMap { UUID(uuidString: $0) }
                .first
            meta.specialization = doc.specialization ?? .other
            meta.doctorName = doc.doctorName ?? ""
            meta.notes = doc.notes ?? ""
            meta.documentDate = doc.createdAt
            meta.expiryDate = doc.expiryDate
            _metadata = State(initialValue: meta)
            _hasExpiry = State(initialValue: doc.expiryDate != nil)
        } else {
            var meta = DocumentMetadata()
            meta.category = initialCategory
            meta.customFolderId = initialCustomFolderId
            _metadata = State(initialValue: meta)
        }

        if case .scannedImages(let images) = preview {
            _scannedPages = State(initialValue: images.map { ScannedPage(image: $0) })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    previewSection
                    categorySection
                    specializationSection
                    dateSection
                    expirySection
                    nameSection
                    doctorSection
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(editingDocument == nil ? L10n.Documents.Metadata.title : L10n.Common.edit)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSpecializationPicker) {
                SpecializationPickerView(selected: $metadata.specialization)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .foregroundColor(.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.save) { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(canSave ? .accent : .textTertiary)
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(L10n.Common.done) { focusedField = nil }
                            .fontWeight(.medium)
                    }
                }
            }
            .onAppear {
                guard editingDocument == nil, metadata.name.isEmpty else { return }
                metadata.name = defaultName
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { result in
                if case .success(let newImages) = result {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scannedPages.append(contentsOf: newImages.map { ScannedPage(image: $0) })
                    }
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $previewingPage) { page in
            DocumentPagesGalleryView(pages: scannedPages, initialID: page.id)
                .presentationBackground(.black)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Group {
            switch preview {
            case .scannedImages:
                scannedImagesPreview
            case .importedFile(let url):
                importedFilePreview(url: url)
            }
        }
        .padding(.top, 8)
    }

    private var scannedImagesPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScannedPagesStrip(
                pages: $scannedPages,
                onPreview: { id in
                    focusedField = nil
                    previewingPage = scannedPages.first(where: { $0.id == id })
                },
                onAdd: { showAddImageOptions = true }
            )

            if !scannedPages.isEmpty {
                Text(
                    scannedPages.count > 1
                        ? L10n.Documents.Metadata.reorderHint
                        : L10n.Documents.Metadata.previewHint
                )
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
            }
        }
        .confirmationDialog(
            L10n.Documents.Metadata.addPage,
            isPresented: $showAddImageOptions,
            titleVisibility: .visible
        ) {
            Button(L10n.Documents.Metadata.scanPage) { showScanner = true }
            Button(L10n.Documents.Metadata.uploadPage) { showPhotoPicker = true }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: DocumentsListViewModel.photoSelectionLimit,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var newPages: [ScannedPage] = []
                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { continue }
                    newPages.append(ScannedPage(image: image))
                }
                guard !newPages.isEmpty else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scannedPages.append(contentsOf: newPages)
                    }
                    selectedPhotoItems = []
                }
            }
        }
    }

    private func importedFilePreview(url: URL) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: fileIcon(for: url))
                    .font(.system(size: 28))
                    .foregroundColor(.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.bodyL)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(url.pathExtension.uppercased())
                    .font(.captionS)
                    .foregroundColor(.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Documents.Metadata.category)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DocumentCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            metadata.category = (metadata.category == cat) ? nil : cat
                            metadata.customFolderId = nil
                        }
                    } label: {
                        categoryChip(
                            icon: {
                                Image(cat.gridIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                            },
                            label: cat.localizedName,
                            isSelected: metadata.category == cat
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(folderStore.foldersForActiveSpace) { folder in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            metadata.customFolderId = (metadata.customFolderId == folder.id) ? nil : folder.id
                            metadata.category = nil
                        }
                    } label: {
                        categoryChip(
                            icon: {
                                if folder.name.caseInsensitiveCompare(CustomFolderStore.otherFolderName) == .orderedSame {
                                    Image("otherIcon")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.accent)
                                }
                            },
                            label: folder.displayName,
                            isSelected: metadata.customFolderId == folder.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryChip<Icon: View>(
        @ViewBuilder icon: () -> Icon,
        label: String,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 8) {
            icon()
            Text(label)
                .font(.bodyS)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isSelected ? Color.surfaceDark : Color.surfaceWhite)
        .foregroundColor(isSelected ? .white : .textPrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Specialization Section

    private var specializationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Documents.Metadata.specialization)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            Button {
                focusedField = nil
                showSpecializationPicker = true
            } label: {
                HStack {
                    Text(metadata.specialization.localizedName)
                        .font(.bodyL)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 14))
                        .foregroundColor(.textTertiary)
                }
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Documents.Metadata.date)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            HStack {
                Text(L10n.Documents.Metadata.date)
                    .font(.bodyL)
                    .foregroundColor(.textPrimary)

                Spacer()

                DatePicker(
                    "",
                    selection: $metadata.documentDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.accent)
            }
            .padding(16)
            .background(Color.surfaceWhite)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Expiry Section

    /// Optional renewal/expiry date (passport, insurance card, warranty). When
    /// set, `DocumentExpiryReminderScheduler` fires reminders 30 and 7 days out.
    private var expirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasExpiry.animation(.spring(response: 0.3, dampingFraction: 0.7))) {
                Text(L10n.Documents.Metadata.expiryToggle)
                    .font(.headingXS)
                    .foregroundColor(.textPrimary)
            }
            .tint(.accent)
            .onChange(of: hasExpiry) { _, enabled in
                metadata.expiryDate = enabled ? (metadata.expiryDate ?? Self.defaultExpiryDate) : nil
            }

            if hasExpiry {
                HStack {
                    Text(L10n.Documents.Metadata.expiryDate)
                        .font(.bodyL)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { metadata.expiryDate ?? Self.defaultExpiryDate },
                            set: { metadata.expiryDate = $0 }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.accent)
                }
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    private static var defaultExpiryDate: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Documents.Metadata.name)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            TextField("Blood Test", text: $metadata.name)
                .focused($focusedField, equals: .name)
                .font(.bodyL)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .submitLabel(.next)
                .onSubmit { focusedField = .doctor }
        }
    }

    // MARK: - Doctor Section

    private var doctorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Documents.Metadata.doctor)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            TextField("e.g. Dr. Sarah Johnson", text: $metadata.doctorName)
                .focused($focusedField, equals: .doctor)
                .font(.bodyL)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .submitLabel(.next)
                .onSubmit { focusedField = .notes }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Documents.Metadata.notes)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            ZStack(alignment: .topLeading) {
                if metadata.notes.isEmpty {
                    Text(L10n.Documents.Metadata.notesPlaceholder)
                        .font(.bodyL)
                        .foregroundColor(.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $metadata.notes)
                    .font(.bodyL)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }
            .padding(16)
            .background(Color.surfaceWhite)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        let hasName = !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch preview {
        case .scannedImages:
            return hasName && !scannedPages.isEmpty
        case .importedFile:
            return hasName
        }
    }

    private var defaultName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let date = formatter.string(from: Date())

        switch preview {
        case .scannedImages: return "Scan - \(date)"
        case .importedFile(let url):
            let name = url.deletingPathExtension().lastPathComponent
            return name.isEmpty ? "Document - \(date)" : name
        }
    }

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }

    private func save() {
        guard canSave else { return }
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var trimmed = metadata
        trimmed.name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed.doctorName = metadata.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed.notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalPreview: DocumentPreviewContent
        switch preview {
        case .scannedImages:
            finalPreview = .scannedImages(scannedPages.map(\.image))
        case .importedFile:
            finalPreview = preview
        }

        onSave(trimmed, finalPreview)
        dismiss()
    }
}

// MARK: - Specialization Picker View

private struct SpecializationPickerView: View {
    @Binding var selected: MedicalSpecialization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(MedicalSpecialization.allCases) { spec in
                    Button {
                        selected = spec
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: spec.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 28, alignment: .center)

                            Text(spec.localizedName)
                                .font(.bodyL)
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        selected == spec ? Color.accent : Color.textTertiary.opacity(0.35),
                                        lineWidth: 2
                                    )
                                    .frame(width: 22, height: 22)

                                if selected == spec {
                                    Circle()
                                        .fill(Color.accent)
                                        .frame(width: 13, height: 13)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if spec != MedicalSpecialization.allCases.last {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(L10n.Documents.Metadata.specializationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("Scanned Images") {
    DocumentMetadataView(
        preview: .scannedImages([UIImage(systemName: "doc.fill")!]),
        onSave: { _, _ in }
    )
}

#Preview("Imported File") {
    DocumentMetadataView(
        preview: .importedFile(URL(fileURLWithPath: "/tmp/report.pdf")),
        onSave: { _, _ in }
    )
}

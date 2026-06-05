import SwiftUI
import PDFKit

struct DocumentViewerView: View {
    let onDelete: () -> Void
    var onEdit: ((DocumentMetadata, DocumentPreviewContent) -> Void)?

    @State private var document: Document
    @State private var showEditSheet = false
    @State private var editPreview: DocumentPreviewContent?
    @State private var isPreparingEdit = false
    @State private var contentRefreshID = UUID()

    init(document: Document,
         onDelete: @escaping () -> Void,
         onEdit: ((DocumentMetadata, DocumentPreviewContent) -> Void)? = nil) {
        _document = State(initialValue: document)
        self.onDelete = onDelete
        self.onEdit = onEdit
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showInfo = false
    @State private var showShareQR = false
    @State private var showPaywall = false
    @State private var appear = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Custom Nav Bar
            navBar

            // MARK: - Document Header
            documentHeader
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)

            // MARK: - Content
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if !document.fileExists {
                    fileMissingView
                } else if document.isPDF {
                    PDFDocumentView(url: document.fileURL)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                } else if document.isImage {
                    ImageDocumentView(url: document.fileURL)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                }
            }
            .id(contentRefreshID)
            .opacity(appear ? 1 : 0)
        }
        .overlay {
            if isPreparingEdit {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(Color.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .background(Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert(L10n.Documents.Viewer.deleteTitle, isPresented: $showDeleteConfirmation) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text(L10n.Documents.Viewer.deleteMessage)
        }
        .sheet(isPresented: $showInfo) {
            documentInfoSheet
        }
        .sheet(isPresented: $showEditSheet) {
            if let preview = editPreview {
                DocumentMetadataView(
                    preview: preview,
                    editingDocument: document
                ) { metadata, updatedPreview in
                    applyEdit(metadata: metadata, preview: updatedPreview)
                }
            }
        }
        .sheet(isPresented: $showShareQR) {
            if let vm = makeShareViewModel() {
                ShareDocumentSheet(viewModel: vm, documentName: document.name)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appear = true
            }
        }
    }
}

// MARK: - Subviews

private extension DocumentViewerView {

    // MARK: Nav Bar

    var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Menu {
                Button {
                    startEdit()
                } label: {
                    Label(L10n.Common.edit, systemImage: "pencil")
                }

                Button { showInfo = true } label: {
                    Label(L10n.Common.info, systemImage: "info.circle")
                }

                Button {
                    shareDocument()
                } label: {
                    Label(L10n.Documents.Viewer.share, systemImage: "square.and.arrow.up")
                }
                .disabled(!document.fileExists)

                Button {
                    if subscriptionManager.canShareViaQR {
                        showShareQR = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Label(L10n.Documents.Viewer.shareQR, systemImage: "qrcode")
                }
                .disabled(!document.fileExists)

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(L10n.Common.delete, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: Document Header

    var documentHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Category icon
                if let category = document.category {
                    Image(category.gridIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(document.name)
                        .font(.headingS)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let category = document.category {
                            Text(category.localizedName)
                                .font(.captionS)
                                .foregroundColor(.accent)
                        }

                        Text("·")
                            .font(.captionS)
                            .foregroundColor(.textTertiary)

                        Text(formattedDate)
                            .font(.captionS)
                            .foregroundColor(.textTertiary)

                        if document.isPDF && document.pageCount > 1 {
                            Text("·")
                                .font(.captionS)
                                .foregroundColor(.textTertiary)
                            Text(L10n.Documents.Viewer.pagesCount(document.pageCount))
                                .font(.captionS)
                                .foregroundColor(.textTertiary)
                        }

                        if let doctor = document.doctorName, !doctor.isEmpty {
                            Text("·")
                                .font(.captionS)
                                .foregroundColor(.textTertiary)
                            Text(doctor)
                                .font(.captionS)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Info Sheet

    var documentInfoSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Document details card
                    VStack(spacing: 0) {
                        infoRow(L10n.Documents.Viewer.name, value: document.name, isFirst: true)
                        infoRow(L10n.Documents.Viewer.type, value: document.documentType.localizedName)
                        infoRow(L10n.Documents.Viewer.date, value: formattedDate)
                        if document.isPDF {
                            infoRow(L10n.Documents.Viewer.pages, value: "\(document.pageCount)", isLast: true)
                        }
                    }
                    .background(Color.surfaceWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let category = document.category {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: category.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(category.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Documents.Viewer.category)
                                    .font(.captionS)
                                    .foregroundColor(.textTertiary)
                                Text(category.localizedName)
                                    .font(.headingXS)
                                    .foregroundColor(.textPrimary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(Color.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let doctor = document.doctorName, !doctor.isEmpty {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accent.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "stethoscope")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Documents.Viewer.doctor)
                                    .font(.captionS)
                                    .foregroundColor(.textTertiary)
                                Text(doctor)
                                    .font(.headingXS)
                                    .foregroundColor(.textPrimary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(Color.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let notes = document.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.Documents.Viewer.notes)
                                .font(.captionS)
                                .foregroundColor(.textTertiary)
                            Text(notes)
                                .font(.bodyL)
                                .foregroundColor(.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let tags = document.tags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.Documents.Viewer.tags)
                                .font(.captionS)
                                .foregroundColor(.textTertiary)
                            FlowTagsView(tags: tags)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(L10n.Documents.Viewer.infoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done) { showInfo = false }
                        .font(.buttonM)
                        .foregroundColor(.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func infoRow(_ label: String, value: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.bodyS)
                    .foregroundColor(.textTertiary)
                Spacer()
                Text(value)
                    .font(.bodyS)
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: document.createdAt)
    }

    // MARK: File Missing

    var fileMissingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.questionmark.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.accent)
            }

            VStack(spacing: 6) {
                Text(L10n.Documents.Viewer.fileNotFound)
                    .font(.headingS)
                    .foregroundColor(.textPrimary)

                Text(L10n.Documents.Viewer.fileNotFoundMessage)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: Share via QR

    func makeShareViewModel() -> ShareDocumentViewModel? {
        guard document.fileExists,
              let data = try? DocumentFileManager.shared.loadDocument(url: document.fileURL) else {
            return nil
        }
        let mimeType = FirebaseUploadService.mimeType(for: document.fileExtension)
        return ShareDocumentViewModel(fileData: data, filename: document.name + "." + document.fileExtension, mimeType: mimeType)
    }

    // MARK: Share

    func shareDocument() {
        guard document.fileExists else { return }

        let activityVC = UIActivityViewController(
            activityItems: [document.fileURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    // MARK: Edit

    func startEdit() {
        switch document.documentType {
        case .pdf:
            // Imported PDF -> metadata only, read-only file row.
            editPreview = .importedFile(document.fileURL)
            showEditSheet = true
        case .image:
            if let image = try? DocumentFileManager.shared.loadImage(url: document.fileURL) {
                editPreview = .scannedImages([image])
            } else {
                editPreview = .importedFile(document.fileURL)
            }
            showEditSheet = true
        case .scan:
            isPreparingEdit = true
            let url = document.fileURL
            DispatchQueue.global(qos: .userInitiated).async {
                let images = PDFGenerator.shared.renderImages(from: url)
                DispatchQueue.main.async {
                    isPreparingEdit = false
                    // Fall back to metadata-only if rendering failed.
                    editPreview = images.isEmpty ? .importedFile(url) : .scannedImages(images)
                    showEditSheet = true
                }
            }
        }
    }

    func applyEdit(metadata: DocumentMetadata, preview: DocumentPreviewContent) {
        // Optimistically refresh the local copy so the header/info update now.
        document.name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
        document.createdAt = metadata.documentDate
        document.category = metadata.category
        document.specialization = metadata.specialization
        let doctor = metadata.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.doctorName = doctor.isEmpty ? nil : doctor
        let notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        document.notes = notes.isEmpty ? nil : notes
        document.tags = metadata.customFolderId.map { [$0.uuidString] }

        // Persist (and re-save file if pages changed) via the ViewModel.
        onEdit?(metadata, preview)

        // Force the PDF/image view to reload the (possibly overwritten) file.
        contentRefreshID = UUID()
    }
}

// MARK: - Flow Tags View

private struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.captionS)
                    .foregroundColor(.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accent.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - PDF Document View

private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white
        pdfView.document = PDFDocument(url: url)
        pdfView.pageShadowsEnabled = false
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {}
}

// MARK: - Image Document View

private struct ImageDocumentView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
                    .background(Color.white)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.accent)
                    Text(L10n.Documents.Viewer.loading)
                        .font(.captionS)
                        .foregroundColor(.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            Task.detached(priority: .userInitiated) {
                let data = try? Data(contentsOf: url)
                let loaded = data.flatMap { UIImage(data: $0) }
                await MainActor.run { image = loaded }
            }
        }
    }
}

// MARK: - Preview

#Preview("File Missing") {
    NavigationStack {
        DocumentViewerView(
            document: Document(
                name: "Blood Test Results",
                fileURL: URL(fileURLWithPath: "/tmp/nonexistent.pdf"),
                documentType: .pdf,
                category: .bloodTests,
                doctorName: "Dr. Sarah Johnson",
                notes: "Annual checkup results",
                tags: ["urgent", "annual"]
            ),
            onDelete: {}
        )
    }
}

#Preview("PDF Viewer") {
    NavigationStack {
        DocumentViewerView(
            document: Document(
                name: "Consultation Report",
                fileURL: URL(fileURLWithPath: "/tmp/report.pdf"),
                documentType: .pdf,
                category: .consultations
            ),
            onDelete: {}
        )
    }
}

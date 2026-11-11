import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Image, document, and prescription slots on a calendar entry.
struct EntryAttachmentsSection: View {
    @Binding var imageID: UUID?
    @Binding var documentID: UUID?
    @Binding var prescriptionID: UUID?
    let documents: [Document]
    /// Entry title, used as the name when a new file is saved.
    let entryTitle: String
    let onCreateDocument: (Document) -> Void
    let onDeleteDocument: ((Document) -> Void)?

    @State private var localDocuments: [Document] = []
    @State private var addSheetKind: EntryAttachmentKind?
    @State private var libraryKind: EntryAttachmentKind?
    @State private var createAfterLibrary: EntryAttachmentKind?
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var fileKind: EntryAttachmentKind = .document
    @State private var savingKind: EntryAttachmentKind?
    @State private var viewingDocument: Document?
    @State private var showPaywall = false
    @State private var attachError: String?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Calendar.attachments)
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                    .padding(.leading, 4)

                VStack(spacing: 8) {
                    ForEach(EntryAttachmentKind.allCases) { kind in
                        attachmentCard(kind)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .navigationDestination(item: $viewingDocument) { document in
            DocumentViewerView(document: document, onDelete: {
                onDeleteDocument?(document)
                clearSlot(containing: document.id)
                viewingDocument = nil
            })
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $addSheetKind) { kind in
            EntryAttachmentAddSheet(
                kind: kind,
                onExisting: { libraryKind = kind },
                onNew: { presentNewFile(for: kind) }
            )
            .presentationDetents([.height(268)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.backgroundPrimary)
        }
        .sheet(item: $libraryKind, onDismiss: {
            if let kind = createAfterLibrary {
                createAfterLibrary = nil
                presentNewFile(for: kind)
            }
        }) { kind in
            EntryAttachmentLibrarySheet(
                kind: kind,
                documents: candidates(for: kind),
                onSelect: { document in
                    assign(document.id, to: kind)
                    libraryKind = nil
                },
                onAddNew: {
                    createAfterLibrary = kind
                    libraryKind = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.backgroundPrimary)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await savePhoto(item) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { saveFile(url, kind: fileKind) }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    attachError = error.localizedDescription
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: .shared)
        }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { attachError != nil },
            set: { if !$0 { attachError = nil } }
        )) {
            Button(L10n.Common.ok) { attachError = nil }
        } message: {
            Text(attachError ?? "")
        }
    }

    @ViewBuilder
    private func attachmentCard(_ kind: EntryAttachmentKind) -> some View {
        if let document = document(for: kind) {
            filledCard(kind, document: document)
        } else if id(for: kind) != nil {
            missingCard(kind)
        } else {
            Button {
                addSheetKind = kind
            } label: {
                cardChrome {
                    cardBody(
                        kind: kind,
                        title: kind.title,
                        detail: kind.addTitle,
                        trailing: { addOrSpinner(kind) }
                    )
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(savingKind != nil)
        }
    }

    private func filledCard(_ kind: EntryAttachmentKind, document: Document) -> some View {
        HStack(spacing: 0) {
            Button {
                viewingDocument = document
            } label: {
                cardBody(
                    kind: kind,
                    title: document.name,
                    detail: kind.title,
                    trailing: { EmptyView() }
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            removeButton(kind)
                .padding(.trailing, 4)
        }
        .modifier(AttachmentCardChrome())
    }

    private func missingCard(_ kind: EntryAttachmentKind) -> some View {
        HStack(spacing: 0) {
            cardBody(
                kind: kind,
                title: kind.title,
                detail: L10n.Calendar.attachmentMissing,
                trailing: { EmptyView() }
            )
            removeButton(kind)
                .padding(.trailing, 4)
        }
        .modifier(AttachmentCardChrome())
    }

    private func cardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().modifier(AttachmentCardChrome())
    }

    private func cardBody<Trailing: View>(
        kind: EntryAttachmentKind,
        title: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundCard)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func addOrSpinner(_ kind: EntryAttachmentKind) -> some View {
        if savingKind == kind {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accent)
                .frame(width: 32, height: 32)
                .background(Color.backgroundCard)
                .clipShape(Circle())
                .padding(.trailing, 4)
                .accessibilityHidden(true)
        }
    }

    private func removeButton(_ kind: EntryAttachmentKind) -> some View {
        Button {
            assign(nil, to: kind)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Calendar.removeAttachment)
    }

    private func presentNewFile(for kind: EntryAttachmentKind) {
        if kind == .image {
            showPhotoPicker = true
        } else {
            fileKind = kind
            showFileImporter = true
        }
    }

    private func savePhoto(_ item: PhotosPickerItem) async {
        guard ensureCanUpload() else { return }
        savingKind = .image
        defer { savingKind = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            let document = try DocumentFileManager.shared.saveImage(image, name: fileName(for: .image))
            store(document, as: .image)
        } catch {
            attachError = error.localizedDescription
        }
    }

    private func saveFile(_ url: URL, kind: EntryAttachmentKind) {
        guard ensureCanUpload() else { return }
        savingKind = kind
        defer { savingKind = nil }
        do {
            var document = try DocumentFileManager.shared.importFile(from: url, name: fileName(for: kind, source: url))
            if kind == .prescription {
                document.category = .prescriptions
            }
            store(document, as: kind)
        } catch {
            attachError = error.localizedDescription
        }
    }

    private func store(_ document: Document, as kind: EntryAttachmentKind) {
        localDocuments.append(document)
        onCreateDocument(document)
        assign(document.id, to: kind)
    }

    private func ensureCanUpload() -> Bool {
        guard SubscriptionManager.shared.canUpload else {
            showPaywall = true
            return false
        }
        return true
    }

    private func fileName(for kind: EntryAttachmentKind, source: URL? = nil) -> String {
        if let source {
            let raw = source.deletingPathExtension().lastPathComponent
            if !raw.isEmpty, raw != "/" { return raw }
        }
        let title = entryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? kind.title : "\(title) — \(kind.title)"
    }

    private var allDocuments: [Document] {
        let known = Set(documents.map(\.id))
        return documents + localDocuments.filter { !known.contains($0.id) }
    }

    private func candidates(for kind: EntryAttachmentKind) -> [Document] {
        let taken = Set([imageID, documentID, prescriptionID].compactMap { $0 })
        return allDocuments
            .filter { kind.matches($0) && !taken.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func document(for kind: EntryAttachmentKind) -> Document? {
        guard let id = id(for: kind) else { return nil }
        return allDocuments.first { $0.id == id }
    }

    private func id(for kind: EntryAttachmentKind) -> UUID? {
        switch kind {
        case .image: return imageID
        case .document: return documentID
        case .prescription: return prescriptionID
        }
    }

    private func assign(_ id: UUID?, to kind: EntryAttachmentKind) {
        switch kind {
        case .image: imageID = id
        case .document: documentID = id
        case .prescription: prescriptionID = id
        }
    }

    private func clearSlot(containing id: UUID) {
        if imageID == id { imageID = nil }
        if documentID == id { documentID = nil }
        if prescriptionID == id { prescriptionID = nil }
    }
}

private enum EntryAttachmentKind: String, CaseIterable, Identifiable {
    case image
    case document
    case prescription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: return L10n.Calendar.attachmentImage
        case .document: return L10n.Calendar.attachmentDocument
        case .prescription: return L10n.Calendar.attachmentPrescription
        }
    }

    var addTitle: String {
        switch self {
        case .image: return L10n.Calendar.addImage
        case .document: return L10n.Calendar.addDocument
        case .prescription: return L10n.Calendar.addPrescription
        }
    }

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .document: return "doc"
        case .prescription: return "pills"
        }
    }

    var newFileSymbol: String {
        switch self {
        case .image: return "photo"
        case .document: return "doc.badge.plus"
        case .prescription: return "pills"
        }
    }

    var newFileTitle: String {
        self == .image ? L10n.Calendar.choosePhoto : L10n.Calendar.importFile
    }

    var newFileSubtitle: String {
        self == .image ? L10n.Calendar.attachmentPhotoSubtitle : L10n.Calendar.attachmentImportSubtitle
    }

    func matches(_ document: Document) -> Bool {
        switch self {
        case .image:
            return document.documentType == .image && document.category != .prescriptions
        case .document:
            return document.documentType != .image && document.category != .prescriptions
        case .prescription:
            return document.category == .prescriptions
        }
    }
}

/// Short sheet: pick a saved file, or add a new photo / import.
private struct EntryAttachmentAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: EntryAttachmentKind
    let onExisting: () -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.stroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text(kind.addTitle)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            optionRow(
                symbol: "folder",
                title: L10n.Calendar.chooseExisting,
                subtitle: L10n.Calendar.attachmentExistingSubtitle
            ) {
                dismiss()
                onExisting()
            }

            Divider().padding(.leading, 76)

            optionRow(
                symbol: kind.newFileSymbol,
                title: kind.newFileTitle,
                subtitle: kind.newFileSubtitle
            ) {
                dismiss()
                onNew()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.backgroundPrimary)
    }

    private func optionRow(symbol: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundCard)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headingXS)
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct EntryAttachmentLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: EntryAttachmentKind
    let documents: [Document]
    let onSelect: (Document) -> Void
    let onAddNew: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(documents) { document in
                                Button {
                                    onSelect(document)
                                } label: {
                                    libraryRow(document)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                if !documents.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(kind.addTitle, action: onAddNew)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundCard)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                }

            Text(L10n.Calendar.attachmentEmpty)
                .font(.bodyL)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: kind.addTitle, action: onAddNew)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func libraryRow(_ document: Document) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(document.createdAt, format: .dateTime.day().month(.abbreviated).year())
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer(minLength: 8)

            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accent)
                .frame(width: 32, height: 32)
                .background(Color.backgroundCard)
                .clipShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.stroke, lineWidth: 1)
        }
    }
}

private struct AttachmentCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.stroke, lineWidth: 1)
            }
    }
}

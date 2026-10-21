import SwiftUI
import PhotosUI
import Combine

// MARK: - Display Mode

enum DocsDisplayMode: String {
    case folders
    case files
}

// MARK: - Sort Option

enum DocumentSortOption: String, CaseIterable, Identifiable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case name = "Name A-Z"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
}

/// Folder the user is adding from. Pre-selects that category / custom folder
/// on the metadata form so a doc scanned inside Hospitalization doesn't land
/// in Other.
enum DocumentAddDestination: Equatable {
    case category(DocumentCategory)
    case customFolder(UUID)

    var category: DocumentCategory? {
        if case .category(let category) = self { return category }
        return nil
    }

    var customFolderId: UUID? {
        if case .customFolder(let id) = self { return id }
        return nil
    }
}

@MainActor
final class DocumentsListViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var searchText = ""
    @Published var displayMode: DocsDisplayMode = .folders {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: Self.displayModeDefaultsKey)
        }
    }

    private static let displayModeDefaultsKey = "docs.displayMode"

    // Filtering & Sorting
    @Published var selectedCategoryFilter: DocumentCategory?
    @Published var selectedSpecializationFilter: MedicalSpecialization?
    @Published var sortOption: DocumentSortOption = .newest

    // Subscription
    @Published var showPaywall = false

    // Source picker
    @Published var showSourcePicker = false

    // Scanner
    @Published var showScanner = false

    // Photo picker
    @Published var showPhotoPicker = false
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    @Published var showPhotoPermissionAlert = false

    /// Every selected photo becomes one page of a single PDF, and each page is
    /// decoded into memory before saving — an unbounded selection stalls the app.
    static let photoSelectionLimit = 20

    // File importer
    @Published var showFileImporter = false

    // Google Drive import tip
    @Published var showDriveImportTip = false
    private static let hasSeenDriveImportTipKey = "docs.hasSeenDriveImportTip"

    // Metadata form
    @Published var showMetadataForm = false
    @Published var pendingPreview: DocumentPreviewContent?

    /// Folder currently on screen. Used when the FAB starts an add from inside
    /// a category / custom folder.
    var folderContext: DocumentAddDestination?

    /// Destination locked in for the in-flight add, read by the metadata form.
    private(set) var pendingAddDestination: DocumentAddDestination?

    /// Frozen copy of the destination at the moment the metadata sheet opens,
    /// so a source-picker dismiss can't race the form's initial state.
    private(set) var capturedFormDestination: DocumentAddDestination?

    // Processing
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let fileManager = DocumentFileManager.shared
    private let activeSpaceManager = ActiveSpaceManager.shared
    private var restoreObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.displayModeDefaultsKey),
           let mode = DocsDisplayMode(rawValue: saved) {
            displayMode = mode
        }
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .documentsRestored, object: nil, queue: .main
        ) { [weak self] _ in self?.loadDocuments() }

        // `documents` itself doesn't change when the active account switches, so
        // without this, views observing this view model never re-render on switch
        // and the (correctly-filtered) computed properties below appear stale.
        // Only send objectWillChange here — don't read currentSpaceID synchronously,
        // since @Published emits from willSet before the backing value updates.
        activeSpaceManager.$currentSpaceID
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Space Scoping

    func belongsToSpace(_ document: Document, spaceID: UUID) -> Bool {
        document.belongsToSpace(spaceID)
    }

    /// All documents belonging to the active account only — no category/search
    /// filtering. This is the shared base every other document-listing surface
    /// (folders grid, custom folders, categories, Home's recents) should read
    /// from instead of the raw, all-accounts `documents` array.
    var spaceScopedDocuments: [Document] {
        documents.filter { belongsToSpace($0, spaceID: activeSpaceManager.currentSpaceID) }
    }

    // MARK: - Filtered & Sorted Documents

    var filteredDocuments: [Document] {
        var result = spaceScopedDocuments

        // Category filter
        if let category = selectedCategoryFilter {
            result = result.filter { $0.category == category }
        }

        // Specialization filter
        if let specialization = selectedSpecializationFilter {
            result = result.filter { $0.specialization == specialization }
        }

        // Search
        if !searchText.isEmpty {
            result = result.filter { matchesSearch($0, query: searchText) }
        }

        // Sort
        switch sortOption {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .name:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        return result
    }

    // All documents in the active space, sorted newest-first (no category/specialisation filter applied).
    var allFilesSorted: [Document] {
        spaceScopedDocuments.sorted { $0.createdAt > $1.createdAt }
    }

    // Shared search predicate so every document list (Files mode, Folders grid, etc.)
    // matches search text the same way.
    func matchesSearch(_ document: Document, query: String) -> Bool {
        document.name.localizedCaseInsensitiveContains(query)
        || (document.category?.rawValue.localizedCaseInsensitiveContains(query) ?? false)
        || (document.doctorName?.localizedCaseInsensitiveContains(query) ?? false)
    }

    // MARK: - Grouped by Date

    struct DateSection: Identifiable {
        let id: String
        let title: String
        let documents: [Document]
    }

    var groupedDocuments: [DateSection] {
        let docs = filteredDocuments
        guard !docs.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()

        var todayDocs: [Document] = []
        var yesterdayDocs: [Document] = []
        var thisWeekDocs: [Document] = []
        var thisMonthDocs: [Document] = []
        // Keyed by a sortable year*12+month value so section ordering doesn't
        // depend on the incoming sort order (or on a localized title string).
        var olderByMonth: [Int: [Document]] = [:]

        for doc in docs {
            let date = doc.createdAt

            if calendar.isDateInToday(date) {
                todayDocs.append(doc)
            } else if calendar.isDateInYesterday(date) {
                yesterdayDocs.append(doc)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                thisWeekDocs.append(doc)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                thisMonthDocs.append(doc)
            } else {
                let parts = calendar.dateComponents([.year, .month], from: date)
                if let year = parts.year, let month = parts.month {
                    olderByMonth[year * 12 + month, default: []].append(doc)
                }
            }
        }

        var sections: [DateSection] = []
        if !todayDocs.isEmpty { sections.append(.init(id: "today", title: L10n.Documents.Section.today, documents: todayDocs)) }
        if !yesterdayDocs.isEmpty { sections.append(.init(id: "yesterday", title: L10n.Documents.Section.yesterday, documents: yesterdayDocs)) }
        if !thisWeekDocs.isEmpty { sections.append(.init(id: "week", title: L10n.Documents.Section.thisWeek, documents: thisWeekDocs)) }
        if !thisMonthDocs.isEmpty { sections.append(.init(id: "month", title: L10n.Documents.Section.thisMonth, documents: thisMonthDocs)) }

        let monthFormatter = DateFormatter()
        monthFormatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

        for (key, monthDocs) in olderByMonth.sorted(by: { $0.key > $1.key }) {
            let title = monthDocs
                .max(by: { $0.createdAt < $1.createdAt })
                .map { monthFormatter.string(from: $0.createdAt) } ?? ""
            sections.append(.init(id: "month-\(key)", title: title, documents: monthDocs))
        }

        // Sections are built newest-first; "Oldest First" reverses them so the
        // header order matches the order of the documents inside them.
        return sortOption == .oldest ? sections.reversed() : sections
    }

    // MARK: - Active filter count for badge

    var activeFilterCount: Int {
        var count = 0
        if selectedCategoryFilter != nil { count += 1 }
        if selectedSpecializationFilter != nil { count += 1 }
        if sortOption != .newest { count += 1 }
        return count
    }

    func clearFilters() {
        selectedCategoryFilter = nil
        selectedSpecializationFilter = nil
        sortOption = .newest
    }

    // MARK: - Subscription Lock

    /// The IDs of documents that are inaccessible because the subscription has expired.
    /// The 3 oldest documents (first uploaded) always remain accessible.
    ///
    /// Computed per account so it matches what the account actually shows —
    /// counting every account's documents would let the owner's uploads consume
    /// all three free slots and leave another account's only document locked.
    var lockedDocumentIDs: Set<UUID> {
        guard SubscriptionManager.shared.hasExpiredSubscription else { return [] }
        let scoped = spaceScopedDocuments
        let accessibleIDs = Set(scoped
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(3)
            .map(\.id))
        return Set(scoped.map(\.id)).subtracting(accessibleIDs)
    }

    func isLocked(_ document: Document) -> Bool {
        lockedDocumentIDs.contains(document.id)
    }

    // MARK: - Load

    func loadDocuments() {
        let fromDisk = fileManager.loadMetadata()
        let onDisk = fromDisk.filter { fileManager.fileExists(for: $0) }
        documents = onDisk.sorted { $0.createdAt > $1.createdAt }
        adoptLegacyFolders()
        reconcileOrphanFolders()

        // DIAGNOSTIC (missing-docs-on-launch investigation): pinpoints which stage
        // drops the documents when the app opens empty — metadata read, the
        // file-exists filter, or the active-space filter. Remove once resolved.
        SyncLog.info("loadDocuments — metadata=\(fromDisk.count) afterFileExists=\(onDisk.count) currentSpace=\(activeSpaceManager.currentSpaceID.uuidString.prefix(8)) spaceScoped=\(spaceScopedDocuments.count)")
    }

    /// Migrates folders created before folders were account-scoped. Such a
    /// folder has no `spaceID`, so it would otherwise appear in every account
    /// and — once scoping applies — every non-owner document filed inside it
    /// would look orphaned and get swept into "Other", losing the user's
    /// organisation. Each legacy folder is handed to the owner account, and any
    /// other account that had documents in it gets its own copy with those
    /// documents re-tagged. Runs once: afterwards no folder lacks a `spaceID`.
    private func adoptLegacyFolders() {
        let store = CustomFolderStore.shared
        let legacy = store.legacyFolders
        guard !legacy.isEmpty else { return }
        // Ownership is inferred from the documents filed in each folder, so never
        // run against an empty list: a cloud restore writes folders before
        // document metadata, and assigning every folder to the owner here would
        // orphan the other accounts' documents once that metadata lands.
        guard !documents.isEmpty else { return }

        var didRetag = false
        for folder in legacy {
            let tag = folder.id.uuidString
            let owningSpaceIDs = Set(
                documents
                    .filter { $0.tags?.contains(tag) == true }
                    .map { $0.spaceID ?? ActiveSpaceManager.defaultSpaceID }
            )

            store.assign(folder, to: ActiveSpaceManager.defaultSpaceID)

            for spaceID in owningSpaceIDs where spaceID != ActiveSpaceManager.defaultSpaceID {
                let copy = store.clone(folder, for: spaceID)
                didRetag = retag(tag, to: copy.id.uuidString, in: spaceID) || didRetag
            }
        }
        if didRetag { persistMetadata() }
    }

    /// Repoints one account's documents from `oldTag` to `newTag`.
    /// Returns whether anything changed.
    private func retag(_ oldTag: String, to newTag: String, in spaceID: UUID) -> Bool {
        var changed = false
        for index in documents.indices where belongsToSpace(documents[index], spaceID: spaceID) {
            guard let tags = documents[index].tags, tags.contains(oldTag) else { continue }
            documents[index].tags = tags.map { $0 == oldTag ? newTag : $0 }
            SyncQueueManager.shared.enqueueMetadataUpdate(documents[index])
            changed = true
        }
        return changed
    }

    /// Heals documents whose folder was lost (e.g. an app reinstall before
    /// folder sync existed): a doc with no category whose folder-UUID tag no
    /// longer matches any folder would render in no folder card at all. We file
    /// every such doc into the canonical "Other" folder and re-tag it to that
    /// folder's id. Idempotent — once a doc matches "Other" it's skipped, so
    /// this stops mutating after the first heal and never churns on relaunch.
    ///
    /// Scoped to the active account: folders and documents both belong to an
    /// account, so healing another account's documents here would silently
    /// re-file data the user isn't even looking at.
    private func reconcileOrphanFolders() {
        let existingFolderIDs = Set(CustomFolderStore.shared.foldersForActiveSpace.map { $0.id.uuidString })

        func isInExistingFolder(_ doc: Document) -> Bool {
            doc.tags?.contains { existingFolderIDs.contains($0) } == true
        }

        // A doc is "orphaned" when it has no category and isn't a member of any
        // folder that still exists. Categorised docs always show under their
        // category, so they can never go missing and are left untouched.
        let orphans = spaceScopedDocuments.filter { $0.category == nil && !isInExistingFolder($0) }
        guard !orphans.isEmpty else { return }

        let other = CustomFolderStore.shared.findOrCreate(name: CustomFolderStore.otherFolderName)
        let otherTag = other.id.uuidString

        for orphan in orphans {
            guard let index = documents.firstIndex(where: { $0.id == orphan.id }) else { continue }
            // Drop any stale folder-UUID tags (orphan references), keep free-text
            // tags, then point the doc at the current "Other" folder.
            let freeTextTags = (documents[index].tags ?? []).filter { UUID(uuidString: $0) == nil }
            documents[index].tags = freeTextTags + [otherTag]
            SyncQueueManager.shared.enqueueMetadataUpdate(documents[index])
        }
        persistMetadata()
    }

    // MARK: - Add Document (source picker)

    /// Captured when Add is tapped inside a folder, before a source is picked.
    private var destinationFromFolderButton: DocumentAddDestination?

    /// True after a source is chosen so dismissing the source picker (which
    /// happens *before* the scanner cover is presented) doesn't drop the snapshot.
    private var isContinuingAddFlow = false

    func showAddOptions(destination: DocumentAddDestination? = nil) {
        let sub = SubscriptionManager.shared
        guard sub.canUpload else {
            showPaywall = true
            return
        }
        destinationFromFolderButton = destination ?? folderContext
        pendingAddDestination = destinationFromFolderButton
        AnalyticsManager.shared.track(.addDocumentSheetOpened)
        showSourcePicker = true
    }

    func startScanning() {
        guard ensureCanUpload() else { return }
        lockInAddDestination()
        AnalyticsManager.shared.track(.documentScanStarted)
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showScanner = true
        }
    }

    func startPhotoUpload() {
        guard ensureCanUpload() else { return }
        lockInAddDestination()
        showSourcePicker = false
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showPhotoPicker = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] granted in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if granted == .authorized || granted == .limited {
                        self?.showPhotoPicker = true
                    } else {
                        self?.showPhotoPermissionAlert = true
                        self?.addFlowDidEnd()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showPhotoPermissionAlert = true
                self.addFlowDidEnd()
            }
        @unknown default:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showPhotoPicker = true
            }
        }
    }

    func startFileImport() {
        guard ensureCanUpload() else { return }
        lockInAddDestination()
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFileImporter = true
        }
    }

    func startGoogleDriveImport() {
        guard ensureCanUpload() else { return }
        lockInAddDestination()
        showSourcePicker = false
        if UserDefaults.standard.bool(forKey: Self.hasSeenDriveImportTipKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showFileImporter = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showDriveImportTip = true
            }
        }
    }

    func sourcePickerDidDismiss() {
        guard !isContinuingAddFlow else { return }
        addFlowDidEnd()
    }

    func addFlowDidEnd() {
        isContinuingAddFlow = false
        pendingAddDestination = nil
        destinationFromFolderButton = nil
        capturedFormDestination = nil
    }

    private func lockInAddDestination() {
        pendingAddDestination = destinationFromFolderButton ?? folderContext
        destinationFromFolderButton = nil
        isContinuingAddFlow = true
    }

    private func presentMetadataForm(_ preview: DocumentPreviewContent) {
        pendingPreview = preview
        capturedFormDestination = pendingAddDestination
        showMetadataForm = true
    }

    func confirmDriveImportTip() {
        UserDefaults.standard.set(true, forKey: Self.hasSeenDriveImportTipKey)
        showDriveImportTip = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFileImporter = true
        }
    }

    /// Authoritative upload gate for every source (scan / photo / file / Drive). Entry points
    /// (the FAB and `showAddOptions`) gate too, but this is the single chokepoint that
    /// guarantees a free user never exceeds the limit. Returns false (and shows the
    /// paywall) when the limit is reached.
    private func ensureCanUpload() -> Bool {
        guard SubscriptionManager.shared.canUpload else {
            showSourcePicker = false
            showPaywall = true
            return false
        }
        return true
    }

    // MARK: - Handle Scanner Result

    func handleScanResult(_ result: Result<[UIImage], Error>) {
        showScanner = false

        switch result {
        case .success(let images):
            guard !images.isEmpty else {
                addFlowDidEnd()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.presentMetadataForm(.scannedImages(images))
            }

        case .failure(let error):
            addFlowDidEnd()
            if case ScannerError.cancelled = error { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Handle Photo Selection

    func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        let items = Array(items.prefix(Self.photoSelectionLimit))
        isProcessing = true

        Task {
            defer {
                isProcessing = false
                selectedPhotoItems = []
            }

            do {
                var images: [UIImage] = []
                for item in items {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { continue }
                    images.append(image)
                }
                guard !images.isEmpty else {
                    addFlowDidEnd()
                    return
                }

                presentMetadataForm(.scannedImages(images))
            } catch {
                addFlowDidEnd()
                errorMessage = "Failed to load photo: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Handle File Import

    func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.presentMetadataForm(.importedFile(url))
            }

        case .failure(let error):
            addFlowDidEnd()
            if (error as NSError).code == NSUserCancelledError { return }
            errorMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Document with Metadata

    /// Guarantees every saved document lands in a folder. The Folders grid is
    /// organised by category / custom folder, so a document saved with neither
    /// would vanish from it.
    ///
    /// Prefer the folder the add was started from (Hospitalization, a custom
    /// folder, …). Only when that is also missing do we file under an
    /// auto-created "Other" custom folder.
    private func resolveFolder(for metadata: DocumentMetadata) -> DocumentMetadata {
        if metadata.category != nil || metadata.customFolderId != nil { return metadata }

        if let destination = pendingAddDestination ?? capturedFormDestination {
            var resolved = metadata
            switch destination {
            case .category(let category):
                resolved.category = category
            case .customFolder(let id):
                resolved.customFolderId = id
            }
            return resolved
        }

        var resolved = metadata
        resolved.customFolderId = CustomFolderStore.shared
            .findOrCreate(name: CustomFolderStore.otherFolderName).id
        return resolved
    }

    func saveDocument(metadata: DocumentMetadata, preview: DocumentPreviewContent) {
        isProcessing = true

        let metadata = resolveFolder(for: metadata)
        let spaceID = activeSpaceManager.currentSpaceID

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let fm = DocumentFileManager.shared

            do {
                var document: Document
                let source: String

                switch preview {
                case .scannedImages(let images):
                    document = try fm.savePDF(from: images, name: metadata.name)
                    source = "scan"

                case .importedFile(let url):
                    document = try fm.importFile(from: url, name: metadata.name)
                    source = "import"
                }

                // Apply metadata
                document.createdAt = metadata.documentDate
                document.category = metadata.category
                document.specialization = metadata.specialization
                if !metadata.doctorName.isEmpty { document.doctorName = metadata.doctorName }
                if !metadata.notes.isEmpty { document.notes = metadata.notes }
                document.expiryDate = metadata.expiryDate
                document.spaceID = spaceID
                if let folderId = metadata.customFolderId {
                    document.tags = (document.tags ?? []) + [folderId.uuidString]
                }

                await MainActor.run {
                    guard !self.documents.contains(where: { $0.id == document.id }) else {
                        self.isProcessing = false
                        return
                    }

                    self.documents.insert(document, at: 0)
                    self.persistMetadata()
                    self.rescheduleExpiryReminders()
                    SyncQueueManager.shared.enqueueUpload(document)
                    self.pendingPreview = nil
                    self.selectedPhotoItems = []
                    SubscriptionManager.shared.recordUpload()

                    // Value Moment: the user successfully added a health document.
                    // Only the source is tracked — never the medical document type (PII).
                    AnalyticsManager.shared.track(.documentSaved, properties: ["source": source])

                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.pendingPreview = nil
                    self.errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Rename

    func renameDocument(_ document: Document, to newName: String) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].name = newName
        persistMetadata()
        SyncQueueManager.shared.enqueueMetadataUpdate(documents[index])
    }

    // MARK: - Update (edit metadata and pages)

    func updateDocument(_ document: Document,
                        metadata: DocumentMetadata,
                        preview: DocumentPreviewContent) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        var updated = documents[index]

        let metadata = resolveFolder(for: metadata)

        // Apply metadata.
        updated.name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.createdAt = metadata.documentDate
        updated.category = metadata.category
        updated.specialization = metadata.specialization
        let doctor = metadata.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.doctorName = doctor.isEmpty ? nil : doctor
        let notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = notes.isEmpty ? nil : notes
        updated.tags = metadata.customFolderId.map { [$0.uuidString] }
        updated.expiryDate = metadata.expiryDate

        var fileBytesChanged = false

        // Re-save the file ONLY when the page count actually changed. A
        // metadata-only edit (e.g. rename) must stay lossless — re-rasterizing
        // the PDF/image on every save would degrade legibility. `pageCount` is
        // the PDF page count for scans/PDFs and 1 for single images, so an
        // unchanged count means no add/remove happened and we skip the rewrite.
        // Limitation: replacing a page with a fresh scan at the same count is
        // not detected (camera-only, rare).
        if case .scannedImages(let images) = preview, !images.isEmpty,
           images.count != updated.pageCount {
            do {
                let fm = DocumentFileManager.shared
                if updated.documentType == .image && images.count > 1 {
                    // Single image gained pages -> becomes a multi-page PDF.
                    let url = try fm.promoteImageToPDF(from: images, documentID: updated.id)
                    updated = Document(
                        id: updated.id,
                        name: updated.name,
                        fileURL: url,
                        createdAt: updated.createdAt,
                        documentType: .scan,
                        category: updated.category,
                        specialization: updated.specialization,
                        doctorName: updated.doctorName,
                        notes: updated.notes,
                        tags: updated.tags,
                        expiryDate: updated.expiryDate
                    )
                } else if updated.documentType == .image {
                    try fm.replaceImage(images[0], documentID: updated.id)
                } else {
                    try fm.replacePDF(from: images, documentID: updated.id)
                }
                fileBytesChanged = true
            } catch {
                errorMessage = "Failed to update document: \(error.localizedDescription)"
                return
            }
        }

        documents[index] = updated
        persistMetadata()
        rescheduleExpiryReminders()
        SyncQueueManager.shared.enqueueMetadataUpdate(updated)
        if fileBytesChanged {
            SyncQueueManager.shared.enqueueUpload(updated)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Delete

    func deleteDocument(_ document: Document) {
        do {
            try fileManager.deleteDocument(document)
            documents.removeAll { $0.id == document.id }
            persistMetadata()
            rescheduleExpiryReminders()
            SyncQueueManager.shared.enqueueDelete(document.id)
            SubscriptionManager.shared.recordDeletion()
            AnalyticsManager.shared.track(.documentDeleted, properties: ["category": document.category?.rawValue ?? "none"])
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Reminders

    /// Expiry reminders span every account by design, labelled with the owning
    /// account's name so they're never ambiguous.
    private func rescheduleExpiryReminders() {
        DocumentExpiryReminderScheduler.shared.reschedule(
            for: documents,
            accountNames: activeSpaceManager.namesBySpaceID
        )
    }

    // MARK: - Persistence

    private func persistMetadata() {
        do {
            try fileManager.saveMetadata(documents)
            // Broadcast so other screens with a cached snapshot (Home's recent
            // list) reload — they own a separate view model instance and would
            // otherwise stay stale after a mutation made on a different tab.
            NotificationCenter.default.post(name: .documentsChanged, object: nil)
        } catch {
            errorMessage = "Failed to save metadata: \(error.localizedDescription)"
        }
    }
}

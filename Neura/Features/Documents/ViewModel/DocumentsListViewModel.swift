import SwiftUI
import PhotosUI
import Combine

// MARK: - Display Mode

enum DocsDisplayMode {
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

@MainActor
final class DocumentsListViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var searchText = ""
    @Published var displayMode: DocsDisplayMode = .folders

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
    @Published var selectedPhotoItem: PhotosPickerItem?

    // File importer
    @Published var showFileImporter = false

    // Metadata form
    @Published var showMetadataForm = false
    @Published var pendingPreview: DocumentPreviewContent?

    // Processing
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let fileManager = DocumentFileManager.shared
    private var restoreObserver: NSObjectProtocol?

    init() {
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .documentsRestored, object: nil, queue: .main
        ) { [weak self] _ in self?.loadDocuments() }
    }

    // MARK: - Filtered & Sorted Documents

    var filteredDocuments: [Document] {
        var result = documents

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
            let query = searchText
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                || ($0.category?.rawValue.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.doctorName?.localizedCaseInsensitiveContains(query) ?? false)
            }
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

    // All documents sorted newest-first (no category/specialisation filter applied).
    var allFilesSorted: [Document] {
        documents.sorted { $0.createdAt > $1.createdAt }
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
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        var todayDocs: [Document] = []
        var yesterdayDocs: [Document] = []
        var thisWeekDocs: [Document] = []
        var thisMonthDocs: [Document] = []
        var olderByMonth: [String: [Document]] = [:]

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        for doc in docs {
            let docDay = calendar.startOfDay(for: doc.createdAt)

            if docDay >= today {
                todayDocs.append(doc)
            } else if docDay >= yesterday {
                yesterdayDocs.append(doc)
            } else if docDay >= weekAgo {
                thisWeekDocs.append(doc)
            } else if docDay >= monthAgo {
                thisMonthDocs.append(doc)
            } else {
                let key = monthFormatter.string(from: doc.createdAt)
                olderByMonth[key, default: []].append(doc)
            }
        }

        var sections: [DateSection] = []
        if !todayDocs.isEmpty { sections.append(.init(id: "today", title: L10n.Documents.Section.today, documents: todayDocs)) }
        if !yesterdayDocs.isEmpty { sections.append(.init(id: "yesterday", title: L10n.Documents.Section.yesterday, documents: yesterdayDocs)) }
        if !thisWeekDocs.isEmpty { sections.append(.init(id: "week", title: L10n.Documents.Section.thisWeek, documents: thisWeekDocs)) }
        if !thisMonthDocs.isEmpty { sections.append(.init(id: "month", title: L10n.Documents.Section.thisMonth, documents: thisMonthDocs)) }

        for (month, monthDocs) in olderByMonth.sorted(by: { $0.value.first!.createdAt > $1.value.first!.createdAt }) {
            sections.append(.init(id: month, title: month, documents: monthDocs))
        }

        return sections
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

    // MARK: - Load

    func loadDocuments() {
        var loaded = fileManager.loadMetadata()
        loaded = loaded.filter { fileManager.fileExists(for: $0) }
        documents = loaded.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Add Document (source picker)

    func showAddOptions() {
        let sub = SubscriptionManager.shared
        guard sub.canUpload else {
            showPaywall = true
            return
        }
        showSourcePicker = true
    }

    func startScanning() {
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showScanner = true
        }
    }

    func startPhotoUpload() {
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showPhotoPicker = true
        }
    }

    func startFileImport() {
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFileImporter = true
        }
    }

    // MARK: - Handle Scanner Result

    func handleScanResult(_ result: Result<[UIImage], Error>) {
        showScanner = false

        switch result {
        case .success(let images):
            guard !images.isEmpty else { return }
            pendingPreview = .scannedImages(images)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showMetadataForm = true
            }

        case .failure(let error):
            if case ScannerError.cancelled = error { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Handle Photo Selection

    func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                guard let image = UIImage(data: data) else { return }

                pendingPreview = .scannedImages([image])
                showMetadataForm = true
            } catch {
                errorMessage = "Failed to load photo: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Handle File Import

    func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            pendingPreview = .importedFile(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showMetadataForm = true
            }

        case .failure(let error):
            if (error as NSError).code == NSUserCancelledError { return }
            errorMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Document with Metadata

    func saveDocument(metadata: DocumentMetadata, preview: DocumentPreviewContent) {
        isProcessing = true

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let fm = DocumentFileManager.shared

            do {
                var document: Document

                switch preview {
                case .scannedImages(let images):
                    document = try fm.savePDF(from: images, name: metadata.name)

                case .importedFile(let url):
                    document = try fm.importFile(from: url, name: metadata.name)
                }

                // Apply metadata
                document.createdAt = metadata.documentDate
                document.category = metadata.category
                document.specialization = metadata.specialization
                if !metadata.doctorName.isEmpty { document.doctorName = metadata.doctorName }
                if !metadata.notes.isEmpty { document.notes = metadata.notes }
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
                    SyncQueueManager.shared.enqueueUpload(document)
                    self.pendingPreview = nil
                    self.selectedPhotoItem = nil
                    SubscriptionManager.shared.recordUpload()
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

    // MARK: - Delete

    func deleteDocument(_ document: Document) {
        do {
            try fileManager.deleteDocument(document)
            documents.removeAll { $0.id == document.id }
            persistMetadata()
            SyncQueueManager.shared.enqueueDelete(document.id)
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Persistence

    private func persistMetadata() {
        do {
            try fileManager.saveMetadata(documents)
        } catch {
            errorMessage = "Failed to save metadata: \(error.localizedDescription)"
        }
    }
}

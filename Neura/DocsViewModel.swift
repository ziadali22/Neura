//
//  DocsViewModel.swift
//  Neura
//
//  Created by ziad on 23/02/2026.
//

import Foundation
import SwiftUI
import Combine

class DocsViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var documents: [String: [Document]] = [:]
    @Published var selectedCategory: Category = .all
    @Published var folders: [CategoryFolder] = []

    // Scanner state
    @Published var showCategoryPicker: Bool = false
    @Published var showScanner: Bool = false
    @Published var showNamingView: Bool = false
    @Published var selectedFolderForScan: CategoryFolder?
    @Published var scannedImages: [UIImage] = []
    @Published var isProcessingScan: Bool = false
    @Published var scanError: String?
    @Published var recentlyScannedDocument: Document?

    private let fileManager = DocumentFileManager.shared

    init() {
        loadFolders()
        loadAllDocuments()
    }

    private func loadFolders() {
        folders = [
            CategoryFolder(
                name: "Blood Tests",
                count: fileManager.getDocumentCount(for: "Blood Tests"),
                icon: "drop.fill",
                gradientColors: [Color(hex: "BD6B73"), Color(hex: "A85861")]
            ),
            CategoryFolder(
                name: "Prescriptions",
                count: fileManager.getDocumentCount(for: "Prescriptions"),
                icon: "doc.text.fill",
                gradientColors: [Color(hex: "456990"), Color(hex: "3A5777")]
            ),
            CategoryFolder(
                name: "Consultations",
                count: fileManager.getDocumentCount(for: "Consultations"),
                icon: "stethoscope",
                gradientColors: [Color(hex: "6B9080"), Color(hex: "5A7A6C")]
            ),
            CategoryFolder(
                name: "Hospitalization",
                count: fileManager.getDocumentCount(for: "Hospitalization"),
                icon: "bed.double.fill",
                gradientColors: [Color(hex: "536B78"), Color(hex: "455863")]
            ),
            CategoryFolder(
                name: "Tests & Imaging",
                count: fileManager.getDocumentCount(for: "Tests & Imaging"),
                icon: "waveform.path.ecg",
                gradientColors: [Color(hex: "8B7E8F"), Color(hex: "756A79")]
            )
        ]
    }

    private func loadAllDocuments() {
        for folder in folders {
            loadDocuments(for: folder.name)
        }
    }

    private func loadDocuments(for category: String) {
        let documentGroups = fileManager.getAllDocuments(for: category)
        var loadedDocuments: [Document] = []

        for (_, fileURLs) in documentGroups {
            guard !fileURLs.isEmpty else { continue }

            let title = generateDocumentTitle(for: category)
            let date = getFileCreationDate(for: fileURLs.first ?? "") ?? Date()

            // Check if this is a PDF document
            if fileURLs.count == 1, fileURLs.first?.hasSuffix(".pdf") == true {
                // PDF document
                let document = Document(
                    title: title,
                    date: date,
                    pdfURL: fileURLs.first!,
                    category: category
                )
                loadedDocuments.append(document)
            } else {
                // Image-based document (backward compatibility)
                let document = Document(
                    title: title,
                    date: date,
                    imageURLs: fileURLs.sorted(),
                    category: category
                )
                loadedDocuments.append(document)
            }
        }

        documents[category] = loadedDocuments.sorted { $0.date > $1.date }
    }

    private func getFileCreationDate(for path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let creationDate = attributes[.creationDate] as? Date else {
            return nil
        }
        return creationDate
    }

    func handleFilterTap() {
        print("Filter tapped")
    }

    func handleAddDocument() {
        showCategoryPicker = true
    }

    func handleAddFolder() {
        print("Add folder tapped")
    }

    // MARK: - Scan Document

    func selectFolderForScan(_ folder: CategoryFolder) {
        selectedFolderForScan = folder
        showCategoryPicker = false

        // Small delay for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showScanner = true
        }
    }

    func scanFromFolder(_ folder: CategoryFolder) {
        selectedFolderForScan = folder
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showScanner = true
    }

    func handleScanResult(_ result: Result<[UIImage], Error>) {
        showScanner = false

        switch result {
        case .success(let images):
            guard !images.isEmpty else { return }
            scannedImages = images

            // Show naming view after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showNamingView = true
            }

        case .failure(let error):
            if case ScannerError.cancelled = error {
                // Silent dismissal for cancellation
                selectedFolderForScan = nil
                return
            }
            scanError = error.localizedDescription
        }
    }

    func saveDocumentWithName(_ name: String) {
        guard let folder = selectedFolderForScan else { return }
        saveScannedDocument(images: scannedImages, to: folder, customName: name)
    }

    func saveScannedDocument(images: [UIImage], to folder: CategoryFolder, customName: String? = nil) {
        isProcessingScan = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Generate PDF instead of saving individual images
            let result = self.fileManager.generateAndSavePDF(from: images, category: folder.name)

            DispatchQueue.main.async {
                switch result {
                case .success(let pdfPath):
                    let title = customName ?? self.generateDocumentTitle(for: folder.name)
                    let document = Document(
                        title: title,
                        date: Date(),
                        pdfURL: pdfPath,
                        category: folder.name
                    )

                    // Add to documents array
                    if self.documents[folder.name] == nil {
                        self.documents[folder.name] = []
                    }
                    self.documents[folder.name]?.insert(document, at: 0)

                    // Update folder count
                    self.updateFolderCount(for: folder.name, increment: 1)

                    // Success feedback
                    self.recentlyScannedDocument = document
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    // Clean up
                    self.scannedImages = []
                    self.selectedFolderForScan = nil

                    // Hide processing overlay after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isProcessingScan = false
                    }

                case .failure(let error):
                    self.isProcessingScan = false
                    self.scannedImages = []
                    self.selectedFolderForScan = nil
                    self.scanError = "Failed to save PDF: \(error.localizedDescription)"
                }
            }
        }
    }

    func updateFolderCount(for folderName: String, increment: Int) {
        if let index = folders.firstIndex(where: { $0.name == folderName }) {
            folders[index].count += increment
        }
    }

    func generateDocumentTitle(for category: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: Date())

        switch category {
        case "Blood Tests":
            return "Blood Test - \(dateString)"
        case "Prescriptions":
            return "Prescription - \(dateString)"
        case "Consultations":
            return "Consultation - \(dateString)"
        case "Hospitalization":
            return "Hospitalization - \(dateString)"
        case "Tests & Imaging":
            return "Test - \(dateString)"
        default:
            return "Document - \(dateString)"
        }
    }

    func deleteDocument(_ document: Document) {
        guard let category = document.category else { return }

        let result = fileManager.deleteDocument(imageURLs: document.imageURLs, pdfURL: document.pdfURL)

        switch result {
        case .success:
            documents[category]?.removeAll { $0.id == document.id }
            updateFolderCount(for: category, increment: -1)

        case .failure(let error):
            scanError = "Failed to delete document: \(error.localizedDescription)"
        }
    }
}

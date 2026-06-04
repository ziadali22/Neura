import Foundation
import UIKit
import PDFKit

// MARK: - Document File Error

enum DocumentFileError: LocalizedError {
    case directoryCreationFailed
    case imageConversionFailed
    case pdfGenerationFailed
    case pdfSaveFailed
    case fileNotFound
    case duplicateDocument(URL)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed: return "Failed to create storage directory"
        case .imageConversionFailed: return "Failed to convert image data"
        case .pdfGenerationFailed: return "Failed to generate PDF"
        case .pdfSaveFailed: return "Failed to save PDF to disk"
        case .fileNotFound: return "Document file not found"
        case .duplicateDocument(let url): return "Document already exists at \(url.lastPathComponent)"
        }
    }
}

// MARK: - Document File Manager

final class DocumentFileManager {
    static let shared = DocumentFileManager()

    private let baseDirectory = "NeuraScans"
    private let fileManager = FileManager.default
    private let metadataFile = "documents.json"

    private init() {
        createBaseDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var baseScanDirectory: URL {
        documentsDirectory.appendingPathComponent(baseDirectory)
    }

    private var metadataURL: URL {
        baseScanDirectory.appendingPathComponent(metadataFile)
    }

    private func createBaseDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: baseScanDirectory, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Failed to create base directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Save PDF

    func savePDF(data: Data, name: String, documentID: UUID = UUID()) throws -> Document {
        let filename = "\(documentID.uuidString).pdf"
        let fileURL = baseScanDirectory.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw DocumentFileError.duplicateDocument(fileURL)
        }

        try data.write(to: fileURL, options: .atomic)

        return Document(
            id: documentID,
            name: name,
            fileURL: fileURL,
            createdAt: Date(),
            documentType: .pdf
        )
    }

    func savePDF(from images: [UIImage], name: String, documentID: UUID = UUID()) throws -> Document {
        guard let pdfDocument = PDFGenerator.shared.generatePDF(from: images) else {
            throw DocumentFileError.pdfGenerationFailed
        }

        let filename = "\(documentID.uuidString).pdf"
        let fileURL = baseScanDirectory.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw DocumentFileError.duplicateDocument(fileURL)
        }

        guard pdfDocument.write(to: fileURL) else {
            throw DocumentFileError.pdfSaveFailed
        }

        return Document(
            id: documentID,
            name: name,
            fileURL: fileURL,
            createdAt: Date(),
            documentType: .scan
        )
    }

    // MARK: - Save Image

    func saveImage(_ image: UIImage, name: String, documentID: UUID = UUID()) throws -> Document {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw DocumentFileError.imageConversionFailed
        }

        let filename = "\(documentID.uuidString).jpg"
        let fileURL = baseScanDirectory.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw DocumentFileError.duplicateDocument(fileURL)
        }

        try imageData.write(to: fileURL, options: .atomic)

        return Document(
            id: documentID,
            name: name,
            fileURL: fileURL,
            createdAt: Date(),
            documentType: .image
        )
    }

    // MARK: - Load Document

    func loadDocument(url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else {
            throw DocumentFileError.fileNotFound
        }
        return try Data(contentsOf: url)
    }

    func loadPDF(url: URL) throws -> PDFDocument {
        guard fileManager.fileExists(atPath: url.path) else {
            throw DocumentFileError.fileNotFound
        }
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentFileError.pdfGenerationFailed
        }
        return pdf
    }

    func loadImage(url: URL) throws -> UIImage {
        guard fileManager.fileExists(atPath: url.path) else {
            throw DocumentFileError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw DocumentFileError.imageConversionFailed
        }
        return image
    }

    // MARK: - Import File (copy external file into sandbox)

    func importFile(from sourceURL: URL, name: String, documentID: UUID = UUID()) throws -> Document {
        let ext = sourceURL.pathExtension.lowercased()
        let filename = "\(documentID.uuidString).\(ext)"
        let fileURL = baseScanDirectory.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw DocumentFileError.duplicateDocument(fileURL)
        }

        // Access security-scoped resource if needed
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        try fileManager.copyItem(at: sourceURL, to: fileURL)

        let docType: DocumentType = (ext == "pdf") ? .pdf : .image

        return Document(
            id: documentID,
            name: name,
            fileURL: fileURL,
            createdAt: Date(),
            documentType: docType
        )
    }

    // MARK: - Delete Document

    func deleteDocument(id: UUID) throws {
        let pdfURL = baseScanDirectory.appendingPathComponent("\(id.uuidString).pdf")
        let jpgURL = baseScanDirectory.appendingPathComponent("\(id.uuidString).jpg")

        if fileManager.fileExists(atPath: pdfURL.path) {
            try fileManager.removeItem(at: pdfURL)
        } else if fileManager.fileExists(atPath: jpgURL.path) {
            try fileManager.removeItem(at: jpgURL)
        }
    }

    func deleteDocument(_ document: Document) throws {
        guard fileManager.fileExists(atPath: document.fileURL.path) else { return }
        try fileManager.removeItem(at: document.fileURL)
    }

    func deleteAllLocalDocuments() throws {
        if fileManager.fileExists(atPath: baseScanDirectory.path) {
            try fileManager.removeItem(at: baseScanDirectory)
        }
        createBaseDirectoryIfNeeded()
    }

    // MARK: - Metadata Persistence

    func saveMetadata(_ documents: [Document]) throws {
        let data = try JSONEncoder().encode(documents)
        try data.write(to: metadataURL, options: .atomic)
    }

    func loadMetadata() -> [Document] {
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let documents = try? JSONDecoder().decode([Document].self, from: data) else {
            return []
        }
        return documents
    }

    // MARK: - URL Resolution

    /// Resolve a filename to a full URL in the current sandbox directory.
    func resolveURL(for filename: String) -> URL {
        baseScanDirectory.appendingPathComponent(filename)
    }

    // MARK: - File Existence

    func fileExists(for document: Document) -> Bool {
        fileManager.fileExists(atPath: document.fileURL.path)
    }
}

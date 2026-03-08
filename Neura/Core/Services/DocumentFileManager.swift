import Foundation
import UIKit
import PDFKit

final class DocumentFileManager {
    static let shared = DocumentFileManager()

    private let baseDirectory = "NeuraScans"

    private init() {
        createBaseFoldersIfNeeded()
    }

    // MARK: - Directory Management

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func getBaseScanDirectory() -> URL {
        getDocumentsDirectory().appendingPathComponent(baseDirectory)
    }

    private func getCategoryDirectory(for category: String) -> URL {
        let sanitizedCategory = category.replacingOccurrences(of: " ", with: "")
                                       .replacingOccurrences(of: "&", with: "And")
        return getBaseScanDirectory().appendingPathComponent(sanitizedCategory)
    }

    private func createBaseFoldersIfNeeded() {
        let categories = ["BloodTests", "Prescriptions", "Consultations", "Hospitalization", "TestsAndImaging"]
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: getBaseScanDirectory(), withIntermediateDirectories: true)

            for category in categories {
                let categoryURL = getBaseScanDirectory().appendingPathComponent(category)
                try fileManager.createDirectory(at: categoryURL, withIntermediateDirectories: true)
            }
        } catch {
            assertionFailure("Failed to create base folders: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Images

    func saveScannedImages(_ images: [UIImage], category: String) -> Result<[String], Error> {
        let categoryDir = getCategoryDirectory(for: category)
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        var savedURLs: [String] = []

        do {
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)

            for (index, image) in images.enumerated() {
                let filename = "scan_\(category.lowercased().replacingOccurrences(of: " ", with: ""))_\(Int(timestamp))_\(uuid)_page\(index + 1).jpg"
                let fileURL = categoryDir.appendingPathComponent(filename)

                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "DocumentFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
                }

                try imageData.write(to: fileURL)
                savedURLs.append(fileURL.path)
            }

            return .success(savedURLs)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Save PDF

    func generateAndSavePDF(from images: [UIImage], category: String) -> Result<String, Error> {
        let categoryDir = getCategoryDirectory(for: category)
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        let filename = "scan_\(category.lowercased().replacingOccurrences(of: " ", with: ""))_\(Int(timestamp))_\(uuid).pdf"

        do {
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)

            let fileURL = categoryDir.appendingPathComponent(filename)
            let result = PDFGenerator.shared.generateAndSavePDF(from: images, to: fileURL)

            switch result {
            case .success(let url):
                return .success(url.path)
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }

    func loadPDF(from path: String) -> PDFDocument? {
        PDFDocument(url: URL(fileURLWithPath: path))
    }

    // MARK: - Load Images

    func loadImage(from path: String) -> UIImage? {
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    // MARK: - Delete Document

    func deleteDocument(imageURLs: [String] = [], pdfURL: String? = nil) -> Result<Void, Error> {
        let fileManager = FileManager.default

        do {
            if let pdfPath = pdfURL {
                let url = URL(fileURLWithPath: pdfPath)
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }

            for urlPath in imageURLs {
                let url = URL(fileURLWithPath: urlPath)
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Get Document Count

    func getDocumentCount(for category: String) -> Int {
        let categoryDir = getCategoryDirectory(for: category)

        do {
            let files = try FileManager.default.contentsOfDirectory(at: categoryDir, includingPropertiesForKeys: nil)
            let uniqueDocuments = Set(files.map { url in
                let filename = url.lastPathComponent
                let fileExtension = url.pathExtension.lowercased()
                let components = filename.components(separatedBy: "_")

                if components.count >= 4 {
                    if fileExtension == "pdf" {
                        return "\(components[2])_\(components[3].replacingOccurrences(of: ".pdf", with: ""))"
                    }
                    return "\(components[2])_\(components[3])"
                }
                return filename
            })
            return uniqueDocuments.count
        } catch {
            return 0
        }
    }

    // MARK: - Get All Documents

    func getAllDocuments(for category: String) -> [String: [String]] {
        let categoryDir = getCategoryDirectory(for: category)
        var documentGroups: [String: [String]] = [:]

        do {
            let files = try FileManager.default.contentsOfDirectory(at: categoryDir, includingPropertiesForKeys: [.creationDateKey])

            for file in files {
                let filename = file.lastPathComponent
                let fileExtension = file.pathExtension.lowercased()

                if fileExtension == "pdf" {
                    let components = filename.components(separatedBy: "_")
                    if components.count >= 4 {
                        let documentKey = "\(components[2])_\(components[3].replacingOccurrences(of: ".pdf", with: ""))"
                        documentGroups[documentKey] = [file.path]
                    }
                } else if fileExtension == "jpg" || fileExtension == "jpeg" {
                    let components = filename.components(separatedBy: "_")
                    if components.count >= 4 {
                        let documentKey = "\(components[2])_\(components[3])"
                        if documentGroups[documentKey] == nil {
                            documentGroups[documentKey] = []
                        }
                        documentGroups[documentKey]?.append(file.path)
                    }
                }
            }
        } catch {
            assertionFailure("Error loading documents: \(error.localizedDescription)")
        }

        return documentGroups
    }
}

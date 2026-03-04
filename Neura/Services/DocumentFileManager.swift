//
//  DocumentFileManager.swift
//  Neura
//
//  Created by ziad on 03/03/2026.
//

import Foundation
import UIKit
import PDFKit

class DocumentFileManager {
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
            print("Error creating base folders: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Images

    func saveScannedImages(_ images: [UIImage], category: String) -> Result<[String], Error> {
        let categoryDir = getCategoryDirectory(for: category)
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        var savedURLs: [String] = []

        do {
            // Ensure category directory exists
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)

            for (index, image) in images.enumerated() {
                let filename = "scan_\(category.lowercased().replacingOccurrences(of: " ", with: ""))_\(Int(timestamp))_\(uuid)_page\(index + 1).jpg"
                let fileURL = categoryDir.appendingPathComponent(filename)

                // Convert to JPEG with 0.8 quality
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "DocumentFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
                }

                try imageData.write(to: fileURL)
                savedURLs.append(fileURL.path)

                print("Saved image to: \(fileURL.path)")
            }

            return .success(savedURLs)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Save PDF

    /// Generate and save PDF from images
    func generateAndSavePDF(from images: [UIImage], category: String) -> Result<String, Error> {
        let categoryDir = getCategoryDirectory(for: category)
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        let filename = "scan_\(category.lowercased().replacingOccurrences(of: " ", with: ""))_\(Int(timestamp))_\(uuid).pdf"

        do {
            // Ensure category directory exists
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)

            let fileURL = categoryDir.appendingPathComponent(filename)
            let result = PDFGenerator.shared.generateAndSavePDF(from: images, to: fileURL)

            switch result {
            case .success(let url):
                print("Saved PDF to: \(url.path)")
                return .success(url.path)
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }

    /// Load PDF from path
    func loadPDF(from path: String) -> PDFDocument? {
        let url = URL(fileURLWithPath: path)
        return PDFDocument(url: url)
    }

    // MARK: - Load Images

    func loadImage(from path: String) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        guard let imageData = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    // MARK: - Delete Document

    func deleteDocument(imageURLs: [String] = [], pdfURL: String? = nil) -> Result<Void, Error> {
        let fileManager = FileManager.default

        do {
            // Delete PDF if present
            if let pdfPath = pdfURL {
                let url = URL(fileURLWithPath: pdfPath)
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }

            // Delete image files (backward compatibility)
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
            // Count unique document sets (group by timestamp and uuid)
            let uniqueDocuments = Set(files.map { url in
                let filename = url.lastPathComponent
                let fileExtension = url.pathExtension.lowercased()

                // Extract timestamp_uuid portion
                let components = filename.components(separatedBy: "_")
                if components.count >= 4 {
                    // For PDFs, remove the .pdf extension from the uuid component
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

                // Handle PDF files
                if fileExtension == "pdf" {
                    let components = filename.components(separatedBy: "_")
                    if components.count >= 4 {
                        // Extract timestamp_uuid (without .pdf extension)
                        let documentKey = "\(components[2])_\(components[3].replacingOccurrences(of: ".pdf", with: ""))"
                        documentGroups[documentKey] = [file.path]
                    }
                }
                // Handle JPEG files (backward compatibility)
                else if fileExtension == "jpg" || fileExtension == "jpeg" {
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
            print("Error loading documents: \(error.localizedDescription)")
        }

        return documentGroups
    }
}

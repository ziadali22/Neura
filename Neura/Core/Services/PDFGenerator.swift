import Foundation
import UIKit
import PDFKit

final class PDFGenerator {
    static let shared = PDFGenerator()

    private init() {}

    // MARK: - PDF Generation

    func generatePDF(from images: [UIImage]) -> PDFDocument? {
        let pdfDocument = PDFDocument()

        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: index)
        }

        guard pdfDocument.pageCount > 0 else { return nil }
        return pdfDocument
    }

    func savePDF(_ pdf: PDFDocument, to url: URL) -> Bool {
        pdf.write(to: url)
    }

    func generateAndSavePDF(from images: [UIImage], to url: URL) -> Result<URL, Error> {
        guard let pdf = generatePDF(from: images) else {
            return .failure(PDFError.generationFailed)
        }

        guard pdf.write(to: url) else {
            return .failure(PDFError.saveFailed)
        }

        return .success(url)
    }
}

// MARK: - PDF Errors

enum PDFError: LocalizedError {
    case generationFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate PDF from images"
        case .saveFailed:
            return "Failed to save PDF to disk"
        }
    }
}

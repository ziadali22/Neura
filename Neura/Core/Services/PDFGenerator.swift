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

    /// Render each page of a PDF file to a UIImage. Returns [] if the file
    /// can't be opened. Used to seed the page editor when editing a scan.
    func renderImages(from url: URL, maxDimension: CGFloat = 2000) -> [UIImage] {
        guard let pdf = PDFDocument(url: url) else { return [] }
        var images: [UIImage] = []
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            guard pageRect.width > 0, pageRect.height > 0 else { continue }

            // Scale so the longest side is at most maxDimension.
            let scale = min(1, maxDimension / max(pageRect.width, pageRect.height))
            let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }
        return images
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

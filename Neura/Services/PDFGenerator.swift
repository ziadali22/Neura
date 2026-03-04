//
//  PDFGenerator.swift
//  Neura
//
//  Created by Claude Code on 03/03/2026.
//

import Foundation
import UIKit
import PDFKit

class PDFGenerator {
    static let shared = PDFGenerator()

    private init() {}

    // MARK: - PDF Generation

    /// Generate PDF document from array of images
    func generatePDF(from images: [UIImage]) -> PDFDocument? {
        print("PDFGenerator: Generating PDF from \(images.count) images")
        let pdfDocument = PDFDocument()

        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else {
                print("PDFGenerator: ERROR - Failed to create PDF page from image at index \(index)")
                continue
            }
            pdfDocument.insert(page, at: index)
            print("PDFGenerator: Added page \(index + 1) to PDF")
        }

        // Ensure at least one page was added
        guard pdfDocument.pageCount > 0 else {
            print("PDFGenerator: ERROR - No pages added to PDF")
            return nil
        }

        print("PDFGenerator: PDF created successfully with \(pdfDocument.pageCount) pages")
        return pdfDocument
    }

    /// Save PDF document to disk
    func savePDF(_ pdf: PDFDocument, to url: URL) -> Bool {
        return pdf.write(to: url)
    }

    /// Generate and save PDF in one step
    func generateAndSavePDF(from images: [UIImage], to url: URL) -> Result<URL, Error> {
        guard let pdf = generatePDF(from: images) else {
            print("PDFGenerator: ERROR - PDF generation failed")
            return .failure(PDFError.generationFailed)
        }

        print("PDFGenerator: Attempting to write PDF to: \(url.path)")
        guard pdf.write(to: url) else {
            print("PDFGenerator: ERROR - Failed to write PDF to disk")
            return .failure(PDFError.saveFailed)
        }

        print("PDFGenerator: PDF written successfully to: \(url.path)")
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

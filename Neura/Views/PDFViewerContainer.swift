//
//  PDFViewerContainer.swift
//  Neura
//
//  Created by Claude Code on 03/03/2026.
//

import SwiftUI
import PDFKit

struct PDFViewerContainer: UIViewRepresentable {
    let pdfURL: String

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black

        loadPDF(into: pdfView)

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update PDF if URL changes
        if pdfView.document == nil {
            loadPDF(into: pdfView)
        }
    }

    private func loadPDF(into pdfView: PDFView) {
        print("PDFViewerContainer: Attempting to load PDF from: \(pdfURL)")

        let url = URL(fileURLWithPath: pdfURL)

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        print("PDFViewerContainer: File exists at path: \(fileExists)")

        if fileExists {
            if let document = PDFDocument(url: url) {
                print("PDFViewerContainer: PDF loaded successfully. Page count: \(document.pageCount)")
                pdfView.document = document
            } else {
                print("PDFViewerContainer: ERROR - Failed to create PDFDocument from URL")
            }
        } else {
            print("PDFViewerContainer: ERROR - File does not exist at path: \(url.path)")
        }
    }
}

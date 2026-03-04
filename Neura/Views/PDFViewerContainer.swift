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
        let url = URL(fileURLWithPath: pdfURL)
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}

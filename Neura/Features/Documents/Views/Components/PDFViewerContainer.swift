import SwiftUI
import PDFKit

struct PDFViewerContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black

        if FileManager.default.fileExists(atPath: url.path) {
            pdfView.document = PDFDocument(url: url)
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil, FileManager.default.fileExists(atPath: url.path) {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

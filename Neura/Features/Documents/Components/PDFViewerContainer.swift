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
        if pdfView.document == nil {
            loadPDF(into: pdfView)
        }
    }

    private func loadPDF(into pdfView: PDFView) {
        let url = URL(fileURLWithPath: pdfURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        pdfView.document = PDFDocument(url: url)
    }
}

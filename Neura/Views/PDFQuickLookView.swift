//
//  PDFQuickLookView.swift
//  Neura
//
//  Created by Claude Code on 03/03/2026.
//

import SwiftUI
import QuickLook

struct PDFQuickLookView: UIViewControllerRepresentable {
    let pdfURL: String

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(pdfURL: pdfURL)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let pdfURL: String

        init(pdfURL: String) {
            self.pdfURL = pdfURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            let url = URL(fileURLWithPath: pdfURL)
            print("PDFQuickLookView: Loading PDF from: \(url.path)")
            print("PDFQuickLookView: File exists: \(FileManager.default.fileExists(atPath: url.path))")
            return url as QLPreviewItem
        }
    }
}

import Foundation
import PDFKit

struct Document: Identifiable, Equatable {
    var id = UUID()
    let title: String
    let date: Date
    let imageURLs: [String]
    let pdfURL: String?
    let category: String?

    var isPDF: Bool {
        pdfURL != nil
    }

    var thumbnailURL: String? {
        imageURLs.first
    }

    var pageCount: Int {
        if isPDF, let pdfPath = pdfURL {
            let url = URL(fileURLWithPath: pdfPath)
            if let pdfDocument = PDFDocument(url: url) {
                return pdfDocument.pageCount
            }
        }
        return imageURLs.count
    }

    init(title: String, date: Date, pdfURL: String, category: String?) {
        self.title = title
        self.date = date
        self.pdfURL = pdfURL
        self.imageURLs = []
        self.category = category
    }

    init(title: String, date: Date, imageURLs: [String], category: String?) {
        self.title = title
        self.date = date
        self.imageURLs = imageURLs
        self.pdfURL = nil
        self.category = category
    }

    init(id: UUID = UUID(), title: String, date: Date, imageURL: String?, category: String?) {
        self.id = id
        self.title = title
        self.date = date
        self.imageURLs = imageURL != nil ? [imageURL!] : []
        self.pdfURL = nil
        self.category = category
    }
}

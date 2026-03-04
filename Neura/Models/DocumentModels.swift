//
//  DocumentModels.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import Foundation
import SwiftUI
import PDFKit

// MARK: - Document
struct Document: Identifiable, Equatable {
    var id = UUID()
    let title: String
    let date: Date
    let imageURLs: [String]
    let pdfURL: String?
    let category: String?

    // Computed property for checking if document is PDF
    var isPDF: Bool {
        pdfURL != nil
    }

    // Computed property for thumbnail
    var thumbnailURL: String? {
        imageURLs.first
    }

    // Page count computed property
    var pageCount: Int {
        if isPDF, let pdfPath = pdfURL {
            let url = URL(fileURLWithPath: pdfPath)
            if let pdfDocument = PDFDocument(url: url) {
                return pdfDocument.pageCount
            }
        }
        return imageURLs.count
    }

    // PDF initializer - primary format for new scans
    init(title: String, date: Date, pdfURL: String, category: String?) {
        self.title = title
        self.date = date
        self.pdfURL = pdfURL
        self.imageURLs = []
        self.category = category
    }

    // Image-based initializer - backward compatibility for existing documents
    init(title: String, date: Date, imageURLs: [String], category: String?) {
        self.title = title
        self.date = date
        self.imageURLs = imageURLs
        self.pdfURL = nil
        self.category = category
    }

    // Legacy initializer for backward compatibility
    init(id: UUID = UUID(), title: String, date: Date, imageURL: String?, category: String?) {
        self.id = id
        self.title = title
        self.date = date
        self.imageURLs = imageURL != nil ? [imageURL!] : []
        self.pdfURL = nil
        self.category = category
    }
}

// MARK: - Category
enum Category: String, CaseIterable, Identifiable {
    case all = "All"
    case cardiology = "Cardiology"
    case neurology = "Neurology"
    case gynaecology = "Gynaecology"

    var id: String { rawValue }
}

// MARK: - CategoryFolder
struct CategoryFolder: Identifiable {
    let id = UUID()
    let name: String
    var count: Int
    let icon: String
    let gradientColors: [Color]
}

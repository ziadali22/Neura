import Foundation
import PDFKit
import SwiftUI

// MARK: - Document Type

enum DocumentType: String, Codable {
    case scan
    case pdf
    case image

    var localizedName: String {
        switch self {
        case .scan: return String(localized: "Scan")
        case .pdf: return String(localized: "PDF")
        case .image: return String(localized: "Image")
        }
    }
}

// MARK: - Document Category

enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case bloodTests = "Blood Tests"
    case medicalLetter = "Medical Letter"
    case consultations = "Consultations"
    case prescriptions = "Prescriptions"
    case hospitalization = "Hospitalization"
    case vaccination = "Vaccination"
    case imaging = "Imaging"
    case other = "Other"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }

    var icon: String {
        switch self {
        case .bloodTests: return "drop.fill"
        case .medicalLetter: return "envelope.fill"
        case .consultations: return "stethoscope"
        case .prescriptions: return "pill.fill"
        case .hospitalization: return "bed.double.fill"
        case .vaccination: return "syringe.fill"
        case .imaging: return "waveform.path.ecg"
        case .other: return "doc.fill"
        }
    }

    /// Custom asset icon name from Assets.xcassets/Docs, nil if SF Symbol only.
    var assetIcon: String? {
        switch self {
        case .bloodTests: return "Blood"
        case .medicalLetter: return "Letter"
        case .consultations: return "Consultation"
        case .prescriptions: return "Prescriptions"
        case .hospitalization: return "Hospitalisation"
        case .vaccination: return "Vaccination"
        case .imaging: return "Investigationspdf"
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .bloodTests: return Color(hex: "E74C3C")
        case .medicalLetter: return Color(hex: "27AE60")
        case .consultations: return Color(hex: "3498DB")
        case .prescriptions: return Color(hex: "9B59B6")
        case .hospitalization: return Color(hex: "536B78")
        case .vaccination: return Color(hex: "2ECC71")
        case .imaging: return Color(hex: "1ABC9C")
        case .other: return Color(hex: "95A5A6")
        }
    }
}

// MARK: - Medical Specialization

enum MedicalSpecialization: String, Codable, CaseIterable, Identifiable {
    case cardiology      = "Cardiology"
    case dermatology     = "Dermatology"
    case dentistry       = "Dentistry"
    case endocrinology   = "Endocrinology"
    case gastroenterology = "Gastroenterology"
    case generalMedicine = "General Medicine"
    case gynaecology     = "Gynaecology"
    case neurology       = "Neurology"
    case oncology        = "Oncology"
    case ophthalmology   = "Ophthalmology"
    case orthopaedics    = "Orthopaedics"
    case pulmonology     = "Pulmonology"
    case psychiatry      = "Psychiatry"
    case surgery         = "Surgery"
    case urology         = "Urology"
    case other           = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cardiology:       return "heart.fill"
        case .dermatology:      return "wand.and.sparkles"
        case .dentistry:        return "mouth.fill"
        case .endocrinology:    return "drop.circle.fill"
        case .gastroenterology: return "cross.case.fill"
        case .generalMedicine:  return "stethoscope"
        case .gynaecology:      return "figure.stand.dress"
        case .neurology:        return "brain.head.profile"
        case .oncology:         return "shield.lefthalf.filled"
        case .ophthalmology:    return "eye.fill"
        case .orthopaedics:     return "figure.walk"
        case .pulmonology:      return "lungs.fill"
        case .psychiatry:       return "brain"
        case .surgery:          return "scissors"
        case .urology:          return "drop.triangle.fill"
        case .other:            return "ellipsis.circle"
        }
    }
}

// MARK: - Document Model

struct Document: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    /// The filename only (e.g. "ABC123.pdf"). The full URL is resolved at runtime.
    var filename: String
    var createdAt: Date
    let documentType: DocumentType
    var category: DocumentCategory?
    var doctorName: String?
    var notes: String?
    var tags: [String]?
    var specialization: MedicalSpecialization?

    /// Full resolved URL in the current sandbox. Not encoded.
    var fileURL: URL {
        DocumentFileManager.shared.resolveURL(for: filename)
    }

    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        createdAt: Date = Date(),
        documentType: DocumentType,
        category: DocumentCategory? = nil,
        specialization: MedicalSpecialization? = nil,
        doctorName: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.filename = fileURL.lastPathComponent
        self.createdAt = createdAt
        self.documentType = documentType
        self.category = category
        self.specialization = specialization
        self.doctorName = doctorName
        self.notes = notes
        self.tags = tags
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, filename, createdAt, documentType, category, specialization, doctorName, notes, tags
        // Legacy key for backward compatibility
        case fileURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        documentType = try container.decode(DocumentType.self, forKey: .documentType)
        category = try container.decodeIfPresent(DocumentCategory.self, forKey: .category)
        specialization = try container.decodeIfPresent(MedicalSpecialization.self, forKey: .specialization)
        doctorName = try container.decodeIfPresent(String.self, forKey: .doctorName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        // Try new filename key first, fall back to extracting from legacy fileURL
        if let fn = try container.decodeIfPresent(String.self, forKey: .filename) {
            filename = fn
        } else if let url = try container.decodeIfPresent(URL.self, forKey: .fileURL) {
            filename = url.lastPathComponent
        } else {
            filename = "\(id.uuidString).pdf"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(filename, forKey: .filename)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(documentType, forKey: .documentType)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(specialization, forKey: .specialization)
        try container.encodeIfPresent(doctorName, forKey: .doctorName)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(tags, forKey: .tags)
    }

    // MARK: - Computed Properties

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    var isPDF: Bool {
        documentType == .pdf || documentType == .scan
    }

    var isImage: Bool {
        documentType == .image
    }

    var pageCount: Int {
        guard isPDF, let pdfDocument = PDFDocument(url: fileURL) else { return 1 }
        return pdfDocument.pageCount
    }

    var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }
}

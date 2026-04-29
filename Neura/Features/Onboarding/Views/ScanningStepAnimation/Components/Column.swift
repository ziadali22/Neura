import SwiftUI

struct Column: Identifiable, Hashable {
    var id: UUID = .init()
    let position: Int
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let documentName: String
    var isExpanded: Bool = false
    var isCompleted: Bool = false

    // MARK: - Presets

    static let scan = Column(
        position: 0,
        title: "Scan",
        subtitle: "Point at any document",
        icon: "doc.viewfinder",
        accentColor: Color(hex:"ff8d29"),
        documentName: "BloodTest_March.pdf"
    )

    static let organize = Column(
        position: 1,
        title: "Organize",
        subtitle: "Auto-categorized by type",
        icon: "folder.fill",
        accentColor: Color(hex:"0088ff"),
        documentName: "Prescription_2026.pdf"
    )

    static let share = Column(
        position: 2,
        title: "Share",
        subtitle: "Send to your doctor instantly",
        icon: "square.and.arrow.up",
        accentColor: Color(hex:"34c759"),
        documentName: "ConsultationNote.pdf",
        isCompleted: true
    )
}

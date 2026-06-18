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

    static var scan: Column {
        Column(
            position: 0,
            title: L10n.Onboarding.Scanning.scanLabel,
            subtitle: L10n.Onboarding.Scanning.scanSubtitleText,
            icon: "doc.viewfinder",
            accentColor: Color(hex:"ff8d29"),
            documentName: "BloodTest_March.pdf"
        )
    }

    static var organize: Column {
        Column(
            position: 1,
            title: L10n.Onboarding.Scanning.organizeLabel,
            subtitle: L10n.Onboarding.Scanning.organizeSubtitle,
            icon: "folder.fill",
            accentColor: Color(hex:"0088ff"),
            documentName: "Prescription_2026.pdf"
        )
    }

    static var share: Column {
        Column(
            position: 2,
            title: L10n.Onboarding.Scanning.shareLabel,
            subtitle: L10n.Onboarding.Scanning.shareSubtitleText,
            icon: "square.and.arrow.up",
            accentColor: Color(hex:"34c759"),
            documentName: "ConsultationNote.pdf",
            isCompleted: true
        )
    }
}

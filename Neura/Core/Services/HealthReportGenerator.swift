import UIKit
import PDFKit

final class HealthReportGenerator {

    // MARK: - Colors

    private let accent = UIColor(red: 1.0, green: 0.353, blue: 0.0, alpha: 1)       // #FF5A00
    private let textPrimary = UIColor(red: 0.122, green: 0.122, blue: 0.122, alpha: 1)
    private let textSecondary = UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1)
    private let textTertiary = UIColor(red: 0.48, green: 0.48, blue: 0.48, alpha: 1)
    private let divider = UIColor(red: 0.91, green: 0.88, blue: 0.85, alpha: 1)
    private let cardBg = UIColor.white
    private let pageBg = UIColor(red: 0.988, green: 0.98, blue: 0.973, alpha: 1)

    // MARK: - Fonts

    private let titleFont = UIFont.systemFont(ofSize: 32, weight: .heavy)
    private let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    private let sectionTitleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
    private let labelFont = UIFont.systemFont(ofSize: 11, weight: .bold)
    private let valueFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    private let bodyFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    private let smallFont = UIFont.systemFont(ofSize: 10, weight: .medium)

    // MARK: - Layout

    private let pageW: CGFloat = 595.0
    private let pageH: CGFloat = 842.0
    private let margin: CGFloat = 44.0
    private var contentW: CGFloat { pageW - margin * 2 }

    private var y: CGFloat = 0
    private var pageNumber = 0
    private var ctx: UIGraphicsPDFRendererContext!

    // MARK: - Generate

    func generate(profile: HealthProfile, documents: [Document]) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        let sortedDocs = documents
            .filter { $0.fileExists }
            .sorted { $0.createdAt > $1.createdAt }

        let data = renderer.pdfData { context in
            self.ctx = context
            self.pageNumber = 0

            drawCoverPage(profile: profile, documentCount: sortedDocs.count)
            drawHealthProfilePages(profile: profile)
            drawDocumentInventoryPages(documents: sortedDocs)
            drawTimelinePages(profile: profile, documents: sortedDocs)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Neura_Health_Report.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Cover Page

    private func drawCoverPage(profile: HealthProfile, documentCount: Int) {
        beginPage()

        // Orange accent bar at top
        accent.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: 6)).fill()

        // Neura branding
        y = 80
        let neuraBrand = NSAttributedString(string: "NEURA", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .heavy),
            .foregroundColor: accent,
            .kern: 4.0
        ])
        neuraBrand.draw(at: CGPoint(x: margin, y: y))
        y += 40

        // Title
        let title = NSAttributedString(string: "Health Report", attributes: [
            .font: UIFont.systemFont(ofSize: 42, weight: .heavy),
            .foregroundColor: textPrimary
        ])
        title.draw(at: CGPoint(x: margin, y: y))
        y += 56

        // Subtitle
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let subtitle = NSAttributedString(string: "Generated \(dateFormatter.string(from: Date()))", attributes: [
            .font: subtitleFont,
            .foregroundColor: textTertiary
        ])
        subtitle.draw(at: CGPoint(x: margin, y: y))
        y += 50

        // Orange divider
        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: 60, height: 4), cornerRadius: 2).fill()
        y += 40

        // Patient info card
        let gd = profile.generalData
        drawCardStart()
        let infoFields: [(String, String)] = [
            ("Patient Name", gd.fullName),
            ("Date of Birth", gd.dateOfBirth),
            ("Gender", gd.gender),
            ("Blood Type", gd.bloodType),
            ("Insurance", gd.insuranceStatus),
            ("Emergency Contact", gd.emergencyContact),
        ].filter { !$1.isEmpty }

        for (i, field) in infoFields.enumerated() {
            drawFieldRow(label: field.0, value: field.1, y: y)
            y += 30
            if i < infoFields.count - 1 {
                drawDivider(indented: false)
            }
        }
        drawCardEnd(startY: y - CGFloat(infoFields.count) * 30 - 16)

        // Stats row at bottom
        y = pageH - 140
        let stats: [(String, String)] = [
            ("\(documentCount)", "Documents"),
            ("\(profile.sections.flatMap(\.entries).count)", "Health Entries"),
            ("\(profile.sections.count)", "Categories"),
        ]

        let statW = contentW / CGFloat(stats.count)
        for (i, stat) in stats.enumerated() {
            let x = margin + CGFloat(i) * statW
            let numStr = NSAttributedString(string: stat.0, attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold), .foregroundColor: accent
            ])
            let labelStr = NSAttributedString(string: stat.1, attributes: [
                .font: smallFont, .foregroundColor: textTertiary
            ])
            numStr.draw(at: CGPoint(x: x, y: y))
            labelStr.draw(at: CGPoint(x: x, y: y + 34))
        }

        drawPageFooter()
    }

    // MARK: - Health Profile Pages

    private func drawHealthProfilePages(profile: HealthProfile) {
        beginPage()
        drawSectionHeader("Health Profile")

        // General Data
        let gd = profile.generalData
        let fields: [(String, String)] = [
            ("Full Name", gd.fullName),
            ("Date of Birth", gd.dateOfBirth),
            ("Gender", gd.gender),
            ("Height", gd.height),
            ("Weight", gd.weight),
            ("Blood Type", gd.bloodType),
            ("Insurance Status", gd.insuranceStatus),
            ("Emergency Contact", gd.emergencyContact),
        ].filter { !$1.isEmpty }

        if !fields.isEmpty {
            drawSubsectionHeader("General Data")
            let cardStartY = y
            drawCardStart()
            for (i, field) in fields.enumerated() {
                ensureSpace(32)
                drawFieldRow(label: field.0, value: field.1, y: y)
                y += 30
                if i < fields.count - 1 { drawDivider(indented: true) }
            }
            y += 8
        }

        // Sections
        for section in profile.sections {
            guard !section.entries.isEmpty else { continue }

            ensureSpace(60)
            drawSubsectionHeader(section.title)

            for (i, entry) in section.entries.enumerated() {
                ensureSpace(40)

                // Bullet
                accent.setFill()
                UIBezierPath(ovalIn: CGRect(x: margin + 4, y: y + 6, width: 6, height: 6)).fill()

                let entryStr = NSAttributedString(string: entry.text, attributes: [
                    .font: valueFont, .foregroundColor: textPrimary
                ])
                entryStr.draw(at: CGPoint(x: margin + 18, y: y))
                y += 20

                if !entry.field1.isEmpty || !entry.field2.isEmpty {
                    var details = [String]()
                    if !entry.field1.isEmpty { details.append(entry.field1) }
                    if !entry.field2.isEmpty { details.append(entry.field2) }
                    let detailStr = NSAttributedString(string: details.joined(separator: "  ·  "), attributes: [
                        .font: bodyFont, .foregroundColor: textTertiary
                    ])
                    detailStr.draw(at: CGPoint(x: margin + 18, y: y))
                    y += 18
                }

                if !entry.notes.isEmpty {
                    let noteStr = NSAttributedString(string: "Note: \(entry.notes)", attributes: [
                        .font: bodyFont, .foregroundColor: textTertiary
                    ])
                    noteStr.draw(at: CGPoint(x: margin + 18, y: y))
                    y += 18
                }

                if i < section.entries.count - 1 {
                    y += 4
                    drawDivider(indented: true)
                    y += 4
                }
            }
            y += 16
        }

        drawPageFooter()
    }

    // MARK: - Document Inventory Pages

    private func drawDocumentInventoryPages(documents: [Document]) {
        guard !documents.isEmpty else { return }

        beginPage()
        drawSectionHeader("Document Inventory")

        // Group by category
        let grouped = Dictionary(grouping: documents.filter { $0.category != nil }) { $0.category! }
        let sortedCategories = grouped.keys.sorted { $0.rawValue < $1.rawValue }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        for category in sortedCategories {
            guard let docs = grouped[category] else { continue }

            ensureSpace(50)
            drawSubsectionHeader("\(category.localizedName) (\(docs.count))")

            for (i, doc) in docs.enumerated() {
                ensureSpace(50)

                // Doc name
                let nameStr = NSAttributedString(string: doc.name, attributes: [
                    .font: valueFont, .foregroundColor: textPrimary
                ])
                nameStr.draw(at: CGPoint(x: margin + 4, y: y))

                // Type badge on right
                let typeStr = NSAttributedString(string: doc.documentType.localizedName.uppercased(), attributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: accent
                ])
                let typeW = typeStr.size().width
                typeStr.draw(at: CGPoint(x: pageW - margin - typeW, y: y + 2))
                y += 20

                // Details line
                var details = [dateFormatter.string(from: doc.createdAt)]
                if doc.isPDF && doc.pageCount > 1 { details.append("\(doc.pageCount) pages") }
                if let doctor = doc.doctorName, !doctor.isEmpty { details.append("Dr. \(doctor)") }

                let detailStr = NSAttributedString(string: details.joined(separator: "  ·  "), attributes: [
                    .font: bodyFont, .foregroundColor: textTertiary
                ])
                detailStr.draw(at: CGPoint(x: margin + 4, y: y))
                y += 18

                if let notes = doc.notes, !notes.isEmpty {
                    let noteStr = NSAttributedString(string: notes, attributes: [
                        .font: bodyFont, .foregroundColor: textTertiary
                    ])
                    noteStr.draw(at: CGPoint(x: margin + 4, y: y))
                    y += 18
                }

                if i < docs.count - 1 {
                    y += 2
                    drawDivider(indented: false)
                    y += 6
                }
            }
            y += 16
        }

        drawPageFooter()
    }

    // MARK: - Timeline Pages

    private func drawTimelinePages(profile: HealthProfile, documents: [Document]) {
        struct TimelineEvent {
            let date: Date
            let title: String
            let subtitle: String
            let type: String // "document" or "profile"
        }

        var events = [TimelineEvent]()

        // Add documents
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        for doc in documents {
            let sub = [doc.category?.localizedName, doc.doctorName.flatMap { $0.isEmpty ? nil : "Dr. \($0)" }]
                .compactMap { $0 }
                .joined(separator: " · ")
            events.append(TimelineEvent(date: doc.createdAt, title: doc.name, subtitle: sub, type: "document"))
        }

        // Add profile update
        events.append(TimelineEvent(
            date: profile.lastUpdated,
            title: "Health Profile Updated",
            subtitle: "\(profile.sections.flatMap(\.entries).count) entries across \(profile.sections.count) sections",
            type: "profile"
        ))

        events.sort { $0.date > $1.date }

        guard !events.isEmpty else { return }

        beginPage()
        drawSectionHeader("Health Timeline")

        for (i, event) in events.enumerated() {
            ensureSpace(55)

            // Timeline dot and line
            let dotX = margin + 6
            let dotY = y + 5

            accent.setFill()
            UIBezierPath(ovalIn: CGRect(x: dotX - 4, y: dotY - 4, width: 8, height: 8)).fill()

            if i < events.count - 1 {
                UIColor(white: 0.88, alpha: 1).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: dotX, y: dotY + 6))
                line.addLine(to: CGPoint(x: dotX, y: dotY + 42))
                line.lineWidth = 1.0
                line.stroke()
            }

            // Date
            let dateStr = NSAttributedString(string: dateFormatter.string(from: event.date), attributes: [
                .font: smallFont, .foregroundColor: accent
            ])
            dateStr.draw(at: CGPoint(x: margin + 22, y: y))
            y += 16

            // Title
            let titleStr = NSAttributedString(string: event.title, attributes: [
                .font: valueFont, .foregroundColor: textPrimary
            ])
            titleStr.draw(at: CGPoint(x: margin + 22, y: y))
            y += 20

            // Subtitle
            if !event.subtitle.isEmpty {
                let subStr = NSAttributedString(string: event.subtitle, attributes: [
                    .font: bodyFont, .foregroundColor: textTertiary
                ])
                subStr.draw(at: CGPoint(x: margin + 22, y: y))
                y += 16
            }

            y += 8
        }

        drawPageFooter()
    }

    // MARK: - Drawing Helpers

    private func beginPage() {
        ctx.beginPage()
        pageNumber += 1
        y = margin + 10

        // Page background
        pageBg.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: pageH)).fill()

        // Top accent line
        if pageNumber > 1 {
            accent.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: 3)).fill()
            y = margin + 16
        }
    }

    private func ensureSpace(_ needed: CGFloat) {
        if y + needed > pageH - 50 {
            drawPageFooter()
            beginPage()
        }
    }

    private func drawSectionHeader(_ title: String) {
        let str = NSAttributedString(string: title, attributes: [
            .font: sectionTitleFont, .foregroundColor: textPrimary
        ])
        str.draw(at: CGPoint(x: margin, y: y))
        y += 30

        // Accent underline
        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: 40, height: 3), cornerRadius: 1.5).fill()
        y += 20
    }

    private func drawSubsectionHeader(_ title: String) {
        let str = NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold), .foregroundColor: textPrimary
        ])
        str.draw(at: CGPoint(x: margin, y: y))
        y += 24
    }

    private func drawFieldRow(label: String, value: String, y: CGFloat) {
        let lbl = NSAttributedString(string: label, attributes: [
            .font: labelFont, .foregroundColor: textTertiary, .kern: 0.3
        ])
        let val = NSAttributedString(string: value, attributes: [
            .font: valueFont, .foregroundColor: textPrimary
        ])
        lbl.draw(at: CGPoint(x: margin + 4, y: y))
        let valW = val.size().width
        val.draw(at: CGPoint(x: pageW - margin - valW - 4, y: y))
    }

    private func drawDivider(indented: Bool) {
        divider.setFill()
        let x = margin + (indented ? 20 : 0)
        UIBezierPath(rect: CGRect(x: x, y: y, width: contentW - (indented ? 20 : 0), height: 0.5)).fill()
    }

    private func drawCardStart() {
        // Simple marker for y tracking
        y += 16
    }

    private func drawCardEnd(startY: CGFloat) {
        y += 8
    }

    private func drawPageFooter() {
        let footerY = pageH - 30

        // Left: Neura branding
        let powered = NSMutableAttributedString()
        powered.append(NSAttributedString(string: "Powered by ", attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: textTertiary
        ]))
        powered.append(NSAttributedString(string: "Neura", attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: accent
        ]))
        powered.draw(at: CGPoint(x: margin, y: footerY))

        // Orange dot before "Powered"
        accent.setFill()
        UIBezierPath(ovalIn: CGRect(x: margin - 8, y: footerY + 3, width: 4, height: 4)).fill()

        // Right: page number
        let pageStr = NSAttributedString(string: "Page \(pageNumber)", attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: textTertiary
        ])
        let pageW = pageStr.size().width
        pageStr.draw(at: CGPoint(x: self.pageW - margin - pageW, y: footerY))

        // Divider above footer
        divider.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: footerY - 8, width: contentW, height: 0.5)).fill()
    }
}

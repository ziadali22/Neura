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

    private let titleFont = UIFont.systemFont(ofSize: 38, weight: .heavy)
    private let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .medium)
    private let sectionTitleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
    private let labelFont = UIFont.systemFont(ofSize: 14, weight: .bold)
    private let valueFont = UIFont.systemFont(ofSize: 16, weight: .medium)
    private let bodyFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    private let smallFont = UIFont.systemFont(ofSize: 12, weight: .medium)

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
        y += 16
        let infoFields: [(String, String)] = [
            ("Patient Name", gd.fullName),
            ("Date of Birth", gd.dateOfBirth),
            ("Gender", gd.gender),
            ("Blood Type", gd.bloodType),
            ("Insurance", gd.insuranceStatus),
            ("My Number", gd.myPhoneNumber),
            ("Emergency Contact", gd.emergencyContactName),
            ("Emergency Number", gd.emergencyContactNumber),
        ].filter { !$1.isEmpty }

        for (i, field) in infoFields.enumerated() {
            let rh = drawFieldRow(label: field.0, value: field.1, atY: y)
            y += rh
            if i < infoFields.count - 1 {
                drawDivider(indented: false)
            }
        }
        y += 8

        // Stats row — push to bottom but never behind current content
        y = max(y + 30, pageH - 140)
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
            ("My Number", gd.myPhoneNumber),
            ("Emergency Contact", gd.emergencyContactName),
            ("Emergency Number", gd.emergencyContactNumber),
        ].filter { !$1.isEmpty }
            + gd.customFields.map { ($0.label, $0.value) }.filter { !$1.isEmpty }

        if !fields.isEmpty {
            drawSubsectionHeader("General Data")
            for (i, field) in fields.enumerated() {
                let rh = textHeight(field.0, font: labelFont, width: contentW * 0.40)
                    .rounded(.up) + 2
                let rh2 = textHeight(field.1, font: valueFont, width: contentW * 0.56, charWrap: true)
                let needed = max(rh, rh2) + 16
                ensureSpace(needed)
                let rdrawn = drawFieldRow(label: field.0, value: field.1, atY: y)
                y += rdrawn
                if i < fields.count - 1 { drawDivider(indented: true) }
            }
            y += 8
        }

        // Sections
        let entryTextX = margin + 18
        let entryTextW = contentW - 18

        for section in profile.sections {
            guard !section.entries.isEmpty else { continue }

            ensureSpace(60)
            drawSubsectionHeader(section.title)

            for (i, entry) in section.entries.enumerated() {
                let textH  = textHeight(entry.text, font: valueFont, width: entryTextW)
                let details = [entry.field1, entry.field2].filter { !$0.isEmpty }.joined(separator: "  ·  ")
                let detH   = details.isEmpty ? 0 : textHeight(details, font: bodyFont, width: entryTextW) + 4
                let noteH  = entry.notes.isEmpty ? 0 : textHeight("Note: \(entry.notes)", font: bodyFont, width: entryTextW) + 4
                ensureSpace(textH + detH + noteH + 16)

                // Bullet
                accent.setFill()
                UIBezierPath(ovalIn: CGRect(x: margin + 4, y: y + 5, width: 6, height: 6)).fill()

                let th = drawText(entry.text, font: valueFont, color: textPrimary,
                                  x: entryTextX, atY: y, width: entryTextW)
                y += th + 4

                if !details.isEmpty {
                    let dh = drawText(details, font: bodyFont, color: textTertiary,
                                      x: entryTextX, atY: y, width: entryTextW)
                    y += dh + 4
                }

                if !entry.notes.isEmpty {
                    let nh = drawText("Note: \(entry.notes)", font: bodyFont, color: textTertiary,
                                      x: entryTextX, atY: y, width: entryTextW)
                    y += nh + 4
                }

                if i < section.entries.count - 1 {
                    y += 2
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
                let docTextW = contentW - 80  // leave room for type badge on right
                var details = [dateFormatter.string(from: doc.createdAt)]
                if doc.isPDF && doc.pageCount > 1 { details.append("\(doc.pageCount) pages") }
                if let doctor = doc.doctorName, !doctor.isEmpty { details.append("Dr. \(doctor)") }
                let detailLine = details.joined(separator: "  ·  ")
                let noteText = doc.notes ?? ""

                let nameH   = textHeight(doc.name, font: valueFont, width: docTextW)
                let detailH = textHeight(detailLine, font: bodyFont, width: contentW)
                let noteH   = noteText.isEmpty ? 0 : textHeight(noteText, font: bodyFont, width: contentW) + 4
                ensureSpace(nameH + detailH + noteH + 20)

                // Type badge (right-aligned, short — draw at point is fine)
                let typeStr = NSAttributedString(string: doc.documentType.localizedName.uppercased(), attributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: accent
                ])
                typeStr.draw(at: CGPoint(x: pageW - margin - typeStr.size().width, y: y + 2))

                // Doc name (may wrap)
                let nh = drawText(doc.name, font: valueFont, color: textPrimary,
                                  x: margin + 4, atY: y, width: docTextW)
                y += nh + 4

                // Details
                let dh = drawText(detailLine, font: bodyFont, color: textTertiary,
                                  x: margin + 4, atY: y, width: contentW)
                y += dh + 4

                if !noteText.isEmpty {
                    let oh = drawText(noteText, font: bodyFont, color: textTertiary,
                                      x: margin + 4, atY: y, width: contentW)
                    y += oh + 4
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

        let timelineX = margin + 22
        let timelineW = contentW - 22

        for (i, event) in events.enumerated() {
            let titleH = textHeight(event.title, font: valueFont, width: timelineW)
            let subH   = event.subtitle.isEmpty ? 0 : textHeight(event.subtitle, font: bodyFont, width: timelineW) + 4
            let blockH = 16 + titleH + subH + 12  // date + title + subtitle + bottom gap
            ensureSpace(blockH)

            let dotX = margin + 6
            let dotY = y + 5

            accent.setFill()
            UIBezierPath(ovalIn: CGRect(x: dotX - 4, y: dotY - 4, width: 8, height: 8)).fill()

            if i < events.count - 1 {
                UIColor(white: 0.88, alpha: 1).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: dotX, y: dotY + 6))
                line.addLine(to: CGPoint(x: dotX, y: dotY + blockH - 2))
                line.lineWidth = 1.0
                line.stroke()
            }

            // Date (short, single line — draw at point is fine)
            NSAttributedString(string: dateFormatter.string(from: event.date), attributes: [
                .font: smallFont, .foregroundColor: accent
            ]).draw(at: CGPoint(x: timelineX, y: y))
            y += 16

            let th = drawText(event.title, font: valueFont, color: textPrimary,
                              x: timelineX, atY: y, width: timelineW)
            y += th + 4

            if !event.subtitle.isEmpty {
                let sh = drawText(event.subtitle, font: bodyFont, color: textTertiary,
                                  x: timelineX, atY: y, width: timelineW)
                y += sh + 4
            }

            y += 8
        }

        drawPageFooter()
    }

    // MARK: - Text Measurement & Drawing Helpers

    private func textHeight(_ text: String, font: UIFont, width: CGFloat, charWrap: Bool = false) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let p = NSMutableParagraphStyle()
        p.lineBreakMode = charWrap ? .byCharWrapping : .byWordWrapping
        p.lineSpacing = 1
        let str = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: p])
        return ceil(str.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil).height) + 1
    }

    @discardableResult
    private func drawText(_ text: String, font: UIFont, color: UIColor, x: CGFloat, atY: CGFloat,
                          width: CGFloat, charWrap: Bool = false) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let p = NSMutableParagraphStyle()
        p.lineBreakMode = charWrap ? .byCharWrapping : .byWordWrapping
        p.lineSpacing = 1
        let h = textHeight(text, font: font, width: width, charWrap: charWrap)
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p])
            .draw(in: CGRect(x: x, y: atY, width: width, height: h))
        return h
    }

    // MARK: - Page Helpers

    private func beginPage() {
        ctx.beginPage()
        pageNumber += 1
        y = margin + 10

        pageBg.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: pageH)).fill()

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
        let h = drawText(title, font: sectionTitleFont, color: textPrimary,
                         x: margin, atY: y, width: contentW)
        y += h + 6
        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: 40, height: 3), cornerRadius: 1.5).fill()
        y += 20
    }

    private func drawSubsectionHeader(_ title: String) {
        let font = UIFont.systemFont(ofSize: 15, weight: .bold)
        let h = drawText(title, font: font, color: textPrimary, x: margin, atY: y, width: contentW)
        y += h + 8
    }

    // Returns actual row height consumed (for callers that need to track y manually)
    @discardableResult
    private func drawFieldRow(label: String, value: String, atY rowY: CGFloat) -> CGFloat {
        let labelColW = contentW * 0.40
        let valueColW = contentW - labelColW - 12
        let valueColX = margin + labelColW + 12

        let lh = textHeight(label, font: labelFont, width: labelColW)
        let vh = textHeight(value.isEmpty ? "—" : value, font: valueFont, width: valueColW, charWrap: true)
        let rowH = max(lh, vh) + 8

        drawText(label, font: labelFont, color: textTertiary,
                 x: margin + 4, atY: rowY + 4, width: labelColW)
        let display = value.isEmpty ? "—" : value
        drawText(display, font: valueFont, color: value.isEmpty ? textTertiary : textPrimary,
                 x: valueColX, atY: rowY + 4, width: valueColW, charWrap: true)
        return rowH
    }

    private func drawDivider(indented: Bool) {
        divider.setFill()
        let x = margin + (indented ? 20 : 0)
        UIBezierPath(rect: CGRect(x: x, y: y, width: contentW - (indented ? 20 : 0), height: 0.5)).fill()
    }

    private func drawPageFooter() {
        let footerY = pageH - 30

        let powered = NSMutableAttributedString()
        powered.append(NSAttributedString(string: "Powered by ", attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: textTertiary
        ]))
        powered.append(NSAttributedString(string: "Neura", attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: accent
        ]))
        powered.draw(at: CGPoint(x: margin, y: footerY))

        accent.setFill()
        UIBezierPath(ovalIn: CGRect(x: margin - 8, y: footerY + 3, width: 4, height: 4)).fill()

        let pageStr = NSAttributedString(string: "Page \(pageNumber)", attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: textTertiary
        ])
        let pageStrW = pageStr.size().width
        pageStr.draw(at: CGPoint(x: pageW - margin - pageStrW, y: footerY))

        divider.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: footerY - 8, width: contentW, height: 0.5)).fill()
    }
}

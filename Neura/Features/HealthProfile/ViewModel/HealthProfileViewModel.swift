import Foundation
import UIKit
import Combine

@MainActor
final class HealthProfileViewModel: ObservableObject {
    @Published var profile: HealthProfile

    private static let storageKey = "health_profile_data"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(HealthProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = .sample
        }
    }

    // MARK: - General Data

    func updateGeneralField(_ keyPath: WritableKeyPath<HealthProfile.GeneralData, String>, value: String) {
        profile.generalData[keyPath: keyPath] = value
        save()
    }

    // MARK: - Sections

    func addEntry(to sectionID: UUID, text: String, field1: String = "", field2: String = "", notes: String = "") {
        guard let index = profile.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        profile.sections[index].entries.append(.init(text: text, field1: field1, field2: field2, notes: notes))
        save()
    }

    func updateEntry(in sectionID: UUID, entryID: UUID, text: String, field1: String = "", field2: String = "", notes: String = "") {
        guard let sIndex = profile.sections.firstIndex(where: { $0.id == sectionID }),
              let eIndex = profile.sections[sIndex].entries.firstIndex(where: { $0.id == entryID }) else { return }
        profile.sections[sIndex].entries[eIndex].text = text
        profile.sections[sIndex].entries[eIndex].field1 = field1
        profile.sections[sIndex].entries[eIndex].field2 = field2
        profile.sections[sIndex].entries[eIndex].notes = notes
        save()
    }

    func removeEntry(from sectionID: UUID, entryID: UUID) {
        guard let sIndex = profile.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        profile.sections[sIndex].entries.removeAll { $0.id == entryID }
        save()
    }

    func addSection(title: String) {
        profile.sections.append(.init(title: title))
        save()
    }

    func removeSection(id: UUID) {
        profile.sections.removeAll { $0.id == id }
        save()
    }

    // MARK: - PDF Generation

    func generatePDF() -> URL? {
        let pageWidth: CGFloat = 595.0  // A4
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 40.0
        let contentWidth = pageWidth - margin * 2

        let accentColor = UIColor(red: 1.0, green: 0.353, blue: 0.0, alpha: 1.0) // #FF5A00
        let textPrimary = UIColor(red: 0.122, green: 0.122, blue: 0.122, alpha: 1.0) // #1F1F1F
        let textSecondary = UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1.0) // #4A4A4A
        let textTertiary = UIColor(red: 0.478, green: 0.478, blue: 0.478, alpha: 1.0) // #7A7A7A
        let strokeColor = UIColor(red: 0.906, green: 0.878, blue: 0.847, alpha: 1.0) // #E7E0D8
        let cardBg = UIColor.white

        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let sectionTitleFont = UIFont.systemFont(ofSize: 19, weight: .bold)
        let labelFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let valueFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let entryFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let detailFont = UIFont.systemFont(ofSize: 11, weight: .regular)

        var yPosition: CGFloat = 0
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            func beginNewPage() {
                context.beginPage()
                yPosition = margin
            }

            func ensureSpace(_ needed: CGFloat) {
                if yPosition + needed > pageHeight - margin {
                    beginNewPage()
                }
            }

            func drawLine(at y: CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin + 16, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin - 16, y: y))
                strokeColor.setStroke()
                path.lineWidth = 0.75
                path.stroke()
            }

            func drawCard(at y: CGFloat, height: CGFloat) {
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
                cardBg.setFill()
                path.fill()
                UIColor(white: 0, alpha: 0.15).setStroke()
                path.lineWidth = 1.0
                path.stroke()
            }

            // --- Page 1 ---
            beginNewPage()

            // Header
            let titleStr = NSAttributedString(string: "Health Profile", attributes: [
                .font: titleFont, .foregroundColor: textPrimary
            ])
            titleStr.draw(at: CGPoint(x: margin, y: yPosition))
            yPosition += titleStr.size().height + 4

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateStr = NSAttributedString(string: "Generated \(dateFormatter.string(from: Date()))", attributes: [
                .font: subtitleFont, .foregroundColor: textTertiary
            ])
            dateStr.draw(at: CGPoint(x: margin, y: yPosition))
            yPosition += dateStr.size().height + 2

            let updatedStr = NSAttributedString(string: "Last updated \(dateFormatter.string(from: profile.lastUpdated))", attributes: [
                .font: subtitleFont, .foregroundColor: textTertiary
            ])
            updatedStr.draw(at: CGPoint(x: margin, y: yPosition))
            yPosition += updatedStr.size().height + 4

            // Accent bar
            let barRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 3)
            UIBezierPath(roundedRect: barRect, cornerRadius: 1.5).fill(with: .normal, alpha: 1)
            accentColor.setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: 1.5).fill()
            yPosition += 20

            // --- General Data Card ---
            let generalFields: [(String, String)] = [
                ("Full Name", profile.generalData.fullName),
                ("Date of Birth", profile.generalData.dateOfBirth),
                ("Gender", profile.generalData.gender),
                ("Height", profile.generalData.height),
                ("Weight", profile.generalData.weight),
                ("Blood Type", profile.generalData.bloodType),
                ("Insurance Status", profile.generalData.insuranceStatus)
            ].filter { !$1.isEmpty }

            let rowHeight: CGFloat = 34
            let cardPadding: CGFloat = 18
            let sectionHeaderHeight: CGFloat = 36
            let generalCardHeight = cardPadding + sectionHeaderHeight + CGFloat(generalFields.count) * rowHeight + cardPadding

            ensureSpace(generalCardHeight)
            let generalCardY = yPosition
            drawCard(at: generalCardY, height: generalCardHeight)

            yPosition = generalCardY + cardPadding
            let sectionTitle = NSAttributedString(string: "General Data", attributes: [
                .font: sectionTitleFont, .foregroundColor: textPrimary
            ])
            sectionTitle.draw(at: CGPoint(x: margin + 20, y: yPosition))
            yPosition += sectionHeaderHeight

            for (index, field) in generalFields.enumerated() {
                let label = NSAttributedString(string: field.0, attributes: [
                    .font: labelFont, .foregroundColor: textSecondary
                ])
                let value = NSAttributedString(string: field.1, attributes: [
                    .font: valueFont, .foregroundColor: textPrimary
                ])
                label.draw(at: CGPoint(x: margin + 20, y: yPosition + 6))
                let valueSize = value.size()
                value.draw(at: CGPoint(x: pageWidth - margin - 20 - valueSize.width, y: yPosition + 6))

                if index < generalFields.count - 1 {
                    drawLine(at: yPosition + rowHeight - 1)
                }
                yPosition += rowHeight
            }
            yPosition = generalCardY + generalCardHeight + 12

            // --- Health Sections ---
            for section in profile.sections {
                let entries = section.entries
                guard !entries.isEmpty else { continue }

                // Calculate card height
                var sectionCardHeight = cardPadding + sectionHeaderHeight
                for entry in entries {
                    sectionCardHeight += 24
                    if !entry.field1.isEmpty || !entry.field2.isEmpty {
                        sectionCardHeight += 18
                    }
                    if !entry.notes.isEmpty {
                        sectionCardHeight += 18
                    }
                    sectionCardHeight += 8
                }
                sectionCardHeight += cardPadding - 6

                ensureSpace(sectionCardHeight)
                let cardY = yPosition
                drawCard(at: cardY, height: sectionCardHeight)

                yPosition = cardY + cardPadding
                let secTitle = NSAttributedString(string: section.title, attributes: [
                    .font: sectionTitleFont, .foregroundColor: textPrimary
                ])
                secTitle.draw(at: CGPoint(x: margin + 20, y: yPosition))
                yPosition += sectionHeaderHeight

                for (index, entry) in entries.enumerated() {
                    // Bullet + entry name
                    let bullet = NSAttributedString(string: "•", attributes: [
                        .font: valueFont, .foregroundColor: accentColor
                    ])
                    bullet.draw(at: CGPoint(x: margin + 20, y: yPosition))

                    let entryText = NSAttributedString(string: entry.text, attributes: [
                        .font: valueFont, .foregroundColor: textPrimary
                    ])
                    entryText.draw(at: CGPoint(x: margin + 34, y: yPosition))
                    yPosition += 24

                    // Field details
                    if !entry.field1.isEmpty || !entry.field2.isEmpty {
                        var details: [String] = []
                        if !entry.field1.isEmpty { details.append(entry.field1) }
                        if !entry.field2.isEmpty { details.append(entry.field2) }
                        let detailStr = NSAttributedString(string: details.joined(separator: "  ·  "), attributes: [
                            .font: detailFont, .foregroundColor: textTertiary
                        ])
                        detailStr.draw(at: CGPoint(x: margin + 34, y: yPosition))
                        yPosition += 18
                    }

                    if !entry.notes.isEmpty {
                        let noteStr = NSAttributedString(string: "Note: \(entry.notes)", attributes: [
                            .font: detailFont, .foregroundColor: textTertiary
                        ])
                        noteStr.draw(at: CGPoint(x: margin + 34, y: yPosition))
                        yPosition += 18
                    }

                    if index < entries.count - 1 {
                        drawLine(at: yPosition + 3)
                    }
                    yPosition += 8
                }

                yPosition = cardY + sectionCardHeight + 12
            }

            // Footer
            ensureSpace(40)
            yPosition += 8
            let footerStr = NSAttributedString(string: "Generated by Neura", attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: accentColor
            ])
            let footerSize = footerStr.size()
            footerStr.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: yPosition))
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Health_Profile.pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    private func save() {
        profile.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        SyncQueueManager.shared.enqueueProfileUpload(profile)
        updateNotifications()
    }

    private func updateNotifications() {
        let g = profile.generalData
        let fields = [g.fullName, g.dateOfBirth, g.gender, g.height, g.weight,
                      g.bloodType, g.insuranceStatus, g.emergencyContact]
        let filled = fields.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        ProfileNotificationManager.shared.requestPermissionAndScheduleIfNeeded(
            filledCount: filled,
            total: fields.count
        )
    }
}

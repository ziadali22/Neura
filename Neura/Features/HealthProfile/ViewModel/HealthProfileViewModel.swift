import Foundation
import UIKit
import Combine

@MainActor
final class HealthProfileViewModel: ObservableObject {
    @Published var profile: HealthProfile

    private static let storageKey = "health_profile_data"
    private var restoreObserver: NSObjectProtocol?

    init() {
        self.profile = Self.loadFromDisk() ?? .sample
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .healthProfileRestored, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reload() }
        }
    }

    func reload() {
        if let fresh = Self.loadFromDisk() {
            profile = fresh
        }
    }

    private static func loadFromDisk() -> HealthProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(HealthProfile.self, from: data) else { return nil }
        return saved
    }

    // MARK: - General Data

    func updateGeneralField(_ keyPath: WritableKeyPath<HealthProfile.GeneralData, String>, value: String) {
        profile.generalData[keyPath: keyPath] = value
        save()
    }

    // MARK: - Custom General Fields

    func addGeneralCustomField(label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        profile.generalData.customFields.append(.init(label: trimmed))
        save()
    }

    func updateGeneralCustomField(id: UUID, value: String) {
        guard let index = profile.generalData.customFields.firstIndex(where: { $0.id == id }) else { return }
        profile.generalData.customFields[index].value = value
        save()
    }

    func removeGeneralCustomField(id: UUID) {
        profile.generalData.customFields.removeAll { $0.id == id }
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

    func renameSection(id: UUID, title: String) {
        guard let index = profile.sections.firstIndex(where: { $0.id == id }) else { return }
        profile.sections[index].title = title
        save()
    }

    // MARK: - PDF Generation

    func generatePDF() -> URL? {
        Self.generatePDF(for: profile)
    }

    nonisolated static func generatePDF(for profile: HealthProfile) -> URL? {
        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let margin: CGFloat = 40
        let hPad: CGFloat = 20        // card inner horizontal padding
        let contentW = pageW - margin * 2

        let accent   = UIColor(red: 1.0,   green: 0.353, blue: 0.0,   alpha: 1)
        let primary  = UIColor(red: 0.122, green: 0.122, blue: 0.122, alpha: 1)
        let secondary = UIColor(red: 0.29,  green: 0.29,  blue: 0.29,  alpha: 1)
        let tertiary = UIColor(red: 0.478, green: 0.478, blue: 0.478, alpha: 1)
        let stroke   = UIColor(red: 0.906, green: 0.878, blue: 0.847, alpha: 1)
        let pageBg   = UIColor(red: 0.988, green: 0.980, blue: 0.973, alpha: 1)

        let titleF    = UIFont.systemFont(ofSize: 34, weight: .bold)
        let subtitleF = UIFont.systemFont(ofSize: 15, weight: .regular)
        let sectionF  = UIFont.systemFont(ofSize: 21, weight: .bold)
        let labelF    = UIFont.systemFont(ofSize: 16, weight: .regular)
        let valueF    = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let detailF   = UIFont.systemFont(ofSize: 14, weight: .regular)

        var y: CGFloat = 0
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        let data = renderer.pdfData { ctx in

            // MARK: Helpers

            func wrapStyle(charWrap: Bool = false) -> NSParagraphStyle {
                let p = NSMutableParagraphStyle()
                p.lineBreakMode = charWrap ? .byCharWrapping : .byWordWrapping
                p.lineSpacing = 1
                return p
            }

            func measure(_ text: String, font: UIFont, width: CGFloat, charWrap: Bool = false) -> CGFloat {
                guard !text.isEmpty else { return 0 }
                let str = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: wrapStyle(charWrap: charWrap)])
                return ceil(str.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil).height) + 1
            }

            @discardableResult
            func drawText(_ text: String, font: UIFont, color: UIColor, x: CGFloat, atY: CGFloat, width: CGFloat, charWrap: Bool = false) -> CGFloat {
                guard !text.isEmpty else { return 0 }
                let h = measure(text, font: font, width: width, charWrap: charWrap)
                NSAttributedString(string: text, attributes: [
                    .font: font, .foregroundColor: color, .paragraphStyle: wrapStyle(charWrap: charWrap)
                ]).draw(in: CGRect(x: x, y: atY, width: width, height: h))
                return h
            }

            func newPage() {
                ctx.beginPage()
                pageBg.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: pageH)).fill()
                accent.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: 3)).fill()
                y = margin + 10
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageH - margin { newPage() }
            }

            func divider(at dy: CGFloat) {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: margin + 16, y: dy))
                p.addLine(to: CGPoint(x: pageW - margin - 16, y: dy))
                stroke.setStroke(); p.lineWidth = 0.75; p.stroke()
            }

            func drawCard(at dy: CGFloat, height: CGFloat) {
                let r = UIBezierPath(roundedRect: CGRect(x: margin, y: dy, width: contentW, height: height), cornerRadius: 14)
                UIColor.white.setFill(); r.fill()
                stroke.setStroke(); r.lineWidth = 1; r.stroke()
            }

            // MARK: Field row layout constants
            let labelColW = contentW * 0.40
            let valueColX = margin + hPad + labelColW + 8
            let valueColW = contentW - hPad - labelColW - 8 - hPad
            let rowVPad: CGFloat = 10

            func rowHeight(label: String, value: String) -> CGFloat {
                let lh = measure(label, font: labelF, width: labelColW)
                let vh = measure(value.isEmpty ? "—" : value, font: valueF, width: valueColW, charWrap: true)
                return max(lh, vh) + rowVPad * 2
            }

            func drawRow(label: String, value: String, atY dy: CGFloat) -> CGFloat {
                let h = rowHeight(label: label, value: value)
                drawText(label, font: labelF, color: secondary, x: margin + hPad, atY: dy + rowVPad, width: labelColW)
                let display = value.isEmpty ? "—" : value
                drawText(display, font: valueF, color: value.isEmpty ? tertiary : primary,
                         x: valueColX, atY: dy + rowVPad, width: valueColW, charWrap: true)
                return h
            }

            // MARK: Entry layout constants
            let bulletX  = margin + hPad
            let entryX   = bulletX + 14
            let entryW   = pageW - margin - entryX - hPad

            func entryHeight(entry: HealthProfile.HealthSection.Entry) -> CGFloat {
                var h = measure(entry.text, font: valueF, width: entryW) + 4
                let details = [entry.field1, entry.field2].filter { !$0.isEmpty }.joined(separator: "  ·  ")
                if !details.isEmpty { h += measure(details, font: detailF, width: entryW) + 4 }
                if !entry.notes.isEmpty { h += measure("Note: \(entry.notes)", font: detailF, width: entryW) + 4 }
                return h + 8
            }

            // MARK: Page 1
            newPage()

            let hdrH = measure("Health Profile", font: titleF, width: contentW)
            drawText("Health Profile", font: titleF, color: primary, x: margin, atY: y, width: contentW)
            y += hdrH + 4

            let df = DateFormatter(); df.dateStyle = .medium
            drawText("Generated \(df.string(from: Date()))", font: subtitleF, color: tertiary,
                     x: margin, atY: y, width: contentW)
            y += 18
            drawText("Last updated \(df.string(from: profile.lastUpdated))", font: subtitleF, color: tertiary,
                     x: margin, atY: y, width: contentW)
            y += 22

            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentW, height: 3), cornerRadius: 1.5).fill()
            y += 20

            // MARK: General Data card
            let generalFields: [(String, String)] = [
                ("Full Name",         profile.generalData.fullName),
                ("Date of Birth",     profile.generalData.dateOfBirth),
                ("Gender",            profile.generalData.gender),
                ("Height",            profile.generalData.height),
                ("Weight",            profile.generalData.weight),
                ("Blood Type",        profile.generalData.bloodType),
                ("Insurance Status",  profile.generalData.insuranceStatus),
                ("My Number",         profile.generalData.myPhoneNumber),
                ("Emergency Contact", profile.generalData.emergencyContactName),
                ("Emergency Number",  profile.generalData.emergencyContactNumber)
            ].filter { !$1.isEmpty }
            + profile.generalData.customFields
                .map { ($0.label, $0.value) }
                .filter { !$1.isEmpty }

            let cardVPad: CGFloat = 16
            let secH: CGFloat = 34

            var genCardH = cardVPad + secH
            for f in generalFields { genCardH += rowHeight(label: f.0, value: f.1) }
            genCardH += cardVPad

            ensureSpace(genCardH)
            let genCardY = y
            drawCard(at: genCardY, height: genCardH)
            y = genCardY + cardVPad

            drawText("General Data", font: sectionF, color: primary,
                     x: margin + hPad, atY: y, width: contentW - hPad * 2)
            y += secH

            for (i, f) in generalFields.enumerated() {
                let rh = drawRow(label: f.0, value: f.1, atY: y)
                y += rh
                if i < generalFields.count - 1 { divider(at: y) }
            }
            y = genCardY + genCardH + 16

            // MARK: Section cards
            for section in profile.sections {
                guard !section.entries.isEmpty else { continue }

                var secCardH = cardVPad + secH
                for e in section.entries { secCardH += entryHeight(entry: e) }
                secCardH += cardVPad

                let fitsOnOnePage = secCardH <= pageH - margin * 2 - 30

                if fitsOnOnePage {
                    ensureSpace(secCardH)
                    let cardY = y
                    drawCard(at: cardY, height: secCardH)
                    y = cardY + cardVPad

                    drawText(section.title, font: sectionF, color: primary,
                             x: margin + hPad, atY: y, width: contentW - hPad * 2)
                    y += secH

                    for (i, entry) in section.entries.enumerated() {
                        NSAttributedString(string: "•", attributes: [.font: valueF, .foregroundColor: accent])
                            .draw(at: CGPoint(x: bulletX, y: y))

                        let details = [entry.field1, entry.field2].filter { !$0.isEmpty }.joined(separator: "  ·  ")
                        let th = drawText(entry.text, font: valueF, color: primary, x: entryX, atY: y, width: entryW)
                        y += th + 4
                        if !details.isEmpty {
                            let dh = drawText(details, font: detailF, color: tertiary, x: entryX, atY: y, width: entryW)
                            y += dh + 4
                        }
                        if !entry.notes.isEmpty {
                            let nh = drawText("Note: \(entry.notes)", font: detailF, color: tertiary, x: entryX, atY: y, width: entryW)
                            y += nh + 4
                        }
                        if i < section.entries.count - 1 { divider(at: y + 3) }
                        y += 8
                    }
                    y = cardY + secCardH + 16
                } else {
                    // Section too tall for one page — flow without card background
                    ensureSpace(secH + 30)
                    drawText(section.title, font: sectionF, color: primary,
                             x: margin, atY: y, width: contentW)
                    y += secH
                    accent.setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: 30, height: 2), cornerRadius: 1).fill()
                    y += 12

                    for (i, entry) in section.entries.enumerated() {
                        let eh = entryHeight(entry: entry)
                        ensureSpace(eh)
                        NSAttributedString(string: "•", attributes: [.font: valueF, .foregroundColor: accent])
                            .draw(at: CGPoint(x: margin, y: y))
                        let details = [entry.field1, entry.field2].filter { !$0.isEmpty }.joined(separator: "  ·  ")
                        let th = drawText(entry.text, font: valueF, color: primary, x: margin + 14, atY: y, width: contentW - 14)
                        y += th + 4
                        if !details.isEmpty {
                            let dh = drawText(details, font: detailF, color: tertiary, x: margin + 14, atY: y, width: contentW - 14)
                            y += dh + 4
                        }
                        if !entry.notes.isEmpty {
                            let nh = drawText("Note: \(entry.notes)", font: detailF, color: tertiary, x: margin + 14, atY: y, width: contentW - 14)
                            y += nh + 4
                        }
                        if i < section.entries.count - 1 { divider(at: y + 3) }
                        y += 8
                    }
                    y += 16
                }
            }

            // Footer
            ensureSpace(30)
            y += 8
            let footStr = NSAttributedString(string: "Generated by Neura", attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: accent
            ])
            footStr.draw(at: CGPoint(x: (pageW - footStr.size().width) / 2, y: y))
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
                      g.bloodType, g.insuranceStatus, g.myPhoneNumber, g.emergencyContactName, g.emergencyContactNumber]
        let filled = fields.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        ProfileNotificationManager.shared.requestPermissionAndScheduleIfNeeded(
            filledCount: filled,
            total: fields.count
        )
    }
}

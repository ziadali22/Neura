import SwiftUI
import UIKit

struct EmergencyCardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()

    @State private var cardAppear = false
    @State private var actionsAppear = false

    private let cardRed = Color(hex: "E8392E")
    private let deepRed = Color(hex: "C41E14")
    private let labelRed = Color(hex: "CC1A10")

    var body: some View {
        VStack(spacing: 24) {
            navBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    emergencyCard
                        .scaleEffect(cardAppear ? 1 : 0.92)
                        .opacity(cardAppear ? 1 : 0)

                    emergencyContactsSection
                        .opacity(actionsAppear ? 1 : 0)
                        .offset(y: actionsAppear ? 0 : 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                cardAppear = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                actionsAppear = true
            }
        }
    }
}

// MARK: - Subviews

private extension EmergencyCardView {

    // MARK: Nav

    var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Button { shareEmergencyCard() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.Emergency.share)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.surfaceWhite)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: Card

    var emergencyCard: some View {
        VStack(spacing: 0) {
            // Red header
            ZStack {
                LinearGradient(
                    colors: [cardRed, deepRed],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 200, height: 200)
                    .offset(x: 100, y: -60)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.Emergency.inCaseOf)
                            .font(.system(size: 14, weight: .bold))
                            .tracking(3)
                            .foregroundColor(.white.opacity(0.7))

                        Text(L10n.Emergency.emergency)
                            .font(.system(size: 28, weight: .heavy))
                            .tracking(1)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.white.opacity(0.2))
                        .rotationEffect(.degrees(15))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
            }
            .frame(height: 100)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
            )

            // White body — vitals + fields + footer
            VStack(spacing: 0) {
                // Vitals strip inside card
                vitalsStripInline
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Rectangle()
                    .fill(Color(hex: "F0ECE8"))
                    .frame(height: 1)
                    .padding(.horizontal, 18)

                // Field rows
                ForEach(Array(cardFields.enumerated()), id: \.offset) { index, field in
                    cardRow(field: field)

                    if index < cardFields.count - 1 {
                        Rectangle()
                            .fill(Color(hex: "F0ECE8"))
                            .frame(height: 1)
                            .padding(.leading, 56)
                    }
                }

                // Neura branding footer inside card
                Rectangle()
                    .fill(Color(hex: "F0ECE8"))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                    .padding(.top, 4)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 6, height: 6)
                    Text(L10n.Emergency.poweredBy)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.textTertiary)
                    Text(L10n.Common.neura)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accent)
                }
                .padding(.vertical, 12)
            }
            .background(Color.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 24,
                    topTrailingRadius: 0
                )
            )
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    // MARK: Vitals Strip (inline)

    var vitalsStripInline: some View {
        let gd = viewModel.profile.generalData
        let items: [(icon: String, value: String, label: String, color: Color)] = [
            ("drop.fill", gd.bloodType, "Blood", Color(hex: "E8392E")),
            ("ruler", gd.height, "Height", Color(hex: "5E5CE6")),
            ("scalemass", gd.weight, "Weight", Color(hex: "10B981")),
            ("figure.stand", gd.gender, "Gender", Color(hex: "F59E0B")),
        ].filter { !$0.value.isEmpty }

        return Group {
            if !items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(items, id: \.label) { item in
                        VStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(item.color)

                            Text(item.value)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(item.label)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.textTertiary)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F8F5F2"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    // MARK: Card Fields

    struct CardField {
        let icon: String
        let label: String
        let value: String
        let iconColor: Color
    }

    var cardFields: [CardField] {
        let gd = viewModel.profile.generalData
        return [
            .init(icon: "person.fill", label: "Full Name", value: gd.fullName, iconColor: Color(hex: "E8392E")),
            .init(icon: "calendar", label: "Date of Birth", value: gd.dateOfBirth, iconColor: Color(hex: "E8392E")),
            .init(icon: "exclamationmark.triangle.fill", label: "Allergies", value: entriesText(for: "allerg"), iconColor: Color(hex: "F59E0B")),
            .init(icon: "pill.fill", label: "Medications", value: entriesText(for: "medication", or: "supplement"), iconColor: Color(hex: "8B5CF6")),
            .init(icon: "heart.text.clipboard", label: "Conditions", value: entriesText(for: "condition"), iconColor: Color(hex: "E8392E")),
            .init(icon: "shield.checkered", label: "Insurance", value: gd.insuranceStatus, iconColor: Color(hex: "10B981")),
            .init(icon: "phone.fill", label: "Emergency Contact", value: [gd.emergencyContactName, gd.emergencyContactNumber].filter { !$0.isEmpty }.joined(separator: " · "), iconColor: Color(hex: "10B981")),
        ]
    }

    func cardRow(field: CardField) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(field.iconColor.opacity(0.1))
                    .frame(width: 34, height: 34)

                Image(systemName: field.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(field.iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(labelRed)
                    .tracking(0.3)
                    .textCase(.uppercase)

                if field.value.isEmpty {
                    Text(L10n.Onboarding.EmergencyCard.notSet)
                        .font(.system(size: 15))
                        .foregroundColor(.textTertiary)
                        .italic()
                } else {
                    Text(field.value)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: Quick Actions

    var emergencyContactsSection: some View {
        let contact = viewModel.profile.generalData.emergencyContactNumber
        return Group {
            if !contact.isEmpty {
                Button {
                    callEmergencyContact(contact)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "10B981"))
                                .frame(width: 48, height: 48)
                            Image(systemName: "phone.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.Emergency.callContact)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Text(contact)
                                .font(.system(size: 13))
                                .foregroundColor(.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "phone.arrow.up.right.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "10B981"))
                    }
                    .padding(16)
                    .background(Color.surfaceWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    // MARK: - Helpers

    func entriesText(for keyword: String, or keyword2: String? = nil) -> String {
        let section = viewModel.profile.sections.first { section in
            let t = section.title.lowercased()
            if t.contains(keyword) { return true }
            if let k2 = keyword2, t.contains(k2) { return true }
            return false
        }
        guard let entries = section?.entries, !entries.isEmpty else { return "" }
        return entries.map(\.text).joined(separator: ", ")
    }

    func callEmergencyContact(_ contact: String) {
        let digits = contact.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Share

    func shareEmergencyCard() {
        guard let pdf = generateEmergencyPDF() else { return }
        let activityVC = UIActivityViewController(activityItems: [pdf], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topVC = root
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - PDF

    func generateEmergencyPDF() -> URL? {
        let profile = viewModel.profile
        let pageW: CGFloat = 595.0
        let pageH: CGFloat = 842.0
        let margin: CGFloat = 40.0
        let cardW = pageW - margin * 2

        let accentUI = UIColor(red: 1.0, green: 0.353, blue: 0.0, alpha: 1) // #FF5A00
        let redUI = UIColor(red: 0.91, green: 0.224, blue: 0.18, alpha: 1)
        let labelRedUI = UIColor(red: 0.8, green: 0.102, blue: 0.063, alpha: 1)
        let textUI = UIColor(red: 0.122, green: 0.122, blue: 0.122, alpha: 1)
        let dimUI = UIColor(red: 0.48, green: 0.48, blue: 0.48, alpha: 1)
        let dividerUI = UIColor(red: 0.94, green: 0.925, blue: 0.91, alpha: 1)
        let bgUI = UIColor(red: 0.973, green: 0.961, blue: 0.949, alpha: 1)

        let subFont = UIFont.systemFont(ofSize: 13, weight: .bold)
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .heavy)
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let valueFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        let vitalLabelFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let vitalValueFont = UIFont.systemFont(ofSize: 13, weight: .bold)

        let fields = buildPDFFields(from: profile)
        let gd = profile.generalData
        let vitals: [(String, String)] = [
            (L10n.HealthProfile.bloodType, gd.bloodType),
            (L10n.HealthProfile.height, gd.height),
            (L10n.HealthProfile.weight, gd.weight),
            (L10n.HealthProfile.gender, gd.gender),
        ].filter { !$0.1.isEmpty }

        let rowH: CGFloat = 38.0
        let headerH: CGFloat = 100.0
        let vitalsH: CGFloat = vitals.isEmpty ? 0 : 56.0
        let bodyH = vitalsH + CGFloat(fields.count) * rowH + 50 // 50 for padding + footer
        let cardX = margin
        let cardY: CGFloat = 50.0

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            // Page background
            bgUI.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: pageH)).fill()

            // Red header
            let headerRect = CGRect(x: cardX, y: cardY, width: cardW, height: headerH)
            redUI.setFill()
            UIBezierPath(roundedRect: headerRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 18, height: 18)).fill()

            // Header text
            let sub = NSAttributedString(string: L10n.Emergency.inCaseOf, attributes: [.font: subFont, .foregroundColor: UIColor.white.withAlphaComponent(0.7), .kern: 3.0])
            sub.draw(at: CGPoint(x: cardX + 22, y: cardY + 22))

            let main = NSAttributedString(string: L10n.Emergency.emergency, attributes: [.font: titleFont, .foregroundColor: UIColor.white, .kern: 1.0])
            main.draw(at: CGPoint(x: cardX + 22, y: cardY + 44))

            // Cross decoration
            UIColor.white.withAlphaComponent(0.15).setFill()
            let cx = cardX + cardW - 56
            let cy = cardY + 28
            UIBezierPath(roundedRect: CGRect(x: cx + 16, y: cy, width: 8, height: 40), cornerRadius: 4).fill()
            UIBezierPath(roundedRect: CGRect(x: cx, y: cy + 16, width: 40, height: 8), cornerRadius: 4).fill()

            // White body
            let bodyY = cardY + headerH
            let bodyRect = CGRect(x: cardX, y: bodyY, width: cardW, height: bodyH)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: bodyRect, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 18, height: 18)).fill()

            // Card border
            UIColor.black.withAlphaComponent(0.05).setStroke()
            let fullRect = CGRect(x: cardX, y: cardY, width: cardW, height: headerH + bodyH)
            UIBezierPath(roundedRect: fullRect, cornerRadius: 18).stroke()

            var y = bodyY + 14

            // Vitals strip
            if !vitals.isEmpty {
                let vitalW = (cardW - 22 * 2 - CGFloat(vitals.count - 1) * 8) / CGFloat(vitals.count)
                var vx = cardX + 22.0
                for vital in vitals {
                    // Vital bg
                    bgUI.setFill()
                    UIBezierPath(roundedRect: CGRect(x: vx, y: y, width: vitalW, height: 42), cornerRadius: 10).fill()

                    // Value
                    let vv = NSAttributedString(string: vital.1, attributes: [.font: vitalValueFont, .foregroundColor: textUI])
                    let vvW = vv.size().width
                    vv.draw(at: CGPoint(x: vx + (vitalW - vvW) / 2, y: y + 8))

                    // Label
                    let vl = NSAttributedString(string: vital.0.uppercased(), attributes: [.font: vitalLabelFont, .foregroundColor: dimUI, .kern: 0.8])
                    let vlW = vl.size().width
                    vl.draw(at: CGPoint(x: vx + (vitalW - vlW) / 2, y: y + 26))

                    vx += vitalW + 8
                }
                y += 52

                // Divider after vitals
                dividerUI.setFill()
                UIBezierPath(rect: CGRect(x: cardX + 22, y: y, width: cardW - 44, height: 0.5)).fill()
                y += 8
            }

            // Field rows
            for (index, field) in fields.enumerated() {
                let lbl = NSAttributedString(string: field.label.uppercased(), attributes: [
                    .font: labelFont, .foregroundColor: labelRedUI, .kern: 0.5
                ])
                let val = NSAttributedString(string: field.value.isEmpty ? L10n.Onboarding.EmergencyCard.notSet : field.value, attributes: [
                    .font: valueFont, .foregroundColor: field.value.isEmpty ? dimUI : textUI
                ])

                lbl.draw(at: CGPoint(x: cardX + 22, y: y + 2))
                val.draw(at: CGPoint(x: cardX + 22, y: y + 16))

                if index < fields.count - 1 {
                    dividerUI.setFill()
                    UIBezierPath(rect: CGRect(x: cardX + 22, y: y + rowH - 2, width: cardW - 44, height: 0.5)).fill()
                }
                y += rowH
            }

            // Branding footer inside card
            y += 6
            dividerUI.setFill()
            UIBezierPath(rect: CGRect(x: cardX + 22, y: y, width: cardW - 44, height: 0.5)).fill()
            y += 10

            let powered = NSAttributedString(string: L10n.Emergency.poweredBy + " ", attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: dimUI
            ])
            let neura = NSAttributedString(string: L10n.Common.neura, attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: accentUI
            ])

            let combined = NSMutableAttributedString()
            combined.append(powered)
            combined.append(neura)
            let combinedW = combined.size().width
            combined.draw(at: CGPoint(x: (pageW - combinedW) / 2, y: y))

            // Accent dot
            accentUI.setFill()
            UIBezierPath(ovalIn: CGRect(x: (pageW - combinedW) / 2 - 10, y: y + 4, width: 5, height: 5)).fill()
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Emergency_Medical_Card.pdf")
        try? data.write(to: url)
        return url
    }

    struct PDFField {
        let label: String
        let value: String
    }

    func buildPDFFields(from profile: HealthProfile) -> [PDFField] {
        [
            .init(label: L10n.HealthProfile.fullName, value: profile.generalData.fullName),
            .init(label: L10n.HealthProfile.dateOfBirth, value: profile.generalData.dateOfBirth),
            .init(label: L10n.Onboarding.Medical.allergies, value: entriesText(for: "allerg")),
            .init(label: L10n.Onboarding.Medical.medications, value: entriesText(for: "medication", or: "supplement")),
            .init(label: L10n.Onboarding.Medical.conditions, value: entriesText(for: "condition")),
            .init(label: L10n.HealthProfile.insuranceStatus, value: profile.generalData.insuranceStatus),
            .init(label: L10n.HealthProfile.emergencyContact, value: [profile.generalData.emergencyContactName, profile.generalData.emergencyContactNumber].filter { !$0.isEmpty }.joined(separator: " · ")),
        ]
    }
}

#Preview {
    NavigationStack {
        EmergencyCardView()
    }
}

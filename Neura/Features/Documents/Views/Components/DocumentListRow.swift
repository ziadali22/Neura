import SwiftUI

struct DocumentListRow: View {
    let document: Document
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            documentIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelecting {
                selectionIndicator
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(14)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        var parts: [String] = []
        parts.append(document.createdAt.formatted(date: .numeric, time: .omitted))
        if let spec = document.specialization, spec != .other {
            parts.append(spec.rawValue)
        }
        if let doctor = document.doctorName, !doctor.isEmpty {
            parts.append("Dr. \(doctor)")
        }
        return parts.joined(separator: " • ")
    }

    // MARK: - Icon

    private var documentIcon: some View {
        let iconColor = document.category?.color ?? Color.accent
        return ZStack {
            if let gridIcon = document.category?.gridIcon {
                Image(gridIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: document.isPDF ? "doc.fill" : "photo.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Selection Indicator

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.accent : Color.textTertiary.opacity(0.35),
                    lineWidth: 2
                )
                .frame(width: 26, height: 26)

            if isSelected {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = document.category {
                        Text(category.localizedName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accent.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 4))
                    }

                    Text(document.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)

                    if document.isPDF && document.pageCount > 1 {
                        Text("·")
                            .foregroundStyle(Color.textTertiary)
                        Text("\(document.pageCount) pages")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                if let doctor = document.doctorName, !doctor.isEmpty {
                    Label(doctor, systemImage: "stethoscope")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            if isSelecting {
                selectionIndicator
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(14)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Subviews

    private var documentIcon: some View {
        let iconColor = document.category?.color ?? Color.accent
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor.opacity(0.12))
                .frame(width: 44, height: 44)

            if let assetIcon = document.category?.assetIcon {
                Image(assetIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: document.category?.icon ?? (document.isPDF ? "doc.fill" : "photo.fill"))
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
            }
        }
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.accent : Color.textTertiary.opacity(0.35),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 24, height: 24)
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

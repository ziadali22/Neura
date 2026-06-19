import SwiftUI

struct DocsSelectionBar: View {
    let onDelete: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack {
            Button(action: onDelete) {
                Label(L10n.Common.delete, systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.surfaceWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.stroke, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }

            Spacer()

            Button(action: onShare) {
                Label(L10n.Common.share, systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accent)
                    .clipShape(Capsule())
                    .shadow(color: Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

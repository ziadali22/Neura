import SwiftUI

struct DocsSelectionBar: View {
    let onDelete: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.surfaceWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.stroke, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }

            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

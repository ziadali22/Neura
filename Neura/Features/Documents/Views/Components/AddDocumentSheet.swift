import SwiftUI

struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: () -> Void
    let onPhoto: () -> Void
    let onFile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.stroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            Text("Add Document")
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, 16)

            // Featured scan card
            Button {
                dismiss()
                onScan()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scan Document")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Use your camera to scan pages")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .background(Color.accent)
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Secondary options
            HStack(spacing: 10) {
                secondaryOption(icon: "photo.on.rectangle", title: "Photos", color: .blue) {
                    dismiss(); onPhoto()
                }
                secondaryOption(icon: "folder", title: "Import File", color: .green) {
                    dismiss(); onFile()
                }
            }
            .padding(.horizontal, 20)

            // Cancel
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .background(Color.surfaceWhite)
    }

    private func secondaryOption(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.backgroundPrimary)
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    AddDocumentSheet(onScan: {}, onPhoto: {}, onFile: {})
        .presentationDetents([.height(360)])
}

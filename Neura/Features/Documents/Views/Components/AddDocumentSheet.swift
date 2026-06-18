import SwiftUI

struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: () -> Void
    let onPhoto: () -> Void
    let onFile: () -> Void

    private struct Option {
        let icon: String
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.stroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            optionRow(icon: "scanAdd",   title: "Scan Document",      subtitle: "Use camera to scan pages")           { dismiss(); onScan() }
            Divider().padding(.leading, 76)
            optionRow(icon: "imageAdd",  title: "Upload from Photos", subtitle: "Choose an image from your library") { dismiss(); onPhoto() }
            Divider().padding(.leading, 76)
            optionRow(icon: "fileAdd",   title: "Import File",        subtitle: "Select a PDF or image file")         { dismiss(); onFile() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }

    private func optionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color(hex: "E7E0D8").opacity(0.4))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(icon)
                            .font(.system(size: 25))
                            .foregroundStyle(Color.accent)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    AddDocumentSheet(onScan: {}, onPhoto: {}, onFile: {})
        .presentationDetents([.height(280)])
}

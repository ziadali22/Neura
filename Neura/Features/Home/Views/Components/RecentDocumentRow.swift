import SwiftUI

struct RecentDocumentRow: View {
    let document: Document
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RecentDocumentIcon(document: document)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.category?.localizedName ?? document.name)
                        .font(.headingXS)
                        .foregroundStyle(Color.textPrimary)

                    Text(document.createdAt, format: .dateTime.day().month(.abbreviated).year())
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                "\(document.category?.localizedName ?? document.name), \(document.createdAt, format: .dateTime.day().month(.abbreviated).year())"
            )
        )
    }
}

// MARK: - Icon

private struct RecentDocumentIcon: View {
    let document: Document

    var body: some View {
        if let category = document.category, let assetIcon = category.assetIcon {
            Image(assetIcon)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Circle()
                    .fill((document.category?.color ?? Color.accent).opacity(0.15))

                Image(systemName: document.category?.icon ?? "doc.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(document.category?.color ?? Color.accent)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        RecentDocumentRow(
            document: Document(
                name: "Prescription",
                fileURL: URL(fileURLWithPath: "/tmp/doc.pdf"),
                documentType: .pdf,
                category: .prescriptions
            ),
            onTap: {}
        )
        Divider().padding(.leading, 72)
        RecentDocumentRow(
            document: Document(
                name: "Medical Check",
                fileURL: URL(fileURLWithPath: "/tmp/doc2.pdf"),
                documentType: .pdf,
                category: .consultations
            ),
            onTap: {}
        )
    }
    .background(Color.surfaceWhite)
    .clipShape(.rect(cornerRadius: 20))
    .padding()
    .background(Color.backgroundPrimary)
}

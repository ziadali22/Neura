import SwiftUI

struct RecentDocumentRow: View {
    let document: Document
    let onTap: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: document.createdAt)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Category icon
                categoryIcon
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.category?.localizedName ?? document.name)
                        .font(.headingXS)
                        .foregroundColor(.textPrimary)

                    Text(formattedDate)
                        .font(.captionS)
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Icon

    @ViewBuilder
    private var categoryIcon: some View {
        if let category = document.category, let assetIcon = category.assetIcon {
            Image(assetIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
        } else {
            ZStack {
                Circle()
                    .fill((document.category?.color ?? Color.accent).opacity(0.15))

                Image(systemName: document.category?.icon ?? "doc.fill")
                    .font(.system(size: 18))
                    .foregroundColor(document.category?.color ?? .accent)
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
    .cornerRadius(20)
    .padding()
    .background(Color.backgroundPrimary)
}

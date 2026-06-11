import SwiftUI

struct DocumentsList: View {
    let documents: [Document]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(documents) { document in
                    LegacyDocumentRow(document: document)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Legacy Document Row

private struct LegacyDocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accent.opacity(0.2))
                .frame(width: 60, height: 80)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.system(size: 16, weight: .semibold))

                Text(document.createdAt, style: .date)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
        }
        .padding(12)
        .background(Color.surfaceWhite)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    DocumentsList(documents: [
        Document(
            name: "Blood Test Results",
            fileURL: URL(fileURLWithPath: "/tmp/doc1.pdf"),
            documentType: .pdf,
            category: .bloodTests
        ),
        Document(
            name: "X-Ray Scan",
            fileURL: URL(fileURLWithPath: "/tmp/doc2.png"),
            documentType: .image,
            category: .imaging
        ),
        Document(
            name: "Prescription - March",
            fileURL: URL(fileURLWithPath: "/tmp/doc3.pdf"),
            documentType: .pdf,
            category: .prescriptions
        ),
    ])
    .background(Color.backgroundPrimary)
}

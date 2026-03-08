import SwiftUI

struct DocumentsList: View {
    let documents: [Document]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(documents) { document in
                    DocumentRow(document: document)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Document Row

private struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.2))
                .frame(width: 60, height: 80)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.system(size: 16, weight: .semibold))

                Text(document.date, style: .date)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DocumentsList(documents: [
        Document(title: "Medical Report", date: Date(), imageURL: nil, category: "Blood Tests"),
        Document(title: "X-Ray Results", date: Date(), imageURL: nil, category: "Tests & Imaging")
    ])
    .background(Color(.systemGroupedBackground))
}

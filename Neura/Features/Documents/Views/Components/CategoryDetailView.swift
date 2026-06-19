import SwiftUI

struct CategoryDetailView: View {
    let folder: CategoryFolder
    @EnvironmentObject var viewModel: DocsViewModel
    @State private var groupedDocuments: [GroupedDocument] = []
    @State private var appearAnimations: [Bool] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if groupedDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottomTrailing) {
            addNewFileButton
        }
        .onAppear {
            animateAppearance()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.textTertiary.opacity(0.5))
                .padding(.top, 60)

            Text(L10n.Documents.Category.noDocumentsYet)
                .font(.headingS)
                .foregroundColor(.textPrimary)

            Text(L10n.Documents.Category.scanFirst)
                .font(.bodyS)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var documentList: some View {
        ForEach(Array(groupedDocuments.enumerated()), id: \.element.id) { index, group in
            VStack(alignment: .leading, spacing: 12) {
                Text(group.month)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    ForEach(group.documents) { document in
                        DocumentDetailRow(
                            document: document,
                            icon: folder.icon,
                            gradientColors: folder.gradientColors
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .opacity(index < appearAnimations.count && appearAnimations[index] ? 1 : 0)
            .offset(y: index < appearAnimations.count && appearAnimations[index] ? 0 : 20)
        }
    }

    private var addNewFileButton: some View {
        Button {
            viewModel.scanFromFolder(folder)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text(L10n.Documents.Category.addNewFile)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: folder.gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: folder.gradientColors.first?.opacity(0.4) ?? .clear, radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Data

    private func animateAppearance() {
        for index in 0..<groupedDocuments.count {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1)) {
                if index < appearAnimations.count {
                    appearAnimations[index] = true
                }
            }
        }
    }
}

// MARK: - Document Detail Row

struct DocumentDetailRow: View {
    let document: Document
    let icon: String
    let gradientColors: [Color]

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gradientColors.first?.opacity(0.15) ?? Color.accent.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: document.isPDF ? "doc.fill" : "photo.fill")
                    .font(.system(size: 20))
                    .foregroundColor(gradientColors.first ?? .accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)

                HStack(spacing: 4) {
                    Text(formatDate(document.createdAt))
                        .font(.system(size: 14))
                        .foregroundColor(.textTertiary)

                    if document.pageCount > 1 {
                        Text("·")
                            .foregroundColor(.textTertiary)
                        Text(L10n.Documents.Viewer.pagesCount(document.pageCount))
                            .font(.system(size: 14))
                            .foregroundColor(.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
        }
        .padding(16)
        .background(Color.surfaceWhite)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("With Documents") {
    NavigationStack {
        CategoryDetailView(
            folder: CategoryFolder(
                name: "Blood Tests",
                count: 3,
                icon: "Blood",
                gradientColors: [Color(hex: "BD6B73"), Color(hex: "A85861")]
            )
        )
        .environmentObject(DocsViewModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        CategoryDetailView(
            folder: CategoryFolder(
                name: "Consultations",
                count: 0,
                icon: "Consultation",
                gradientColors: [Color(hex: "6B9080"), Color(hex: "5A7A6C")]
            )
        )
        .environmentObject(DocsViewModel())
    }
}

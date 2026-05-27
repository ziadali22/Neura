import SwiftUI

struct CategoryDocumentsView: View {
    let category: DocumentCategory
    @ObservedObject var viewModel: DocumentsListViewModel
    @State private var searchText = ""

    private var documents: [Document] {
        viewModel.documents
            .filter { $0.category == category }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty else { return documents }
        let query = searchText.lowercased()
        return documents.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                categoryEmptyState
            } else {
                VStack(spacing: 0) {
                    searchBar
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredDocuments) { document in
                                NavigationLink(value: document) {
                                    DocumentListRow(document: document)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
                .font(.system(size: 15))
            TextField("Search documents", text: $searchText)
                .font(.bodyL)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

    private var categoryEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            if let assetName = category.assetIcon {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
            } else {
                Image(systemName: category.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(category.color)
            }

            VStack(spacing: 8) {
                Text("No \(category.localizedName)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Scan or upload a document and tag it as \(category.localizedName).")
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                viewModel.showAddOptions()
            } label: {
                Text("Add document")
                    .font(.buttonM)
                    .foregroundStyle(.white)
                    .frame(width: 190)
                    .padding(.vertical, 14)
                    .background(Color.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 4)

            Spacer()
        }
    }
}

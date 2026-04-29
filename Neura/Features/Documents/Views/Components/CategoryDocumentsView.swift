import SwiftUI

struct CategoryDocumentsView: View {
    let category: DocumentCategory
    @ObservedObject var viewModel: DocumentsListViewModel

    private var documents: [Document] {
        viewModel.documents
            .filter { $0.category == category }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                ContentUnavailableView(
                    "No \(category.localizedName)",
                    systemImage: category.icon,
                    description: Text("Scan or upload a document and tag it as \(category.localizedName).")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(documents) { document in
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
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.large)
        .background(Color.backgroundPrimary)
    }
}

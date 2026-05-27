import SwiftUI

struct DocsFoldersGrid: View {
    @ObservedObject var viewModel: DocumentsListViewModel
    @ObservedObject var folderStore: CustomFolderStore
    @Binding var showNewFolderAlert: Bool
    @Binding var newFolderName: String

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            grid
        }
        .scrollIndicators(.hidden)
    }

    private var grid: some View {
        let docsByCategory = Dictionary(
            grouping: viewModel.documents.filter { $0.category != nil },
            by: { $0.category! }
        )
        return LazyVGrid(columns: columns, spacing: 12) {
            // Built-in categories
            ForEach(DocumentCategory.allCases) { category in
                NavigationLink(value: category) {
                    CategoryFolderGridCard(
                        category: category,
                        count: (docsByCategory[category] ?? []).count
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // User-created custom folders
            ForEach(folderStore.folders) { folder in
                let count = viewModel.documents.filter {
                    $0.tags?.contains(folder.id.uuidString) == true
                }.count
                NavigationLink(value: folder) {
                    CustomFolderGridCard(folder: folder, count: count)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // New Folder card
            Button {
                newFolderName = ""
                showNewFolderAlert = true
            } label: {
                NewFolderGridCard()
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
}

import SwiftUI

struct DocsFoldersGrid: View {
    @ObservedObject var viewModel: DocumentsListViewModel
    @ObservedObject var folderStore: CustomFolderStore
    @Binding var showNewFolderAlert: Bool
    @Binding var newFolderName: String

    @State private var folderPendingDelete: CustomFolder?
    @State private var folderToRename: CustomFolder?
    @State private var renameText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            grid
        }
        .scrollIndicators(.hidden)
        .alert("Rename Folder", isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField(L10n.Documents.Folder.namePlaceholder, text: $renameText)
            Button(L10n.Common.save) {
                if let folder = folderToRename {
                    folderStore.rename(folder, to: renameText)
                }
                folderToRename = nil
            }
            Button(L10n.Common.cancel, role: .cancel) { folderToRename = nil }
        }
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
                .contextMenu {
                    Button {
                        renameText = folder.name
                        // Defer so the context menu can finish dismissing before
                        // we present — otherwise SwiftUI swallows the alert.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            folderToRename = folder
                        }
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            folderPendingDelete = folder
                        }
                    } label: {
                        Label(L10n.Common.delete, systemImage: "trash")
                    }
                }
                // Anchor the delete confirmation to this specific folder card so
                // the popover points right at it instead of floating elsewhere.
                .popover(isPresented: Binding(
                    get: { folderPendingDelete?.id == folder.id },
                    set: { if !$0 { folderPendingDelete = nil } }
                )) {
                    deleteConfirmation(folder)
                }
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

    // MARK: - Delete Confirmation

    private func deleteConfirmation(_ folder: CustomFolder) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Delete \"\(folder.name)\"?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text("The folder will be removed. Your documents stay safe and remain in their categories.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button {
                    folderPendingDelete = nil
                } label: {
                    Text(L10n.Common.cancel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.backgroundPrimary)
                        .clipShape(Capsule())
                }

                Button {
                    let toDelete = folder
                    folderPendingDelete = nil
                    withAnimation { folderStore.delete(toDelete) }
                } label: {
                    Text(L10n.Common.delete)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
    }
}

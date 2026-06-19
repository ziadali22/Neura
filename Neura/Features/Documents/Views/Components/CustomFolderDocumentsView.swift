import SwiftUI

struct CustomFolderDocumentsView: View {
    let folder: CustomFolder
    @ObservedObject var viewModel: DocumentsListViewModel
    @ObservedObject private var folderStore = CustomFolderStore.shared

    @State private var showRename = false
    @State private var renameText = ""
    @State private var searchText = ""

    private var documents: [Document] {
        viewModel.documents
            .filter { $0.tags?.contains(folder.id.uuidString) == true }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty else { return documents }
        let query = searchText.lowercased()
        return documents.filter { $0.name.lowercased().contains(query) }
    }

    private var monthSections: [MonthSection] {
        let calendar = Calendar.current
        var groups: [Date: [Document]] = [:]
        for doc in filteredDocuments {
            let comps = calendar.dateComponents([.year, .month], from: doc.createdAt)
            if let monthStart = calendar.date(from: comps) {
                groups[monthStart, default: []].append(doc)
            }
        }
        return groups.map { date, docs in
            MonthSection(
                date: date,
                title: date.formatted(.dateTime.month(.wide).year()),
                documents: docs.sorted { $0.createdAt > $1.createdAt }
            )
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                folderEmptyState
            } else {
                VStack(spacing: 0) {
                    searchBar
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(monthSections) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.title)
                                        .font(.headingXS)
                                        .foregroundStyle(Color.textSecondary)
                                        .padding(.horizontal, 4)

                                    VStack(spacing: 8) {
                                        ForEach(section.documents) { document in
                                            NavigationLink(value: document) {
                                                CustomFolderDocumentRow(document: document)
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle(currentName)
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    renameText = currentName
                    showRename = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .alert(L10n.Documents.Folder.renameTitle, isPresented: $showRename) {
            TextField(L10n.Documents.Folder.namePlaceholder, text: $renameText)
            Button(L10n.Common.rename) { folderStore.rename(folder, to: renameText) }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
    }

    private var currentName: String {
        folderStore.folders.first(where: { $0.id == folder.id })?.name ?? folder.name
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
                .font(.system(size: 15))
            TextField(L10n.Documents.searchPlaceholder, text: $searchText)
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

    private var folderEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "folder.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accent)

            VStack(spacing: 8) {
                Text(L10n.Documents.Folder.noDocuments)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Documents.Folder.emptyDescriptionFormat(currentName))
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                viewModel.showAddOptions()
            } label: {
                Text(L10n.Documents.addDocument)
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

// MARK: - Month Section

private struct MonthSection: Identifiable {
    var id: Date { date }
    let date: Date
    let title: String
    let documents: [Document]
}

// MARK: - Document Row

private struct CustomFolderDocumentRow: View {
    let document: Document
    @ScaledMetric private var iconSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.accent.opacity(0.13))
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accent)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(document.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(document.createdAt.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

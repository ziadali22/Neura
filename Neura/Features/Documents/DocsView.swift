import SwiftUI

struct DocsView: View {
    @EnvironmentObject private var router: DocsRouter
    @StateObject private var viewModel = DocsViewModel()

    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(spacing: 0) {
                SearchFilterBar(
                    searchText: $viewModel.searchText,
                    onFilterTapped: viewModel.handleFilterTap
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if viewModel.folders.isEmpty {
                    EmptyDocumentsView(
                        onAddDocument: viewModel.handleAddDocument
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            CategoryFilterView(selectedCategory: $viewModel.selectedCategory)
                                .padding(.top, 16)

                            CategoryFolderGrid(
                                folders: viewModel.folders,
                                onAddFolder: viewModel.handleAddFolder
                            )
                            .environmentObject(viewModel)
                            .padding(.top, 8)
                        }
                        .padding(.bottom, 100)
                    }
                }

                Spacer()
            }
            .background(Color(red: 0.99, green: 0.98, blue: 0.97))
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: DocsRoute.self) { route in
                switch route {
                case .categoryDetail(let name):
                    EmptyView() // TODO: Implement
                }
            }
            .overlay {
                ScanProcessingView(isProcessing: viewModel.isProcessingScan)
            }
            .fullScreenCover(isPresented: $viewModel.showScanner) {
                DocumentScanner { result in
                    viewModel.handleScanResult(result)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $viewModel.showNamingView) {
                if let folder = viewModel.selectedFolderForScan {
                    DocumentNamingView(
                        scannedImages: viewModel.scannedImages,
                        category: folder.name,
                        onSave: { name in
                            viewModel.saveDocumentWithName(name)
                        }
                    )
                }
            }
            .alert("Error", isPresented: .constant(viewModel.scanError != nil)) {
                Button("OK") {
                    viewModel.scanError = nil
                }
            } message: {
                if let error = viewModel.scanError {
                    Text(error)
                }
            }
        }
    }
}

#Preview {
    DocsView()
        .environmentObject(DocsRouter())
}

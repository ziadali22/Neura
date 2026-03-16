import SwiftUI
import Combine

// Legacy ViewModel kept for CategoryDetailView/CategoryFolderGrid compatibility.
// New document pipeline uses DocumentsListViewModel.

final class DocsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: Category = .all
    @Published var folders: [CategoryFolder] = []

    @Published var showCategoryPicker = false
    @Published var showScanner = false
    @Published var showNamingView = false
    @Published var selectedFolderForScan: CategoryFolder?
    @Published var scannedImages: [UIImage] = []
    @Published var isProcessingScan = false
    @Published var scanError: String?

    init() {
        loadFolders()
    }

    // MARK: - Data Loading

    private func loadFolders() {
        folders = [
            CategoryFolder(
                name: "Blood Tests",
                count: 0,
                icon: "Blood",
                gradientColors: [Color(hex: "BD6B73"), Color(hex: "A85861")]
            ),
            CategoryFolder(
                name: "Prescriptions",
                count: 0,
                icon: "Prescriptions",
                gradientColors: [Color(hex: "456990"), Color(hex: "3A5777")]
            ),
            CategoryFolder(
                name: "Consultations",
                count: 0,
                icon: "Consultation",
                gradientColors: [Color(hex: "6B9080"), Color(hex: "5A7A6C")]
            ),
            CategoryFolder(
                name: "Hospitalization",
                count: 0,
                icon: "Hospitalisation",
                gradientColors: [Color(hex: "536B78"), Color(hex: "455863")]
            ),
            CategoryFolder(
                name: "Tests & Imaging",
                count: 0,
                icon: "Investigationspdf",
                gradientColors: [Color(hex: "8B7E8F"), Color(hex: "756A79")]
            )
        ]
    }

    // MARK: - Actions

    func handleFilterTap() {}
    func handleAddDocument() { showCategoryPicker = true }
    func handleAddFolder() {}

    func scanFromFolder(_ folder: CategoryFolder) {
        selectedFolderForScan = folder
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showScanner = true
    }
}

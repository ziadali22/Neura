import SwiftUI
import Combine

// MARK: - App Coordinator

@MainActor
final class AppCoordinator: ObservableObject {
    enum Tab: Int {
        case profile = 0
        case home = 1
        case docs = 2
    }

    enum AddDocumentAction { case scan, photo, file }

    @Published var selectedTab: Tab = .home
    @Published var showAddMenu = false
    @Published var pendingAddAction: AddDocumentAction? = nil
    @Published var isInDetailView = false
    @Published var isSelectingDocs = false

    let profileRouter = ProfileRouter()
    let homeRouter = HomeRouter()
    let docsRouter = DocsRouter()

    private var cancellables = Set<AnyCancellable>()

    init() {
        homeRouter.$path
            .combineLatest(profileRouter.$path)
            .combineLatest(docsRouter.$path)
            .map { homePlusProfile, docs in
                let (home, profile) = homePlusProfile
                return !home.isEmpty || !profile.isEmpty || !docs.isEmpty
            }
            .assign(to: &$isInDetailView)
    }
}

// MARK: - Route Definitions

enum ProfileRoute: Hashable {
    case healthProfile
    case language
}

enum HomeRoute: Hashable {
    case healthProfile
    case healthProfileDetail
    case emergencyCard
}

enum DocsRoute: Hashable {
    case categoryDetail(String)
}

// MARK: - Router Type Aliases

typealias ProfileRouter = NavigationRouter<ProfileRoute>
typealias HomeRouter = NavigationRouter<HomeRoute>
typealias DocsRouter = NavigationRouter<DocsRoute>

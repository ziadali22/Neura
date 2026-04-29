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

    @Published var selectedTab: Tab = .home
    @Published var showAddDocument = false
    @Published var isInDetailView = false
    @Published var isSelectingDocs = false

    let profileRouter = ProfileRouter()
    let homeRouter = HomeRouter()
    let docsRouter = DocsRouter()

    private var cancellables = Set<AnyCancellable>()

    init() {
        homeRouter.$path
            .combineLatest(profileRouter.$path)
            .map { home, profile in !home.isEmpty || !profile.isEmpty }
            .assign(to: &$isInDetailView)
    }
}

// MARK: - Route Definitions

enum ProfileRoute: Hashable {
    case healthProfile
    case language
}

enum HomeRoute: Hashable {
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

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

    let profileRouter = ProfileRouter()
    let homeRouter = HomeRouter()
    let docsRouter = DocsRouter()
}

// MARK: - Route Definitions

enum ProfileRoute: Hashable {
    case healthProfile
    case language
}

enum HomeRoute: Hashable {
    case healthProfileDetail
}

enum DocsRoute: Hashable {
    case categoryDetail(String)
}

// MARK: - Router Type Aliases

typealias ProfileRouter = NavigationRouter<ProfileRoute>
typealias HomeRouter = NavigationRouter<HomeRoute>
typealias DocsRouter = NavigationRouter<DocsRoute>

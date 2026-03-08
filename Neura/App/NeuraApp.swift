import SwiftUI

@main
struct NeuraApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.light)
        }
    }
}

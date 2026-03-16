import SwiftUI

@main
struct NeuraApp: App {
    @State private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.light)
                .environment(\.locale, languageManager.locale)
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .environment(languageManager)
        }
    }
}

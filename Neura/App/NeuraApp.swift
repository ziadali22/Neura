import SwiftUI

@main
struct NeuraApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                DashboardView()
                    .preferredColorScheme(.light)
                    .environment(\.locale, languageManager.locale)
                    .environment(\.layoutDirection, languageManager.layoutDirection)
                    .environment(languageManager)

                if showSplash {
                    SplashView(isPresented: $showSplash)
                        .ignoresSafeArea()
                        .zIndex(1)
                }
            }
        }
    }
}

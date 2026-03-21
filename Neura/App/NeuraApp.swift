import SwiftUI

@main
struct NeuraApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var showSplash = true
    @State private var hasCompletedOnboarding: Bool

    init() {
        // Skip onboarding for existing users who already have profile data
        let key = "hasCompletedOnboarding"
        if !UserDefaults.standard.bool(forKey: key),
           UserDefaults.standard.data(forKey: "health_profile_data") != nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        _hasCompletedOnboarding = State(initialValue: UserDefaults.standard.bool(forKey: key))
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
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
            } else {
                OnboardingView(onComplete: {
                    withAnimation { hasCompletedOnboarding = true }
                })
                .preferredColorScheme(.light)
                .environment(\.locale, languageManager.locale)
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .environment(languageManager)
            }
        }
    }
}

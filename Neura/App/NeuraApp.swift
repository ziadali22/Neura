import SwiftUI

@main
struct NeuraApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var showSplash: Bool
    @State private var hasCompletedOnboarding: Bool

    init() {
        let key = "hasCompletedOnboarding"
        // Skip onboarding for existing users who already have profile data
        if !UserDefaults.standard.bool(forKey: key),
           UserDefaults.standard.data(forKey: "health_profile_data") != nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        let done = UserDefaults.standard.bool(forKey: key)
        _hasCompletedOnboarding = State(initialValue: done)
        // Only show launch splash for returning users;
        // new users get it triggered by onComplete instead.
        _showSplash = State(initialValue: done)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    DashboardView()
                        .preferredColorScheme(.light)
                        .environment(\.locale, languageManager.locale)
                        .environment(\.layoutDirection, languageManager.layoutDirection)
                        .environment(languageManager)
                } else {
                    OnboardingView(onComplete: {
                        // Show splash first — it covers the switch to DashboardView,
                        // turning the hard cut into a branded transition moment.
                        showSplash = true
                        hasCompletedOnboarding = true
                    })
                    .preferredColorScheme(.light)
                    .environment(\.locale, languageManager.locale)
                    .environment(\.layoutDirection, languageManager.layoutDirection)
                    .environment(languageManager)
                }

                if showSplash {
                    SplashView(isPresented: $showSplash)
                        .ignoresSafeArea()
                        .zIndex(1)
                }
            }
        }
    }
}

import SwiftUI
import FirebaseCore
import GoogleSignIn

//Firebase Integrations
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    return true
  }
}


@main
struct NeuraApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var showSplash: Bool
    @State private var hasCompletedOnboarding: Bool
    @State private var isSignedIn: Bool
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // Configure Firebase first — must happen before any Auth/Firestore access
        FirebaseApp.configure()

        // Configure Google Sign-In using the client ID from GoogleService-Info.plist
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        let key = "hasCompletedOnboarding"
        // Skip onboarding for existing users who already have profile data
        if !UserDefaults.standard.bool(forKey: key),
           UserDefaults.standard.data(forKey: "health_profile_data") != nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        let done = UserDefaults.standard.bool(forKey: key)
        let signedIn = Auth.auth().currentUser != nil
        _hasCompletedOnboarding = State(initialValue: done)
        _isSignedIn = State(initialValue: signedIn)
        _showSplash = State(initialValue: done && signedIn)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isSignedIn && hasCompletedOnboarding {
                    DashboardView()
                        .preferredColorScheme(.light)
                        .environment(\.locale, languageManager.locale)
                        .environment(\.layoutDirection, languageManager.layoutDirection)
                        .environment(languageManager)
                } else {
                    OnboardingView(onComplete: {
                        showSplash = true
                        hasCompletedOnboarding = true
                        isSignedIn = true
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            // Only react to sign-out — not to sign-in during onboarding
            .onReceive(AuthService.shared.$currentUser) { user in
                if user == nil {
                    isSignedIn = false
                    hasCompletedOnboarding = false
                }
            }
        }
    }
}

// Needed so NeuraApp.init() can read the Firebase auth cache synchronously
import FirebaseAuth

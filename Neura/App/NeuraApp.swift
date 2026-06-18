import SwiftUI
import FirebaseCore
import GoogleSignIn

//Firebase Integrations
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
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

        // Configure analytics (no-ops until a real Mixpanel token is set).
        AnalyticsManager.shared.initialize()

        let key = "hasCompletedOnboarding"
        // Skip onboarding for existing users who already have profile data
        if !UserDefaults.standard.bool(forKey: key),
           UserDefaults.standard.data(forKey: "health_profile_data") != nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        // Reinstall detection: onboarding not complete means UserDefaults was wiped (reinstall or
        // fresh install). Sign out any stale Firebase session that persisted in Keychain so the
        // wrong account's data is never shown and the user is always forced to authenticate fresh.
        if !UserDefaults.standard.bool(forKey: key),
           Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
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
            .onAppear {
                scheduleProfileNotificationIfNeeded()
            }
            .task {
                // Start the StoreKit transaction listener and reconcile Pro entitlement.
                SubscriptionManager.shared.start()
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

// MARK: - Notification helpers

private extension NeuraApp {
    /// Reads the saved profile from UserDefaults and asks the notification manager
    /// to schedule (or cancel) reminders based on current fill state.
    func scheduleProfileNotificationIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: "health_profile_data"),
              let profile = try? JSONDecoder().decode(HealthProfile.self, from: data) else {
            // No profile saved yet — schedule a gentle first-time nudge
            ProfileNotificationManager.shared.requestPermissionAndScheduleIfNeeded(filledCount: 0, total: 8)
            return
        }
        let g = profile.generalData
        let fields = [g.fullName, g.dateOfBirth, g.gender, g.height, g.weight,
                      g.bloodType, g.insuranceStatus, g.myPhoneNumber, g.emergencyContactName, g.emergencyContactNumber]
        let filled = fields.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        ProfileNotificationManager.shared.requestPermissionAndScheduleIfNeeded(filledCount: filled, total: fields.count)
    }
}

// Needed so NeuraApp.init() can read the Firebase auth cache synchronously
import FirebaseAuth

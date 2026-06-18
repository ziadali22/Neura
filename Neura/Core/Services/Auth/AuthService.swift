import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import CryptoKit
import Combine

// MARK: - Auth Service

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: FirebaseAuth.User?

    var isSignedIn: Bool { currentUser != nil }

    private var stateListener: AuthStateDidChangeListenerHandle?

    private init() {
        // currentUser is available synchronously from Firebase's persisted cache
        currentUser = Auth.auth().currentUser
        if let uid = currentUser?.uid {
            // Re-tie analytics to the logged-in user on every app launch.
            AnalyticsManager.shared.identify(uid)
            restoreCloudData(for: uid)
        }
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.currentUser = user }
        }
    }

    deinit {
        if let stateListener { Auth.auth().removeStateDidChangeListener(stateListener) }
    }

    // MARK: - Sign In with Apple

    /// Returns the user's display name as provided by Apple, if any. Apple only supplies
    /// `fullName` on the *first* authorization for an Apple ID (nil on re-auth), so callers
    /// must treat a nil result as "not provided" — never require the user to re-enter it.
    @discardableResult
    func signInWithApple() async throws -> String? {
        let result = try await AppleSignInHandler.shared.signIn()
        let credential = OAuthProvider.appleCredential(
            withIDToken: result.idToken,
            rawNonce: result.nonce,
            fullName: result.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        onSignInSuccess(uid: authResult.user.uid)
        return Self.displayName(from: result.fullName)
    }

    // MARK: - Sign In with Google

    /// Returns the user's display name as provided by Google, if any.
    @discardableResult
    func signInWithGoogle() async throws -> String? {
        let (credential, name) = try await googleSignInResult()
        let authResult = try await Auth.auth().signIn(with: credential)
        onSignInSuccess(uid: authResult.user.uid)
        return name
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        KeychainManager.shared.clearKey()
        AnalyticsManager.shared.reset()
        currentUser = nil
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }

        // Delete server-side data (Storage + Firestore) before revoking auth
        if let token = try? await user.getIDToken() {
            var req = URLRequest(url: URL(string: "\(FirebaseConfig.cloudFunctionBaseURL)/deleteUserData")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }

        do {
            try await user.delete()
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            // Account deletion is security-sensitive: Firebase rejects it unless the user
            // signed in recently. Reauthenticate with their provider, then retry once so
            // the account is actually removed from Firebase rather than silently left behind.
            let credential = try await reauthCredential(for: user)
            try await user.reauthenticate(with: credential)
            try await user.delete()
        }
        KeychainManager.shared.clearKey()
        AnalyticsManager.shared.reset()
        currentUser = nil
    }

    // MARK: - Cloud Existence Check

    /// Returns true if this uid already has any private cloud data in Firestore.
    /// Used during onboarding to detect returning users without decrypting anything.
    func hasExistingCloudData(uid: String) async -> Bool {
        let database = Firestore.firestore()
        let userDocument = database.collection("users").document(uid)

        async let profileSnapshot = userDocument
            .collection("profile").document("data")
            .getDocument()

        async let preferencesSnapshot = userDocument
            .collection("preferences").document("data")
            .getDocument()

        async let documentsSnapshot = userDocument
            .collection("documents")
            .limit(to: 1)
            .getDocuments()

        do {
            let (profile, preferences, documents) = try await (
                profileSnapshot,
                preferencesSnapshot,
                documentsSnapshot
            )
            return profile.exists || preferences.exists || !documents.documents.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Private

    // MARK: - Credentials

    private func appleCredential() async throws -> AuthCredential {
        let result = try await AppleSignInHandler.shared.signIn()
        return OAuthProvider.appleCredential(
            withIDToken: result.idToken,
            rawNonce: result.nonce,
            fullName: result.fullName
        )
    }

    /// Presents Google Sign-In and returns both the Firebase credential and the user's
    /// display name (if Google provides one).
    private func googleSignInResult() async throws -> (credential: AuthCredential, name: String?) {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = scene.keyWindow?.rootViewController else {
            throw AuthError.noRootViewController
        }
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let name = result.user.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (credential, (name?.isEmpty == false) ? name : nil)
    }

    private func googleCredential() async throws -> AuthCredential {
        try await googleSignInResult().credential
    }

    /// Formats Apple's `PersonNameComponents` into a display string, returning nil if empty.
    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter()
            .string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Obtains a fresh credential from the user's original sign-in provider so a
    /// security-sensitive operation (e.g. account deletion) can reauthenticate.
    private func reauthCredential(for user: FirebaseAuth.User) async throws -> AuthCredential {
        switch user.providerData.first?.providerID {
        case "google.com": return try await googleCredential()
        case "apple.com":  return try await appleCredential()
        default:           throw AuthError.unsupportedReauthProvider
        }
    }

    private func onSignInSuccess(uid: String) {
        // Tie all subsequent events to this user; keyed on the Firebase UID
        // (a stable primary key) — never email.
        AnalyticsManager.shared.identify(uid)
        restoreCloudData(for: uid)
    }

    private func restoreCloudData(for uid: String) {
        Task {
            guard let key = await EncryptionKeyService.shared.resolveKey(uid: uid) else {
                SyncLog.info("Key unavailable (offline); deferring restore and sync")
                return
            }
            // Key is now cached in KeychainManager. Pull cloud data down, then push
            // anything that failed to upload previously.
            SyncQueueManager.shared.performInitialRestore(uid: uid, key: key)
            SyncQueueManager.shared.drainPending()
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noRootViewController
    case missingToken
    case unsupportedReauthProvider

    var errorDescription: String? {
        switch self {
        case .noRootViewController:      return "Unable to present sign-in screen."
        case .missingToken:              return "Sign-in failed: missing authentication token."
        case .unsupportedReauthProvider: return "Unable to re-verify your identity for this account."
        }
    }
}

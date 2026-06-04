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

    func signInWithApple() async throws {
        let result = try await AppleSignInHandler.shared.signIn()
        let credential = OAuthProvider.appleCredential(
            withIDToken: result.idToken,
            rawNonce: result.nonce,
            fullName: result.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        onSignInSuccess(uid: authResult.user.uid)
    }

    // MARK: - Sign In with Google

    func signInWithGoogle() async throws {
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
        let authResult = try await Auth.auth().signIn(with: credential)
        onSignInSuccess(uid: authResult.user.uid)
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        KeychainManager.shared.clearKey()
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

        try await user.delete()
        KeychainManager.shared.clearKey()
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

    private func onSignInSuccess(uid: String) {
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

    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "Unable to present sign-in screen."
        case .missingToken:         return "Sign-in failed: missing authentication token."
        }
    }
}

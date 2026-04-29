import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - Apple Sign In Result

struct AppleSignInResult {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
}

// MARK: - Apple Sign In Handler

final class AppleSignInHandler: NSObject {
    static let shared = AppleSignInHandler()

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

    private override init() { super.init() }

    // MARK: - Sign In

    @MainActor
    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let nonce = randomNonceString()
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            randoms.forEach { byte in
                guard remaining > 0 else { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInHandler: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.missingToken)
            continuation = nil
            return
        }

        let result = AppleSignInResult(
            idToken: idToken,
            nonce: nonce,
            fullName: credential.fullName
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInHandler: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? ASPresentationAnchor()
    }
}

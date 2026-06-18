import Foundation
import UIKit
import FirebaseFirestore

// MARK: - Feedback Service

/// Writes user feedback to the top-level `feedback` collection.
/// Plain (unencrypted), append-only write — feedback is not sensitive health data.
actor FeedbackService {
    static let shared = FeedbackService()

    private init() {}

    /// Submits one feedback entry. `uid` is attached only when a user is signed in.
    func submit(email: String, message: String, uid: String?) async throws {
        var data: [String: Any] = [
            "email": email,
            "message": message,
            "createdAt": FieldValue.serverTimestamp(),
            "appVersion": Self.appVersion,
            "platform": Self.platform,
            "locale": UserDefaults.standard.string(forKey: "app_language") ?? "en"
        ]
        if let uid {
            data["uid"] = uid
        }

        try await Firestore.firestore()
            .collection("feedback")
            .addDocument(data: data)
    }

    // MARK: - Metadata

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static var platform: String {
        "iOS \(UIDevice.current.systemVersion)"
    }
}

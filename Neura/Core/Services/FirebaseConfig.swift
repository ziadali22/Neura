import Foundation

// MARK: - Firebase Configuration

enum FirebaseConfig {
    // MARK: - Project Settings
    // Replace these with your Firebase project values
    static let storageBucket = "YOUR_PROJECT_ID.firebasestorage.app"
    static let cloudFunctionBaseURL = "https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net"
    static let apiKey = "YOUR_API_KEY"

    // MARK: - Upload Settings
    static let maxFileSizeBytes: Int = 10 * 1024 * 1024 // 10MB
    static let sharedFolderPrefix = "shared"
    static let linkExpirationSeconds: TimeInterval = 2 * 60 * 60 // 2 hours

    // MARK: - Endpoints

    static var uploadURL: String {
        "https://firebasestorage.googleapis.com/v0/b/\(storageBucket)/o"
    }

    static var shareURL: String {
        "\(cloudFunctionBaseURL)/getShareUrl"
    }

    static func redirectURL(fileId: String) -> String {
        "\(cloudFunctionBaseURL)/share/\(fileId)"
    }

    // MARK: - Validation

    static var isConfigured: Bool {
        storageBucket != "YOUR_PROJECT_ID.firebasestorage.app"
            && apiKey != "YOUR_API_KEY"
            && cloudFunctionBaseURL != "https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net"
    }
}

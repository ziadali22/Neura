import Foundation
import Combine

// MARK: - Subscription Manager

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private let freeUploadLimit = 3
    private let freeShareLimit = 1
    private let uploadCountKey = "neura_document_upload_count"
    private let shareCountKey = "neura_share_count"
    private let isProKey = "neura_is_pro"

    @Published private(set) var uploadCount: Int
    @Published private(set) var shareCount: Int
    @Published private(set) var isPro: Bool

    var remainingUploads: Int {
        max(0, freeUploadLimit - uploadCount)
    }

    var canUpload: Bool {
        isPro || uploadCount < freeUploadLimit
    }

    var canShareViaQR: Bool {
        isPro || shareCount < freeShareLimit
    }

    var limitText: String {
        "\(uploadCount)/\(freeUploadLimit)"
    }

    private init() {
        self.uploadCount = UserDefaults.standard.integer(forKey: uploadCountKey)
        self.shareCount = UserDefaults.standard.integer(forKey: shareCountKey)
        self.isPro = UserDefaults.standard.bool(forKey: isProKey)
    }

    // MARK: - Actions

    func recordUpload() {
        guard !isPro else { return }
        uploadCount += 1
        UserDefaults.standard.set(uploadCount, forKey: uploadCountKey)
    }

    func recordShare() {
        guard !isPro else { return }
        shareCount += 1
        UserDefaults.standard.set(shareCount, forKey: shareCountKey)
    }

    func upgradeToPro() {
        isPro = true
        UserDefaults.standard.set(true, forKey: isProKey)
    }

    func restorePurchase() {
        // In a real app, verify with StoreKit
        isPro = true
        UserDefaults.standard.set(true, forKey: isProKey)
    }

    func reset() {
        isPro = false
        uploadCount = 0
        shareCount = 0
        UserDefaults.standard.set(false, forKey: isProKey)
        UserDefaults.standard.set(0, forKey: uploadCountKey)
        UserDefaults.standard.set(0, forKey: shareCountKey)
    }
}

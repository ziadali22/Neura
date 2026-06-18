import Foundation
import Combine
import StoreKit

// MARK: - Subscription Manager

/// Single source of truth for Neura Pro entitlement.
///
/// Pro state is driven by StoreKit 2 `Transaction.currentEntitlements` — never by a
/// manually-set flag. `isPro` is recomputed after purchase, after restore, at launch,
/// and whenever `Transaction.updates` fires (renewals, refunds, Ask-to-Buy approvals).
/// The cached UserDefaults value only avoids a launch flicker before the async check runs.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// App Store Connect product identifiers. Must match exactly or products fail to load.
    enum Product_ID {
        static let monthly = "com.neura.monthly"
        static let annual = "com.neura.annual"
        static let all = [annual, monthly]
    }

    private let freeUploadLimit = 3
    private let freeShareLimit = 1
    private let uploadCountKey = "neura_document_upload_count"
    private let shareCountKey = "neura_share_count"
    private let isProKey = "neura_is_pro"
    private let subscriptionExpiredKey = "neura_subscription_expired"
    private let everHadProKey = "neura_ever_had_pro"

    @Published private(set) var uploadCount: Int
    @Published private(set) var shareCount: Int
    @Published private(set) var isPro: Bool
    /// True when the user *had* a Pro subscription that has since lapsed.
    @Published private(set) var subscriptionExpired: Bool

    /// Details of the currently-active Pro subscription, or `nil` when not subscribed.
    ///
    /// Populated asynchronously by `refreshEntitlements()` — it is `nil` on a cold launch
    /// even when the cached `isPro` is already `true`, so any UI must render nil-safely.
    @Published private(set) var activeSubscription: ActiveSubscription?

    /// Snapshot of the active subscription used to drive the Subscription detail screen.
    struct ActiveSubscription: Equatable {
        let productID: String
        /// For an auto-renewable, the next renewal date (or the final access date when
        /// auto-renew is off). `nil` if StoreKit didn't provide an expiration.
        let renewalDate: Date?
        /// Whether the subscription will renew (true) or lapse (false) on `renewalDate`.
        let willAutoRenew: Bool

        var isMonthly: Bool { productID == Product_ID.monthly }
    }

    /// Loaded StoreKit products (empty until `loadProducts()` succeeds).
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false

    private var updatesListenerTask: Task<Void, Never>?
    private var restoreObserver: NSObjectProtocol?

    /// Locked-document gate: subscription was active but is now expired.
    var hasExpiredSubscription: Bool { subscriptionExpired && !isPro }

    var remainingUploads: Int {
        max(0, freeUploadLimit - uploadCount)
    }

    var canUpload: Bool {
        isPro || uploadCount < freeUploadLimit
    }

    var canShareViaQR: Bool {
        isPro || shareCount < freeShareLimit
    }

    /// "remaining/total" for the home banner — counts down from the limit as uploads are used.
    var remainingText: String {
        "\(remainingUploads)/\(freeUploadLimit)"
    }

    private init() {
        self.uploadCount = UserDefaults.standard.integer(forKey: uploadCountKey)
        self.shareCount = UserDefaults.standard.integer(forKey: shareCountKey)
        self.isPro = UserDefaults.standard.bool(forKey: isProKey)
        self.subscriptionExpired = UserDefaults.standard.bool(forKey: subscriptionExpiredKey)

        // Reconcile the free-tier gate whenever cloud restore brings documents
        // back (reinstall / new device). The restored metadata is already on
        // disk by the time this fires, so re-reading the real count is accurate.
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .documentsRestored, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDocumentCount() }
        }
    }

    // MARK: - Lifecycle

    /// Call once at app launch. Starts the transaction listener and reconciles state with
    /// the App Store. Safe to call more than once (the listener is only started once).
    func start() {
        if updatesListenerTask == nil {
            updatesListenerTask = listenForTransactions()
        }
        // Reconcile the upload gate with the documents actually on disk, so a
        // cold launch after a reinstall/restore (or a lapsed Pro subscription)
        // reflects reality instead of a stale cached counter.
        refreshDocumentCount()
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    deinit {
        updatesListenerTask?.cancel()
        if let restoreObserver {
            NotificationCenter.default.removeObserver(restoreObserver)
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Product_ID.all)
            // Keep a stable order matching Product_ID.all (annual first, then monthly).
            self.products = loaded.sorted {
                let lhs = Product_ID.all.firstIndex(of: $0.id) ?? .max
                let rhs = Product_ID.all.firstIndex(of: $1.id) ?? .max
                return lhs < rhs
            }
        } catch {
            self.products = []
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Purchase

    enum PurchaseOutcome {
        case success
        case pending        // Ask-to-Buy / SCA — access not yet granted
        case cancelled
        case failed
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    AnalyticsManager.shared.track("subscription_started", properties: [
                        "product_id": product.id,
                        "price": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
                    return .success
                case .unverified:
                    return .failed
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    // MARK: - Restore

    /// Forces an App Store sync and re-checks entitlements. Returns true if Pro is now active.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    // MARK: - Entitlements (source of truth)

    /// Recomputes `isPro` from `Transaction.currentEntitlements`. Active auto-renewables
    /// appear here; expired ones drop out automatically, which is how a lapse is detected.
    func refreshEntitlements() async {
        var entitled = false
        var current: ActiveSubscription?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Product_ID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                entitled = true
                current = ActiveSubscription(
                    productID: transaction.productID,
                    renewalDate: transaction.expirationDate,
                    willAutoRenew: await willAutoRenew(for: transaction.productID) ?? true
                )
            }
        }
        activeSubscription = current
        applyEntitlement(active: entitled)
    }

    /// Best-effort auto-renew flag from the (already-loaded) product's subscription status.
    /// Returns `nil` when the product hasn't been loaded yet or StoreKit has no status,
    /// in which case callers default to treating the subscription as renewing.
    private func willAutoRenew(for productID: String) async -> Bool? {
        guard let subscription = product(for: productID)?.subscription,
              let statuses = try? await subscription.status else { return nil }
        for status in statuses {
            if case .verified(let renewalInfo) = status.renewalInfo {
                return renewalInfo.willAutoRenew
            }
        }
        return nil
    }

    private func applyEntitlement(active: Bool) {
        if active {
            isPro = true
            subscriptionExpired = false
            UserDefaults.standard.set(true, forKey: isProKey)
            UserDefaults.standard.set(false, forKey: subscriptionExpiredKey)
            UserDefaults.standard.set(true, forKey: everHadProKey)
        } else {
            let everHadPro = UserDefaults.standard.bool(forKey: everHadProKey)
            isPro = false
            subscriptionExpired = everHadPro
            UserDefaults.standard.set(false, forKey: isProKey)
            UserDefaults.standard.set(everHadPro, forKey: subscriptionExpiredKey)
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }

    // MARK: - Free-tier counters

    /// Reconciles `uploadCount` with the documents actually on disk — the single
    /// source of truth for the free-tier gate. Counting the real files (rather
    /// than maintaining a separate +1/−1 counter) keeps the home banner and the
    /// paywall accurate across adds, deletes, cloud restore, and Pro lapse. The
    /// count is intentionally NOT gated on `isPro`: a former-Pro user who drops
    /// to free must still be gated against the documents they already hold.
    /// The persisted value is only a launch-flicker cache; this recomputes it.
    func refreshDocumentCount() {
        let count = DocumentFileManager.shared.loadMetadata()
            .filter { $0.fileExists }
            .count
        guard count != uploadCount else { return }
        uploadCount = count
        UserDefaults.standard.set(count, forKey: uploadCountKey)
    }

    /// Call after a document is successfully saved. Reconciles against the real
    /// file count rather than blindly incrementing, so the gate can't drift.
    func recordUpload() {
        refreshDocumentCount()
    }

    /// Call after a document is deleted, so the limit tracks the documents the
    /// user currently has — deleting lets a free user upload again and the home
    /// banner counts back up.
    func recordDeletion() {
        refreshDocumentCount()
    }

    func recordShare() {
        guard !isPro else { return }
        shareCount += 1
        UserDefaults.standard.set(shareCount, forKey: shareCountKey)
    }

    // MARK: - Debug / reset

    func reset() {
        isPro = false
        subscriptionExpired = false
        activeSubscription = nil
        uploadCount = 0
        shareCount = 0
        UserDefaults.standard.set(false, forKey: isProKey)
        UserDefaults.standard.set(false, forKey: subscriptionExpiredKey)
        UserDefaults.standard.set(false, forKey: everHadProKey)
        UserDefaults.standard.set(0, forKey: uploadCountKey)
        UserDefaults.standard.set(0, forKey: shareCountKey)
    }
}

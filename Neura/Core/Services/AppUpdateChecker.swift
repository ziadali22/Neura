import Combine
import Foundation

// MARK: - Model

/// Describes an update that is available on the App Store but not yet installed.
struct AppUpdateInfo: Identifiable, Equatable {
    let version: String
    let appStoreURL: URL

    var id: String { version }
}

// MARK: - Service

/// Checks the App Store for a newer version of the app via Apple's iTunes
/// Lookup API and exposes the result for the UI to present.
///
/// Looking up by bundle identifier returns the live App Store `version` and the
/// store URL, so nothing needs to be hardcoded. All failures (no network, decode
/// errors, missing results) are swallowed — a failed check never blocks the UI.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    /// Set when a newer version is live on the App Store. `nil` otherwise.
    @Published var availableUpdate: AppUpdateInfo?

    /// Guards against re-prompting on every Home appearance (e.g. tab switches).
    /// The sheet should surface once per cold launch.
    private var didPromptThisSession = false

    private let bundleId: String
    private let installedVersion: String
    private let session: URLSession

    init(
        bundleId: String = Bundle.main.bundleIdentifier ?? "",
        installedVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        session: URLSession = .shared
    ) {
        self.bundleId = bundleId
        self.installedVersion = installedVersion
        self.session = session
    }

    /// Queries the App Store and publishes `availableUpdate` if a newer version
    /// exists. Runs at most once per app session.
    func checkForUpdate() async {
        guard !didPromptThisSession else { return }
        guard !bundleId.isEmpty, !installedVersion.isEmpty else { return }
        didPromptThisSession = true

        guard let lookup = await fetchLookup() else { return }
        guard isStoreVersionNewer(lookup.version) else { return }

        availableUpdate = AppUpdateInfo(version: lookup.version, appStoreURL: lookup.url)
    }

    // MARK: - Lookup

    private func fetchLookup() async -> (version: String, url: URL)? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "bundleId", value: bundleId)]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let result = response.results.first,
                  let storeURL = URL(string: result.trackViewUrl) else { return nil }
            return (result.version, storeURL)
        } catch {
            return nil
        }
    }

    /// Semantic, dot-separated comparison so e.g. `1.10.0` > `1.2.0` and
    /// `2.0` > `1.9.9`.
    private func isStoreVersionNewer(_ storeVersion: String) -> Bool {
        storeVersion.compare(installedVersion, options: .numeric) == .orderedDescending
    }

    private struct LookupResponse: Decodable {
        let results: [Result]
        struct Result: Decodable {
            let version: String
            let trackViewUrl: String
        }
    }
}

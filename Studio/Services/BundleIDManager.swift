import Foundation
import Combine

@MainActor
class BundleIDManager: ObservableObject {
    @Published var bundleID: String = ""
    @Published var isFetching: Bool = false

    private let bundleIDService = BundleIDService()
    private let preferences: PreferencesServiceProtocol

    init(preferences: PreferencesServiceProtocol) {
        self.preferences = preferences

        if let savedBundleID = preferences.lastBundleID {
            bundleID = savedBundleID
        }
    }

    convenience init() {
        self.init(preferences: PreferencesService())
    }

    /// Update the bundle ID, automatically detecting and fetching from App Store URLs
    func setBundleID(_ value: String) async {
        guard !isFetching else { return }

        if isAppStoreURL(value) {
            await fetchBundleIDFromURL(value)
        } else {
            bundleID = value
            preferences.lastBundleID = value
        }
    }

    /// Update bundle ID without triggering URL detection (for programmatic updates)
    func updateBundleID(_ value: String) {
        bundleID = value
        preferences.lastBundleID = value
    }

    // MARK: - Private Methods

    private func isAppStoreURL(_ urlString: String) -> Bool {
        urlString.contains("apps.apple.com") || urlString.contains("itunes.apple.com")
    }

    private func fetchBundleIDFromURL(_ urlString: String) async {
        isFetching = true
        defer { isFetching = false }

        do {
            let app = try await bundleIDService.getBundleID(from: urlString)
            bundleID = app.bundleId
            preferences.lastBundleID = app.bundleId
        } catch {
        }
    }
}

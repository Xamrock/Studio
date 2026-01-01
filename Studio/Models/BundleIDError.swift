import Foundation

enum BundleIDError: LocalizedError {
    case invalidURL
    case noAppIDFound
    case networkError(Error)
    case noResults
    case noBundleID
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid App Store URL. Please provide a valid URL."
        case .noAppIDFound:
            return "Could not find an app ID in the URL. Make sure the URL contains 'id' followed by numbers."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noResults:
            return "No app found for this ID. The app may not exist or may have been removed."
        case .noBundleID:
            return "Bundle ID not found in the response. This shouldn't happen!"
        case .invalidResponse:
            return "Invalid response from iTunes API."
        }
    }
}

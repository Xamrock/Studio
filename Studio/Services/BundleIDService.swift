import Foundation

actor BundleIDService {
    private let lookupURL = "https://itunes.apple.com/lookup"

    func extractAppID(from urlString: String) throws -> String {
        let decodedURL = urlString.removingPercentEncoding ?? urlString

        let pattern = #"id(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: decodedURL,
                range: NSRange(decodedURL.startIndex..., in: decodedURL)
              ),
              let range = Range(match.range(at: 1), in: decodedURL) else {
            throw BundleIDError.noAppIDFound
        }

        return String(decodedURL[range])
    }

    func fetchBundleID(appID: String) async throws -> AppStoreApp {
        var components = URLComponents(string: lookupURL)
        components?.queryItems = [URLQueryItem(name: "id", value: appID)]

        guard let url = components?.url else {
            throw BundleIDError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BundleIDError.invalidResponse
        }

        let iTunesResponse = try JSONDecoder().decode(iTunesResponse.self, from: data)

        guard let app = iTunesResponse.results.first else {
            throw BundleIDError.noResults
        }

        return app
    }

    func getBundleID(from urlString: String) async throws -> AppStoreApp {
        let appID = try extractAppID(from: urlString)
        return try await fetchBundleID(appID: appID)
    }
}

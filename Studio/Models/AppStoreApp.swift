import Foundation

struct iTunesResponse: Codable {
    let resultCount: Int
    let results: [AppStoreApp]
}

struct AppStoreApp: Codable, Identifiable {
    let trackId: Int
    let bundleId: String
    let trackName: String
    let artistName: String
    let artworkUrl100: String?
    let primaryGenreName: String?
    let averageUserRating: Double?
    let userRatingCount: Int?

    var id: Int { trackId }
}

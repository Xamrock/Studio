import Foundation

struct StudioSession: Codable {
    let version: String
    let exportDate: Date
    let bundleID: String
    let screens: [CapturedScreen]
    let edges: [NavigationEdge]
    let flowGroups: [FlowGroup]
}

class SessionPersistenceService {
    func save(
        bundleID: String,
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        flowGroups: [FlowGroup],
        to url: URL
    ) throws {
        let session = StudioSession(
            version: "1.0",
            exportDate: Date(),
            bundleID: bundleID,
            screens: screens,
            edges: edges,
            flowGroups: flowGroups
        )

        let encoder = createJSONEncoder()
        let data = try encoder.encode(session)
        try data.write(to: url)
    }

    func load(from url: URL) throws -> StudioSession {
        let data = try Data(contentsOf: url)

        let decoder = createJSONDecoder()
        let session = try decoder.decode(StudioSession.self, from: data)

        return session
    }

    // MARK: - Private Methods

    private func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

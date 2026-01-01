import Foundation

class CommunicationService {
    private let sessionID: UUID
    private let baseDirectory: URL
    private let serverURL: String

    init(sessionID: UUID = UUID(), deviceIP: String = "localhost") throws {
        let validatedIP = try Self.validateDeviceIP(deviceIP)

        self.sessionID = sessionID
        self.baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("studio_\(sessionID.uuidString)")
        self.serverURL = "http://\(validatedIP):8080"
    }

    private static func validateDeviceIP(_ ip: String) throws -> String {
        let trimmed = ip.trimmingCharacters(in: .whitespaces)

        if trimmed == "localhost" {
            return trimmed
        }

        let localPattern = "^[a-zA-Z0-9.-]+\\.local$"
        if trimmed.range(of: localPattern, options: .regularExpression) != nil {
            return trimmed
        }

        let ipPattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if trimmed.range(of: ipPattern, options: .regularExpression) != nil {
            return trimmed
        }

        throw CommunicationError.invalidDeviceIP(ip: ip)
    }

    func setup() throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func sendCommand(_ command: Command) async throws -> String? {
        try Task.checkCancellation()

        let endpoint: String
        var bodyData: Data?

        switch command {
        case .captureSnapshot:
            endpoint = "/capture"
        case .stop:
            endpoint = "/stop"
        case .tap, .doubleTap, .longPress, .swipe, .typeText, .tapCoordinate, .swipeCoordinate:
            endpoint = "/interact"
            let encoder = JSONEncoder()
            bodyData = try encoder.encode(command)
        }

        guard let url = URL(string: "\(serverURL)\(endpoint)") else {
            throw CommunicationError.invalidURL(endpoint: endpoint)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10

        if let bodyData = bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("\(bodyData.count)", forHTTPHeaderField: "Content-Length")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        try Task.checkCancellation()

        if let body = String(data: data, encoding: .utf8) {
            return body
        }

        return nil
    }

    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(serverURL)/health") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
        }

        return false
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }

    var basePath: String {
        baseDirectory.path
    }
}

enum CommunicationError: Error, LocalizedError {
    case invalidDeviceIP(ip: String)
    case invalidURL(endpoint: String)

    var errorDescription: String? {
        switch self {
        case .invalidDeviceIP(let ip):
            return "Invalid device IP address: '\(ip)'. Must be localhost, an IP address, or a .local domain."
        case .invalidURL(let endpoint):
            return "Failed to construct URL for endpoint: '\(endpoint)'"
        }
    }
}

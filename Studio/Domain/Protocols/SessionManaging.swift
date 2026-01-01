import Foundation

struct SessionConfiguration {
    let bundleID: String
    let deviceID: String
    let skipAppLaunch: Bool
}

protocol SessionManaging {
    var isRunning: Bool { get }
    func startSession(configuration: SessionConfiguration) async throws
    func stopSession()
    func captureSnapshot() async throws -> HierarchySnapshot
}

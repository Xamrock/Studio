import Foundation

protocol SnapshotCapturing {
    func captureSnapshot(name: String) async throws -> CapturedScreen
}

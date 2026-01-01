import Foundation
import AppKit
import Combine

@MainActor
class SnapshotCapturingService: ObservableObject, SnapshotCapturing {
    @Published var isCapturing = false
    @Published var errorMessage: String?

    private let sessionCoordinator: SessionCoordinator

    init(sessionCoordinator: SessionCoordinator) {
        self.sessionCoordinator = sessionCoordinator
    }

    func captureSnapshot(name: String) async throws -> CapturedScreen {
        guard !isCapturing else {
            throw SnapshotError.alreadyCapturing
        }

        guard sessionCoordinator.hasActiveSession else {
            throw SnapshotError.noActiveSession
        }

        isCapturing = true
        errorMessage = nil

        defer { isCapturing = false }

        do {
            let snapshot = try await sessionCoordinator.captureSnapshot()

            var screenshotImage: NSImage?
            if let base64Screenshot = snapshot.screenshot,
               let imageData = Data(base64Encoded: base64Screenshot) {
                screenshotImage = NSImage(data: imageData)
            }

            let screen = CapturedScreen(
                timestamp: Date(),
                name: name,
                snapshot: snapshot,
                screenshot: screenshotImage
            )

            return screen
        } catch {
            errorMessage = "Failed to capture: \(error.localizedDescription)"
            throw error
        }
    }
}

enum SnapshotError: Error, LocalizedError {
    case alreadyCapturing
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "Already capturing a snapshot"
        case .noActiveSession:
            return "No active session to capture from"
        }
    }
}

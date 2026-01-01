import Foundation
import Combine

@MainActor
class SessionCoordinator: ObservableObject {
    @Published var isRecording = false
    @Published var isTestRunning = false
    @Published var errorMessage: String?

    private var testRunner: TestRunnerService?
    private var communicationService: CommunicationService?
    private(set) var interactionService: InteractionService?

    func startSession(
        bundleID: String,
        device: Device,
        skipAppLaunch: Bool
    ) async throws {
        guard !bundleID.isEmpty else {
            errorMessage = "Please enter a bundle ID"
            throw SessionError.invalidBundleID
        }

        errorMessage = nil
        isRecording = true

        do {
            let deviceIP = device.isPhysical ? "iPhone.local" : "localhost"

            let commService = try CommunicationService(deviceIP: deviceIP)
            communicationService = commService
            interactionService = InteractionService(communicationService: commService)

            let runner = TestRunnerService(communicationService: commService)
            testRunner = runner

            try await runner.startSession(
                bundleID: bundleID,
                deviceID: device.id,
                skipAppLaunch: skipAppLaunch
            )

            try await Task.sleep(nanoseconds: 8_000_000_000)

            if let healthy = await communicationService?.checkHealth(), healthy {
                isTestRunning = true
            } else {
                throw SessionError.connectionFailed
            }
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            isRecording = false
            isTestRunning = false
            throw error
        }
    }

    func stopSession() async {
        await testRunner?.stopSession()
        testRunner = nil
        communicationService = nil
        interactionService = nil
        isRecording = false
        isTestRunning = false
    }

    func captureSnapshot() async throws -> HierarchySnapshot {
        guard let testRunner = testRunner else {
            throw SessionError.sessionNotStarted
        }
        return try await testRunner.captureSnapshot()
    }

    var hasActiveSession: Bool {
        testRunner != nil && isTestRunning
    }
}

enum SessionError: Error, LocalizedError {
    case invalidBundleID
    case connectionFailed
    case sessionNotStarted

    var errorDescription: String? {
        switch self {
        case .invalidBundleID:
            return "Please enter a bundle ID"
        case .connectionFailed:
            return "Failed to connect to test session"
        case .sessionNotStarted:
            return "Session not started"
        }
    }
}

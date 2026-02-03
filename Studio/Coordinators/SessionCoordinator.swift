import Foundation
import Combine

@MainActor
class SessionCoordinator: ObservableObject {
    @Published var isRecording = false
    @Published var isTestRunning = false
    @Published var errorMessage: String?
    @Published var connectionStatus: String?

    private var testRunner: TestRunnerService?
    private var androidTestRunner: AndroidTestRunnerService?
    private var communicationService: CommunicationService?
    private(set) var interactionService: InteractionService?
    private var currentPlatform: DevicePlatform?
    private let deviceConnectionService = DeviceConnectionService()

    func startSession(
        bundleID: String,
        device: Device,
        skipAppLaunch: Bool
    ) async throws {
        guard !bundleID.isEmpty else {
            errorMessage = "Please enter a \(device.platform == .ios ? "bundle ID" : "package name")"
            throw SessionError.invalidBundleID
        }

        errorMessage = nil
        isRecording = true
        currentPlatform = device.platform

        do {
            switch device.platform {
            case .ios:
                try await startIOSSession(bundleID: bundleID, device: device, skipAppLaunch: skipAppLaunch)
            case .android:
                try await startAndroidSession(packageName: bundleID, device: device, skipAppLaunch: skipAppLaunch)
            }

            isTestRunning = true
            connectionStatus = nil
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            isRecording = false
            isTestRunning = false
            throw error
        }
    }

    private func startIOSSession(
        bundleID: String,
        device: Device,
        skipAppLaunch: Bool
    ) async throws {
        let deviceIP: String
        
        if device.isPhysical {
            // Use DeviceConnectionService for physical devices
            connectionStatus = "Detecting device connection type..."
            
            do {
                let connectionInfo = try await deviceConnectionService.getConnectionInfo(for: device)
                
                switch connectionInfo.connectionType {
                case .usb:
                    connectionStatus = "Setting up USB connection..."
                case .wifi:
                    connectionStatus = "Connecting via WiFi..."
                case .simulator:
                    break
                }
                
                deviceIP = try await deviceConnectionService.getConnectionAddress(for: connectionInfo)
            } catch {
                // Provide helpful error message based on connection failure
                throw SessionError.deviceConnectionFailed(
                    deviceName: device.name,
                    underlyingError: error
                )
            }
        } else {
            deviceIP = "localhost"
        }

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

        // Wait for server to become ready with polling and exponential backoff
        try await waitForServerHealth(deviceType: device.isPhysical ? "physical device" : "simulator")
    }

    private func startAndroidSession(
        packageName: String,
        device: Device,
        skipAppLaunch: Bool
    ) async throws {
        // Android always uses localhost with port forwarding
        let commService = try CommunicationService(deviceIP: "localhost")
        communicationService = commService
        interactionService = InteractionService(communicationService: commService)

        let runner = AndroidTestRunnerService(communicationService: commService)
        androidTestRunner = runner

        try await runner.startSession(
            packageName: packageName,
            deviceID: device.id,
            skipAppLaunch: skipAppLaunch
        )

        // Wait for server to become ready
        try await waitForServerHealth(deviceType: device.isPhysical ? "physical device" : "emulator")
    }

    private func waitForServerHealth(deviceType: String) async throws {
        let maxAttempts = 30  // 30 attempts over ~60 seconds
        var attempt = 0
        var isHealthy = false

        connectionStatus = "Waiting for test server to start..."

        while attempt < maxAttempts && !isHealthy {
            attempt += 1

            // Calculate delay: start at 1s, cap at 3s
            let baseDelay = min(1.0 + Double(attempt - 1) * 0.1, 3.0)
            let delayNanoseconds = UInt64(baseDelay * 1_000_000_000)

            try await Task.sleep(nanoseconds: delayNanoseconds)

            connectionStatus = "Attempting to connect... (\(attempt)/\(maxAttempts))"

            if let healthy = await communicationService?.checkHealth(), healthy {
                isHealthy = true
                connectionStatus = "Connected!"
                break
            }

            try Task.checkCancellation()
        }

        guard isHealthy else {
            throw SessionError.connectionFailed(
                deviceType: deviceType,
                attempts: attempt
            )
        }
    }

    func stopSession() async {
        if let platform = currentPlatform {
            switch platform {
            case .ios:
                await testRunner?.stopSession()
                testRunner = nil
                deviceConnectionService.disconnect()
            case .android:
                await androidTestRunner?.stopSession()
                androidTestRunner = nil
            }
        }

        communicationService = nil
        interactionService = nil
        isRecording = false
        isTestRunning = false
        currentPlatform = nil
    }

    func captureSnapshot() async throws -> HierarchySnapshot {
        if let testRunner = testRunner {
            return try await testRunner.captureSnapshot()
        } else if let androidTestRunner = androidTestRunner {
            return try await androidTestRunner.captureSnapshot()
        } else {
            throw SessionError.sessionNotStarted
        }
    }

    var hasActiveSession: Bool {
        (testRunner != nil || androidTestRunner != nil) && isTestRunning
    }
}

enum SessionError: Error, LocalizedError {
    case invalidBundleID
    case connectionFailed(deviceType: String, attempts: Int)
    case sessionNotStarted
    case deviceConnectionFailed(deviceName: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .invalidBundleID:
            return "Please enter a bundle ID"
        case .connectionFailed(let deviceType, let attempts):
            var message = "Failed to connect to test server on \(deviceType) after \(attempts) attempts.\n\n"

            if deviceType.contains("physical") {
                message += "For physical devices:\n"
                message += "• For USB: Ensure the device is trusted and unlocked\n"
                message += "• For WiFi: Ensure device and Mac are on the same network\n"
                message += "• Make sure no firewall is blocking port 8080\n"
                message += "• Try disconnecting and reconnecting the device\n\n"
            } else {
                message += "For simulators:\n"
                message += "• Try resetting the simulator\n"
                message += "• Ensure no other process is using port 8080\n"
                message += "• Check that xcodebuild completed successfully\n\n"
            }

            message += "If the problem persists, try stopping and restarting the session."
            return message
        case .sessionNotStarted:
            return "Session not started"
        case .deviceConnectionFailed(let deviceName, let underlyingError):
            var message = "Failed to establish connection to \(deviceName).\n\n"
            message += "Error: \(underlyingError.localizedDescription)\n\n"
            message += "Troubleshooting:\n"
            message += "• For USB: Make sure the device is unlocked and trusted\n"
            message += "• For WiFi: Ensure device and Mac are on the same network\n"
            message += "• Try unplugging and replugging the USB cable\n"
            message += "• Restart the device if the issue persists"
            return message
        }
    }
}

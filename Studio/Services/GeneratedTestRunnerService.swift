import Foundation

/// Service for running generated tests on devices using the bundled test runner
class GeneratedTestRunnerService {
    private var process: Process?
    private var outputHandler: ((String) -> Void)?

    /// Runs the generated test commands on the specified device
    /// - Parameters:
    ///   - commands: JSON string of script commands
    ///   - device: The target device to run the test on
    ///   - bundleID: The bundle ID of the app being tested
    ///   - outputHandler: Closure called with output lines as they're received
    func runTest(commands: String, device: Device, bundleID: String, outputHandler: @escaping (String) -> Void) async throws {
        self.outputHandler = outputHandler

        outputHandler("Preparing test execution...\n")
        outputHandler("Target app: \(bundleID)\n")
        outputHandler("Device: \(device.displayName)\n\n")

        // Try to use bundled xctestrun first (for distributed app)
        // Fall back to building from source (for development)
        if let xctestrunPath = try? locateBundledXCTestRun(deviceID: device.id) {
            outputHandler("Using bundled test runner\n")
            try await runWithBundledRunner(
                xctestrunPath: xctestrunPath,
                commands: commands,
                device: device,
                bundleID: bundleID,
                outputHandler: outputHandler
            )
        } else {
            outputHandler("Bundled test runner not found, building from source...\n")
            try await runFromSource(
                commands: commands,
                device: device,
                bundleID: bundleID,
                outputHandler: outputHandler
            )
        }
    }

    /// Stops any running test process
    func stop() {
        if let process = process, process.isRunning {
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }
            process.terminate()
        }
        self.process = nil
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Run Methods

    private func runWithBundledRunner(
        xctestrunPath: String,
        commands: String,
        device: Device,
        bundleID: String,
        outputHandler: @escaping (String) -> Void
    ) async throws {
        if !device.isPhysical {
            try await ensureSimulatorBooted(deviceID: device.id, outputHandler: outputHandler)
        }

        let xcodebuildPath = "/usr/bin/xcodebuild"
        let arguments = [
            "test-without-building",
            "-xctestrun", xctestrunPath,
            "-destination", "id=\(device.id)",
            "-only-testing:TestHostUITests/XamrockScriptedUITest/testExecuteScript",
            "-parallel-testing-enabled", "NO"
        ]

        outputHandler("Running: xcodebuild \(arguments.joined(separator: " "))\n\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: xcodebuildPath)
        process.arguments = arguments

        // Pass commands via environment variables
        var environment = ProcessInfo.processInfo.environment
        environment["TEST_RUNNER_XAMROCK_BUNDLE_ID"] = bundleID
        environment["TEST_RUNNER_XAMROCK_COMMANDS"] = commands
        process.environment = environment

        try await runProcess(process, outputHandler: outputHandler)
    }

    private func runFromSource(
        commands: String,
        device: Device,
        bundleID: String,
        outputHandler: @escaping (String) -> Void
    ) async throws {
        let projectPath = try locateStudioProject()
        let projectDir = URL(fileURLWithPath: projectPath).deletingLastPathComponent()

        if !device.isPhysical {
            try await ensureSimulatorBooted(deviceID: device.id, outputHandler: outputHandler)
        }

        let xcodebuildPath = "/usr/bin/xcodebuild"
        let arguments = [
            "test",
            "-project", projectPath,
            "-scheme", "TestHost",
            "-destination", "id=\(device.id)",
            "-only-testing:TestHostUITests/XamrockScriptedUITest/testExecuteScript",
            "-parallel-testing-enabled", "NO"
        ]

        outputHandler("Running: xcodebuild \(arguments.joined(separator: " "))\n\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: xcodebuildPath)
        process.arguments = arguments
        process.currentDirectoryURL = projectDir

        // Pass commands via environment variables
        var environment = ProcessInfo.processInfo.environment
        environment["TEST_RUNNER_XAMROCK_BUNDLE_ID"] = bundleID
        environment["TEST_RUNNER_XAMROCK_COMMANDS"] = commands
        process.environment = environment

        try await runProcess(process, outputHandler: outputHandler)
    }

    private func runProcess(_ process: Process, outputHandler: @escaping (String) -> Void) async throws {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.outputHandler?(output)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.outputHandler?(output)
                }
            }
        }

        try process.run()
        self.process = process

        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        let exitStatus = process.terminationStatus
        if exitStatus == 0 {
            outputHandler("\n\nTest completed successfully!\n")
        } else {
            outputHandler("\n\nTest finished with exit code: \(exitStatus)\n")
        }

        self.process = nil
    }

    // MARK: - Helper Methods

    private func locateBundledXCTestRun(deviceID: String) throws -> String {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw GeneratedTestRunnerError.testRunnerNotBundled
        }

        let testRunnerDir = resourceURL.appendingPathComponent("TestRunner")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: testRunnerDir.path) else {
            throw GeneratedTestRunnerError.testRunnerNotBundled
        }

        let isSimulator = self.isSimulator(deviceID: deviceID)
        let platformDir = testRunnerDir.appendingPathComponent(isSimulator ? "Simulator" : "Device")

        guard fileManager.fileExists(atPath: platformDir.path) else {
            throw GeneratedTestRunnerError.testRunnerNotBundled
        }

        let contents = try fileManager.contentsOfDirectory(atPath: platformDir.path)
        guard let xctestrunFile = contents.first(where: { $0.hasSuffix(".xctestrun") }) else {
            throw GeneratedTestRunnerError.xctestrunNotFound
        }

        return platformDir.appendingPathComponent(xctestrunFile).path
    }

    private func isSimulator(deviceID: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "-j"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let devices = json["devices"] as? [String: [[String: Any]]] {
                for (_, deviceList) in devices {
                    for device in deviceList {
                        if let udid = device["udid"] as? String, udid == deviceID {
                            return true
                        }
                    }
                }
            }
        } catch {
        }

        return false
    }

    private func locateStudioProject() throws -> String {
        if let projectPath = Bundle.main.infoDictionary?["StudioProjectPath"] as? String {
            let fullPath = "\(projectPath)/Studio.xcodeproj"
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        var searchURL = URL(fileURLWithPath: Bundle.main.bundlePath)

        for _ in 0..<10 {
            searchURL = searchURL.deletingLastPathComponent()

            let projectPath = searchURL.appendingPathComponent("Studio.xcodeproj").path
            if FileManager.default.fileExists(atPath: projectPath) {
                return projectPath
            }

            if searchURL.path == "/" || searchURL.path.isEmpty {
                break
            }
        }

        throw GeneratedTestRunnerError.projectNotFound
    }

    private func ensureSimulatorBooted(deviceID: String, outputHandler: @escaping (String) -> Void) async throws {
        outputHandler("Checking simulator status...\n")

        let maxRetries = 30

        for attempt in 0..<maxRetries {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "list", "devices", "-j"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let devices = json["devices"] as? [String: [[String: Any]]] else {
                throw GeneratedTestRunnerError.simulatorNotFound
            }

            var currentState: String?

            for (_, deviceList) in devices {
                for device in deviceList {
                    if let udid = device["udid"] as? String, udid == deviceID {
                        currentState = device["state"] as? String
                        break
                    }
                }
            }

            guard let state = currentState else {
                throw GeneratedTestRunnerError.simulatorNotFound
            }

            if state == "Booted" {
                outputHandler("Simulator is booted and ready.\n")
                return
            }

            if attempt == 0 && state == "Shutdown" {
                outputHandler("Booting simulator...\n")
                let bootProcess = Process()
                bootProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                bootProcess.arguments = ["simctl", "boot", deviceID]
                bootProcess.standardOutput = Pipe()
                bootProcess.standardError = Pipe()

                try? bootProcess.run()
                bootProcess.waitUntilExit()
            }

            if state == "Booting" || state == "Shutdown" {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
        }

        throw GeneratedTestRunnerError.simulatorBootTimeout
    }
}

enum GeneratedTestRunnerError: Error, LocalizedError {
    case projectNotFound
    case testRunnerNotBundled
    case xctestrunNotFound
    case simulatorNotFound
    case simulatorBootTimeout

    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "Could not locate Studio.xcodeproj. Running from source requires the development environment."
        case .testRunnerNotBundled:
            return "Test runner not found in app bundle."
        case .xctestrunNotFound:
            return "Test configuration (.xctestrun) not found in bundle."
        case .simulatorNotFound:
            return "Simulator not found. Please select a valid simulator."
        case .simulatorBootTimeout:
            return "Simulator took too long to boot. Please try again."
        }
    }
}

import Foundation

class TestRunnerService {
    private var process: Process?
    private let communicationService: CommunicationService
    private var startupTask: Task<Void, Error>?

    init(communicationService: CommunicationService) {
        self.communicationService = communicationService
    }

    func startSession(bundleID: String, deviceID: String, skipAppLaunch: Bool = false) async throws {
        try communicationService.setup()

        if isSimulator(deviceID: deviceID) {
            try await ensureSimulatorBooted(deviceID: deviceID)
        }

        let xcodebuildPath = "/usr/bin/xcodebuild"
        let arguments: [String]

        if let xctestrunPath = try? locateBundledXCTestRun(deviceID: deviceID) {
            arguments = [
                "test-without-building",
                "-xctestrun", xctestrunPath,
                "-destination", "id=\(deviceID)",
                "-only-testing:TestHostUITests/StudioRecorderUITest/testRecordingSession",
                "-parallel-testing-enabled", "NO"
            ]
        } else {
            let projectPath = try locateStudioProject()
            arguments = [
                "test",
                "-project", projectPath,
                "-scheme", "TestHost",
                "-destination", "id=\(deviceID)",
                "-only-testing:TestHostUITests/StudioRecorderUITest/testRecordingSession",
                "-parallel-testing-enabled", "NO"
            ]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: xcodebuildPath)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["TEST_RUNNER_PROMETHEUS_BUNDLE_ID"] = bundleID
        environment["TEST_RUNNER_PROMETHEUS_COMMUNICATION_PATH"] = communicationService.basePath
        environment["TEST_RUNNER_PROMETHEUS_SKIP_APP_LAUNCH"] = skipAppLaunch ? "true" : "false"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
        }

        try process.run()
        self.process = process

        try await Task.sleep(nanoseconds: 5_000_000_000)

        try Task.checkCancellation()
    }

    func captureSnapshot() async throws -> HierarchySnapshot {
        guard let jsonString = try await communicationService.sendCommand(.captureSnapshot),
              let jsonData = jsonString.data(using: .utf8) else {
            throw TestRunnerError.noSnapshotData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HierarchySnapshot.self, from: jsonData)
    }

    func stopSession() async {
        startupTask?.cancel()
        startupTask = nil

        do {
            try await communicationService.sendCommand(.stop)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch is CancellationError {
        } catch {
        }

        if let process = process, process.isRunning {
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }

            process.terminate()
        }

        communicationService.cleanup()

        self.process = nil
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    private func locateBundledXCTestRun(deviceID: String) throws -> String {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw TestRunnerError.testRunnerNotBundled
        }

        let testRunnerDir = resourceURL.appendingPathComponent("TestRunner")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: testRunnerDir.path) else {
            throw TestRunnerError.testRunnerNotBundled
        }

        let isSimulator = self.isSimulator(deviceID: deviceID)
        let platformDir = testRunnerDir.appendingPathComponent(isSimulator ? "Simulator" : "Device")

        guard fileManager.fileExists(atPath: platformDir.path) else {
            throw TestRunnerError.testRunnerNotBundled
        }

        let contents = try fileManager.contentsOfDirectory(atPath: platformDir.path)
        guard let xctestrunFile = contents.first(where: { $0.hasSuffix(".xctestrun") }) else {
            throw TestRunnerError.xctestrunNotFound
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

    private func ensureSimulatorBooted(deviceID: String) async throws {
        try await shutdownCloneSimulators()

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
                throw TestRunnerError.simulatorNotFound
            }

            var currentState: String?
            var deviceName: String?

            for (_, deviceList) in devices {
                for device in deviceList {
                    if let udid = device["udid"] as? String, udid == deviceID {
                        currentState = device["state"] as? String
                        deviceName = device["name"] as? String
                        break
                    }
                }
            }

            guard let state = currentState else {
                throw TestRunnerError.simulatorNotFound
            }

            if state == "Booted" {
                let bootStatusProcess = Process()
                bootStatusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                bootStatusProcess.arguments = ["simctl", "bootstatus", deviceID]
                bootStatusProcess.standardOutput = Pipe()
                bootStatusProcess.standardError = Pipe()

                do {
                    try bootStatusProcess.run()
                    bootStatusProcess.waitUntilExit()

                    if bootStatusProcess.terminationStatus == 0 {
                        return
                    }
                } catch {
                }

                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            }

            if attempt == 0 && state == "Shutdown" {
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                openProcess.arguments = ["-a", "Simulator", "--args", "-CurrentDeviceUDID", deviceID]
                openProcess.standardOutput = Pipe()
                openProcess.standardError = Pipe()

                do {
                    try openProcess.run()
                    openProcess.waitUntilExit()
                } catch {
                }
            }

            if state == "Booting" || state == "Shutdown" {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }

            throw TestRunnerError.simulatorInBadState(state: state)
        }

        throw TestRunnerError.simulatorBootTimeout
    }

    private func shutdownCloneSimulators() async throws {
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
            return
        }

        for (_, deviceList) in devices {
            for device in deviceList {
                if let name = device["name"] as? String,
                   let udid = device["udid"] as? String,
                   let state = device["state"] as? String,
                   name.contains("Clone") && state == "Booted" {
                    let shutdownProcess = Process()
                    shutdownProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                    shutdownProcess.arguments = ["simctl", "shutdown", udid]
                    shutdownProcess.standardOutput = Pipe()
                    shutdownProcess.standardError = Pipe()

                    try? shutdownProcess.run()
                    shutdownProcess.waitUntilExit()
                }
            }
        }
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

        throw TestRunnerError.projectNotFound
    }
}

enum TestRunnerError: Error, LocalizedError {
    case testRunnerNotBundled
    case xctestrunNotFound
    case projectNotFound
    case simulatorNotFound
    case simulatorBootTimeout
    case simulatorInBadState(state: String)
    case noSnapshotData

    var errorDescription: String? {
        switch self {
        case .testRunnerNotBundled:
            return "Test runner not found in app bundle."
        case .xctestrunNotFound:
            return "Test configuration (.xctestrun) not found."
        case .projectNotFound:
            return "Could not locate Studio.xcodeproj. Please run from the project directory or use a bundled release."
        case .simulatorNotFound:
            return "Simulator not found. Please select a valid simulator."
        case .simulatorBootTimeout:
            return "Simulator took too long to boot. Please try again or select a different simulator."
        case .simulatorInBadState(let state):
            return "Simulator is in an unexpected state: \(state). Please reset the simulator and try again."
        case .noSnapshotData:
            return "Failed to capture UI hierarchy snapshot"
        }
    }
}

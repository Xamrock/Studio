import Foundation

class AndroidTestRunnerService {
    private var adbProcess: Process?
    private var instrumentationProcess: Process?
    private let communicationService: CommunicationService

    init(communicationService: CommunicationService) {
        self.communicationService = communicationService
    }

    func startSession(packageName: String, deviceID: String, skipAppLaunch: Bool = false) async throws {
        try communicationService.setup()

        // Kill any existing test processes to ensure clean start
        try await killExistingTestProcess(deviceID: deviceID)

        // Install test APK if not already installed
        try await installTestAPKIfNeeded(deviceID: deviceID)

        // Set up port forwarding
        try await setupPortForwarding(deviceID: deviceID)

        // Launch instrumentation test
        try await launchInstrumentationTest(
            packageName: packageName,
            deviceID: deviceID,
            skipAppLaunch: skipAppLaunch
        )

        // Wait for server to start
        try await Task.sleep(nanoseconds: 3_000_000_000)
    }

    func captureSnapshot() async throws -> HierarchySnapshot {
        guard let jsonString = try await communicationService.sendCommand(.captureSnapshot),
              let jsonData = jsonString.data(using: .utf8) else {
            throw AndroidTestRunnerError.noSnapshotData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HierarchySnapshot.self, from: jsonData)
    }

    func stopSession() async {
        do {
            try await communicationService.sendCommand(.stop)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            // Ignore errors when stopping
        }

        // Kill instrumentation process
        if let process = instrumentationProcess, process.isRunning {
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }
            process.terminate()
        }

        // Remove port forwarding
        if let adbProcess = adbProcess, adbProcess.isRunning {
            adbProcess.terminate()
        }

        communicationService.cleanup()

        self.instrumentationProcess = nil
        self.adbProcess = nil
    }

    var isRunning: Bool {
        instrumentationProcess?.isRunning ?? false
    }

    // MARK: - Private Methods

    private func killExistingTestProcess(deviceID: String) async throws {
        // Force stop the test host app to kill any running instrumentation tests
        let process = Process()
        process.executableURL = try getAdbPath()
        process.arguments = ["-s", deviceID, "shell", "am", "force-stop", "com.xamrock.testhost"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // Give it a moment to clean up
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func installTestAPKIfNeeded(deviceID: String) async throws {
        // Check if test app is already installed
        if try await isTestAppInstalled(deviceID: deviceID) {
            return
        }

        // Try to find bundled APK
        guard let apkPath = try? locateBundledTestAPK() else {
            throw AndroidTestRunnerError.testAPKNotFound
        }

        // Install APK
        try await installAPK(apkPath: apkPath, deviceID: deviceID)
    }

    private func isTestAppInstalled(deviceID: String) async throws -> Bool {
        let process = Process()
        process.executableURL = try getAdbPath()
        process.arguments = ["-s", deviceID, "shell", "pm", "list", "packages", "com.xamrock.testhost"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.contains("com.xamrock.testhost")
        }

        return false
    }

    private func locateBundledTestAPK() throws -> String {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw AndroidTestRunnerError.testAPKNotFound
        }

        let testAPKDir = resourceURL.appendingPathComponent("AndroidTestHost")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: testAPKDir.path) else {
            throw AndroidTestRunnerError.testAPKNotFound
        }

        // Look for app-debug.apk and app-debug-androidTest.apk
        let appAPK = testAPKDir.appendingPathComponent("app-debug.apk")
        let testAPK = testAPKDir.appendingPathComponent("app-debug-androidTest.apk")

        if fileManager.fileExists(atPath: appAPK.path) && fileManager.fileExists(atPath: testAPK.path) {
            return testAPKDir.path
        }

        throw AndroidTestRunnerError.testAPKNotFound
    }

    private func installAPK(apkPath: String, deviceID: String) async throws {
        // Install main app APK
        let appAPK = "\(apkPath)/app-debug.apk"
        try await runAdbCommand(["-s", deviceID, "install", "-r", appAPK])

        // Install test APK
        let testAPK = "\(apkPath)/app-debug-androidTest.apk"
        try await runAdbCommand(["-s", deviceID, "install", "-r", testAPK])
    }

    private func setupPortForwarding(deviceID: String) async throws {
        let process = Process()
        process.executableURL = try getAdbPath()
        process.arguments = ["-s", deviceID, "forward", "tcp:8080", "tcp:8080"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw AndroidTestRunnerError.portForwardingFailed
        }

        self.adbProcess = process
    }

    private func launchInstrumentationTest(
        packageName: String,
        deviceID: String,
        skipAppLaunch: Bool
    ) async throws {
        let process = Process()
        process.executableURL = try getAdbPath()

        var arguments = [
            "-s", deviceID,
            "shell", "am", "instrument",
            "-w",
            "-e", "targetPackage", packageName,
            "-e", "class", "com.xamrock.testhost.StudioRecorderInstrumentationTest#testRecordingSession"
        ]

        if skipAppLaunch {
            arguments.append(contentsOf: ["-e", "skipAppLaunch", "true"])
        }

        arguments.append("com.xamrock.testhost.test/androidx.test.runner.AndroidJUnitRunner")

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            // Log output if needed
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            // Log errors if needed
        }

        try process.run()
        self.instrumentationProcess = process
    }

    private func runAdbCommand(_ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = try getAdbPath()
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AndroidTestRunnerError.adbCommandFailed(message: errorMessage)
        }
    }

    private func getAdbPath() throws -> URL {
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // Try to find adb in PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["adb"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            // Fall through
        }

        throw AndroidTestRunnerError.adbNotFound
    }
}

enum AndroidTestRunnerError: Error, LocalizedError {
    case adbNotFound
    case testAPKNotFound
    case portForwardingFailed
    case adbCommandFailed(message: String)
    case noSnapshotData

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "Android Debug Bridge (adb) not found. Please install Android SDK Platform Tools."
        case .testAPKNotFound:
            return "Android test APK not found in app bundle. Please build the Android test host project."
        case .portForwardingFailed:
            return "Failed to set up port forwarding to Android device."
        case .adbCommandFailed(let message):
            return "ADB command failed: \(message)"
        case .noSnapshotData:
            return "Failed to capture UI hierarchy snapshot from Android device"
        }
    }
}

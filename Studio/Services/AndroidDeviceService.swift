import Foundation

class AndroidDeviceService: DeviceService {
    func fetchDevices() async throws -> [Device] {
        async let emulators = fetchAndroidEmulators()
        async let physicalDevices = fetchPhysicalDevices()

        var allDevices = try await emulators + physicalDevices

        // Sort: physical devices first, then by name
        allDevices.sort { lhs, rhs in
            if lhs.isPhysical != rhs.isPhysical {
                return lhs.isPhysical
            }
            return lhs.name < rhs.name
        }

        return allDevices
    }

    private func fetchAndroidEmulators() async throws -> [Device] {
        let devices = try await fetchAllAdbDevices()
        return devices.filter { !$0.isPhysical }
    }

    private func fetchPhysicalDevices() async throws -> [Device] {
        let devices = try await fetchAllAdbDevices()
        return devices.filter { $0.isPhysical }
    }

    private func fetchAllAdbDevices() async throws -> [Device] {
        let adbPath = try getAdbPath()

        let process = Process()
        process.executableURL = adbPath
        process.arguments = ["devices", "-l"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw AndroidDeviceServiceError.invalidResponse
        }

        return parseAdbDevicesOutput(output)
    }

    private func parseAdbDevicesOutput(_ output: String) -> [Device] {
        var devices: [Device] = []
        let lines = output.components(separatedBy: .newlines)

        for (_, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip header line and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("List of devices") {
                continue
            }

            // Parse line format: "serial_number    state    product:xxx model:xxx device:xxx transport_id:xxx"
            let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 2 else {
                continue
            }

            let serialNumber = components[0]
            let state = components[1]

            // Only include devices that are available
            guard state == "device" else {
                continue
            }

            // Extract additional info from the line
            var model = serialNumber
            var product = ""
            var isPhysical = true

            // Parse additional device info
            let infoString = trimmedLine
            if let modelRange = infoString.range(of: "model:") {
                let afterModel = infoString[modelRange.upperBound...]
                if let spaceIndex = afterModel.firstIndex(of: " ") {
                    model = String(afterModel[..<spaceIndex])
                } else {
                    model = String(afterModel)
                }
            }

            if let productRange = infoString.range(of: "product:") {
                let afterProduct = infoString[productRange.upperBound...]
                if let spaceIndex = afterProduct.firstIndex(of: " ") {
                    product = String(afterProduct[..<spaceIndex])
                } else {
                    product = String(afterProduct)
                }
            }

            // Determine if emulator or physical device
            if serialNumber.hasPrefix("emulator-") {
                isPhysical = false
            }

            // Get Android version
            let runtime = getAndroidVersion(for: serialNumber)

            let deviceName = isPhysical ? model : "Android Emulator \(serialNumber)"

            let device = Device(
                id: serialNumber,
                name: deviceName,
                runtime: runtime,
                state: "Online",
                isAvailable: true,
                isPhysical: isPhysical,
                platform: .android
            )
            devices.append(device)
        }

        return devices
    }

    private func getAndroidVersion(for serialNumber: String) -> String {
        guard let adbPath = try? getAdbPath() else {
            return "Android"
        }

        let process = Process()
        process.executableURL = adbPath
        process.arguments = ["-s", serialNumber, "shell", "getprop", "ro.build.version.release"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !version.isEmpty {
                return "Android \(version)"
            }
        } catch {
            // Fall back to unknown version
        }

        return "Android"
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
            // Fall through to throw error
        }

        throw AndroidDeviceServiceError.adbNotFound
    }

    func findDefaultDevice() async throws -> Device? {
        let devices = try await fetchDevices()

        // Prefer physical devices
        if let physicalDevice = devices.first(where: { $0.isPhysical && $0.isAvailable }) {
            return physicalDevice
        }

        // Fall back to any available emulator
        return devices.first(where: { $0.isAvailable })
    }
}

enum AndroidDeviceServiceError: Error, LocalizedError {
    case adbNotFound
    case invalidResponse
    case noDevicesFound

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "Android Debug Bridge (adb) not found. Please install Android SDK Platform Tools."
        case .invalidResponse:
            return "Failed to parse adb devices output"
        case .noDevicesFound:
            return "No Android devices or emulators found"
        }
    }
}

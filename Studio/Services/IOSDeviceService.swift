import Foundation

class IOSDeviceService: DeviceService {
    func fetchDevices() async throws -> [Device] {
        async let simulators = fetchIOSSimulators()
        async let physicalDevices = fetchPhysicalDevices()

        var allDevices = try await simulators + physicalDevices

        allDevices.sort { lhs, rhs in
            if lhs.isPhysical != rhs.isPhysical {
                return lhs.isPhysical
            }
            if lhs.runtime != rhs.runtime {
                return lhs.runtime > rhs.runtime
            }
            return lhs.name < rhs.name
        }

        return allDevices
    }

    private func fetchIOSSimulators() async throws -> [Device] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "iOS", "--json"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            throw DeviceServiceError.invalidResponse
        }

        var simulators: [Device] = []

        for (runtime, deviceList) in devices {
            guard runtime.contains("iOS") else { continue }

            let runtimeName = parseRuntimeName(runtime)

            for device in deviceList {
                guard let name = device["name"] as? String,
                      let udid = device["udid"] as? String,
                      let state = device["state"] as? String,
                      let isAvailable = device["isAvailable"] as? Bool else {
                    continue
                }

                if name.contains("Clone") {
                    continue
                }

                simulators.append(Device(
                    id: udid,
                    name: name,
                    runtime: runtimeName,
                    state: state,
                    isAvailable: isAvailable,
                    isPhysical: false
                ))
            }
        }

        return simulators
    }

    private func fetchPhysicalDevices() async throws -> [Device] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xctrace", "list", "devices"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        var devices: [Device] = []
        var inDevicesSection = false

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "== Devices ==" {
                inDevicesSection = true
                continue
            } else if trimmedLine.hasPrefix("==") {
                inDevicesSection = false
                continue
            }

            guard inDevicesSection else { continue }
            guard !trimmedLine.isEmpty else { continue }

            let pattern = #"^(.+?)\s+\((.+?)\)\s+\(([A-F0-9a-f-]+)\)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) else {
                continue
            }

            guard let nameRange = Range(match.range(at: 1), in: trimmedLine),
                  let versionRange = Range(match.range(at: 2), in: trimmedLine),
                  let udidRange = Range(match.range(at: 3), in: trimmedLine) else {
                continue
            }

            let name = String(trimmedLine[nameRange]).trimmingCharacters(in: .whitespaces)
            let version = String(trimmedLine[versionRange])
            let udid = String(trimmedLine[udidRange])

            if name.contains("Mac") || name.contains("MacBook") {
                continue
            }

            let device = Device(
                id: udid,
                name: name,
                runtime: "iOS \(version)",
                state: "Connected",
                isAvailable: true,
                isPhysical: true
            )
            devices.append(device)
        }

        return devices
    }

    func findDefaultDevice() async throws -> Device? {
        let devices = try await fetchDevices()

        if let physicalDevice = devices.first(where: { $0.isPhysical && $0.isAvailable }) {
            return physicalDevice
        }

        if let iphone17Pro = devices.first(where: {
            !$0.isPhysical &&
            $0.name.contains("iPhone 17 Pro") &&
            $0.runtime.contains("iOS 26") &&
            $0.isAvailable
        }) {
            return iphone17Pro
        }

        if let iphone17Pro = devices.first(where: {
            !$0.isPhysical &&
            $0.name.contains("iPhone 17 Pro") &&
            $0.isAvailable
        }) {
            return iphone17Pro
        }

        if let latestPro = devices.first(where: {
            !$0.isPhysical &&
            $0.name.contains("iPhone") &&
            $0.name.contains("Pro") &&
            $0.isAvailable
        }) {
            return latestPro
        }

        return devices.first(where: { $0.isAvailable })
    }

    private func parseRuntimeName(_ runtime: String) -> String {
        let components = runtime.components(separatedBy: ".")
        guard let lastComponent = components.last else {
            return runtime
        }

        let parts = lastComponent.components(separatedBy: "-")
        if parts.count >= 2 {
            let os = parts[0]
            let version = parts.dropFirst().joined(separator: ".")
            return "\(os) \(version)"
        }

        return lastComponent
    }
}

enum DeviceServiceError: Error {
    case invalidResponse
    case noDevicesFound
}

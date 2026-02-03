//
//  DeviceConnectionService.swift
//  Studio
//
//  Handles establishing connections to iOS devices via USB or WiFi.
//

import Foundation

/// Service for establishing connections to physical iOS devices.
/// Automatically detects USB vs WiFi connections and uses the appropriate method.
class DeviceConnectionService {
    
    enum ConnectionType {
        case usb
        case wifi
        case simulator
    }
    
    struct DeviceConnectionInfo {
        let deviceID: String
        let connectionType: ConnectionType
        let deviceName: String?
        let ipAddress: String?
    }
    
    private var usbMuxClient: USBMuxClient?
    
    /// Determines how a device is connected (USB, WiFi, or simulator)
    func getConnectionInfo(for device: Device) async throws -> DeviceConnectionInfo {
        guard device.isPhysical else {
            return DeviceConnectionInfo(
                deviceID: device.id,
                connectionType: .simulator,
                deviceName: device.name,
                ipAddress: nil
            )
        }
        
        // Use xcrun devicectl to get connection information
        let connectionType = try await detectConnectionType(deviceID: device.id)
        let deviceName = try await getDeviceName(deviceID: device.id)
        
        return DeviceConnectionInfo(
            deviceID: device.id,
            connectionType: connectionType,
            deviceName: deviceName,
            ipAddress: nil
        )
    }
    
    /// Gets the IP address to connect to for a device
    func getConnectionAddress(for connectionInfo: DeviceConnectionInfo) async throws -> String {
        switch connectionInfo.connectionType {
        case .simulator:
            return "localhost"
            
        case .usb:
            // Start USB port forwarding and connect via localhost
            try await setupUSBPortForwarding(deviceID: connectionInfo.deviceID)
            return "localhost"
            
        case .wifi:
            // Use device name for Bonjour resolution
            if let deviceName = connectionInfo.deviceName {
                let sanitizedName = sanitizeDeviceName(deviceName)
                return "\(sanitizedName).local"
            }
            throw DeviceConnectionError.deviceNameNotFound
        }
    }
    
    /// Sets up USB port forwarding via usbmuxd
    private func setupUSBPortForwarding(deviceID: String, localPort: UInt16 = 8080, remotePort: UInt16 = 8080) async throws {
        // Clean up any existing connection
        usbMuxClient?.disconnect()
        
        let client = USBMuxClient(deviceID: deviceID, localPort: localPort, remotePort: remotePort)
        usbMuxClient = client
        
        try await client.connect()
    }
    
    /// Detects whether a device is connected via USB or WiFi using xcrun devicectl
    private func detectConnectionType(deviceID: String) async throws -> ConnectionType {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["devicectl", "list", "devices", "--json-output", "/dev/stdout"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let devices = result["devices"] as? [[String: Any]] {
                
                for device in devices {
                    if let identifier = device["identifier"] as? String,
                       identifier == deviceID {
                        
                        // Check connection properties
                        if let connectionProperties = device["connectionProperties"] as? [String: Any] {
                            if let transportType = connectionProperties["transportType"] as? String {
                                if transportType.lowercased().contains("usb") {
                                    return .usb
                                } else if transportType.lowercased().contains("wifi") || 
                                          transportType.lowercased().contains("network") {
                                    return .wifi
                                }
                            }
                            
                            // Fallback: check for tunnel type
                            if let tunnelState = connectionProperties["tunnelState"] as? String {
                                if tunnelState.lowercased().contains("usb") {
                                    return .usb
                                }
                            }
                        }
                        
                        // Default to USB for physical devices if we can't determine
                        return .usb
                    }
                }
            }
        } catch {
            // If devicectl fails, fall back to checking via idevice_id
            return try await detectConnectionTypeFallback(deviceID: deviceID)
        }
        
        throw DeviceConnectionError.deviceNotFound(deviceID: deviceID)
    }
    
    /// Fallback detection using traditional methods
    private func detectConnectionTypeFallback(deviceID: String) async throws -> ConnectionType {
        // Check if device responds to USB query via system_profiler
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPUSBDataType", "-json"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let jsonString = String(data: data, encoding: .utf8),
           jsonString.contains(deviceID) || jsonString.lowercased().contains("iphone") || jsonString.lowercased().contains("ipad") {
            return .usb
        }
        
        // Assume WiFi if not found in USB
        return .wifi
    }
    
    /// Gets the device name using xcrun devicectl
    private func getDeviceName(deviceID: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["devicectl", "list", "devices", "--json-output", "/dev/stdout"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let devices = result["devices"] as? [[String: Any]] {
                
                for device in devices {
                    if let identifier = device["identifier"] as? String,
                       identifier == deviceID,
                       let deviceProperties = device["deviceProperties"] as? [String: Any],
                       let name = deviceProperties["name"] as? String {
                        return name
                    }
                }
            }
        } catch {
            // Fall back to simctl for the device name
            return try await getDeviceNameFallback(deviceID: deviceID)
        }
        
        throw DeviceConnectionError.deviceNameNotFound
    }
    
    /// Fallback to get device name via other methods
    private func getDeviceNameFallback(deviceID: String) async throws -> String {
        // Try using ideviceinfo if available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ideviceinfo")
        process.arguments = ["-u", deviceID, "-k", "DeviceName"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return name
            }
        } catch {
            // ideviceinfo not available
        }
        
        // Default fallback
        return "iPhone"
    }
    
    /// Sanitizes a device name for use in Bonjour/mDNS resolution
    private func sanitizeDeviceName(_ name: String) -> String {
        // Bonjour names replace special characters
        var sanitized = name
        
        // Replace apostrophes and special characters
        sanitized = sanitized.replacingOccurrences(of: "'", with: "")
        sanitized = sanitized.replacingOccurrences(of: "'", with: "")
        sanitized = sanitized.replacingOccurrences(of: " ", with: "-")
        
        // Remove any other non-alphanumeric characters except hyphens
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        sanitized = sanitized.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        
        return sanitized
    }
    
    /// Cleans up any active connections
    func disconnect() {
        usbMuxClient?.disconnect()
        usbMuxClient = nil
    }
}

enum DeviceConnectionError: Error, LocalizedError {
    case deviceNotFound(deviceID: String)
    case deviceNameNotFound
    case connectionFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let deviceID):
            return "Device not found: \(deviceID)"
        case .deviceNameNotFound:
            return "Could not determine device name"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}

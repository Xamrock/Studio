//
//  USBMuxClient.swift
//  Studio
//
//  Handles USB device communication via Apple's usbmuxd service.
//  This enables port forwarding to physical iOS devices connected via USB.
//

import Foundation
import Network

/// Client for communicating with Apple's usbmuxd service.
/// usbmuxd (USB Multiplexor Daemon) is a first-party Apple service that handles
/// iOS device communication over USB.
class USBMuxClient {
    private let socketPath = "/var/run/usbmuxd"
    private var connection: NWConnection?
    private var proxyListener: NWListener?
    private var deviceConnection: NWConnection?
    
    private let localPort: UInt16
    private let remotePort: UInt16
    private let deviceID: String
    
    private var isConnected = false
    
    init(deviceID: String, localPort: UInt16 = 8080, remotePort: UInt16 = 8080) {
        self.deviceID = deviceID
        self.localPort = localPort
        self.remotePort = remotePort
    }
    
    deinit {
        disconnect()
    }
    
    /// Starts port forwarding from localhost:localPort to device:remotePort
    func connect() async throws {
        // Create a local TCP listener that forwards to the device
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        proxyListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: localPort)!)
        
        proxyListener?.newConnectionHandler = { [weak self] incomingConnection in
            self?.handleIncomingConnection(incomingConnection)
        }
        
        proxyListener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
            case .failed(let error):
                print("Listener failed: \(error)")
                self?.isConnected = false
            default:
                break
            }
        }
        
        proxyListener?.start(queue: .global())
        
        // Wait for listener to be ready
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let timeout = DispatchTime.now() + .seconds(5)
            
            func checkReady() {
                if self.isConnected {
                    continuation.resume()
                } else if DispatchTime.now() >= timeout {
                    continuation.resume(throwing: USBMuxError.connectionTimeout)
                } else {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                        checkReady()
                    }
                }
            }
            
            checkReady()
        }
    }
    
    private func handleIncomingConnection(_ incomingConnection: NWConnection) {
        // Connect to usbmuxd and request connection to device
        let endpoint = NWEndpoint.unix(path: socketPath)
        let parameters = NWParameters()
        
        let muxConnection = NWConnection(to: endpoint, using: parameters)
        
        muxConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                // Send connect request to usbmuxd
                self.sendConnectRequest(muxConnection: muxConnection, incomingConnection: incomingConnection)
            case .failed(let error):
                print("Mux connection failed: \(error)")
                incomingConnection.cancel()
            default:
                break
            }
        }
        
        muxConnection.start(queue: .global())
    }
    
    private func sendConnectRequest(muxConnection: NWConnection, incomingConnection: NWConnection) {
        // Build usbmuxd connect request (plist format)
        let request: [String: Any] = [
            "MessageType": "Connect",
            "DeviceID": getDeviceIDNumber(),
            "PortNumber": htons(remotePort)
        ]
        
        guard let plistData = try? PropertyListSerialization.data(fromPropertyList: request, format: .binary, options: 0) else {
            incomingConnection.cancel()
            muxConnection.cancel()
            return
        }
        
        // usbmuxd protocol: 4-byte length + 4-byte version + 4-byte message type + 4-byte tag + payload
        var header = Data(count: 16)
        let totalLength = UInt32(16 + plistData.count)
        
        header.replaceSubrange(0..<4, with: withUnsafeBytes(of: totalLength.littleEndian) { Data($0) })
        header.replaceSubrange(4..<8, with: withUnsafeBytes(of: UInt32(1).littleEndian) { Data($0) }) // version
        header.replaceSubrange(8..<12, with: withUnsafeBytes(of: UInt32(8).littleEndian) { Data($0) }) // plist message
        header.replaceSubrange(12..<16, with: withUnsafeBytes(of: UInt32(1).littleEndian) { Data($0) }) // tag
        
        let packet = header + plistData
        
        muxConnection.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("Failed to send connect request: \(error)")
                incomingConnection.cancel()
                muxConnection.cancel()
                return
            }
            
            // Wait for response
            self?.receiveConnectResponse(muxConnection: muxConnection, incomingConnection: incomingConnection)
        })
    }
    
    private func receiveConnectResponse(muxConnection: NWConnection, incomingConnection: NWConnection) {
        // Read response header
        muxConnection.receive(minimumIncompleteLength: 16, maximumLength: 1024) { [weak self] content, _, _, error in
            if let error = error {
                print("Failed to receive response: \(error)")
                incomingConnection.cancel()
                muxConnection.cancel()
                return
            }
            
            guard let data = content, data.count >= 16 else {
                incomingConnection.cancel()
                muxConnection.cancel()
                return
            }
            
            // Parse response - check if connection was successful
            // For now, assume success and start proxying
            self?.startProxying(muxConnection: muxConnection, incomingConnection: incomingConnection)
        }
    }
    
    private func startProxying(muxConnection: NWConnection, incomingConnection: NWConnection) {
        incomingConnection.start(queue: .global())
        
        // Forward data from incoming to mux
        func forwardIncomingToMux() {
            incomingConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                if let data = content, !data.isEmpty {
                    muxConnection.send(content: data, completion: .contentProcessed { _ in
                        if !isComplete {
                            forwardIncomingToMux()
                        }
                    })
                } else if isComplete || error != nil {
                    muxConnection.cancel()
                }
            }
        }
        
        // Forward data from mux to incoming
        func forwardMuxToIncoming() {
            muxConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                if let data = content, !data.isEmpty {
                    incomingConnection.send(content: data, completion: .contentProcessed { _ in
                        if !isComplete {
                            forwardMuxToIncoming()
                        }
                    })
                } else if isComplete || error != nil {
                    incomingConnection.cancel()
                }
            }
        }
        
        forwardIncomingToMux()
        forwardMuxToIncoming()
    }
    
    private func getDeviceIDNumber() -> Int {
        // usbmuxd uses numeric device IDs, we need to look this up
        // For now, try to extract from UDID or use a default lookup
        // This will be enhanced to query usbmuxd for the device list
        return 1 // Placeholder - will implement device lookup
    }
    
    private func htons(_ value: UInt16) -> UInt16 {
        return value.bigEndian
    }
    
    func disconnect() {
        proxyListener?.cancel()
        proxyListener = nil
        deviceConnection?.cancel()
        deviceConnection = nil
        connection?.cancel()
        connection = nil
        isConnected = false
    }
}

enum USBMuxError: Error, LocalizedError {
    case connectionTimeout
    case deviceNotFound
    case connectionRefused
    
    var errorDescription: String? {
        switch self {
        case .connectionTimeout:
            return "Timed out connecting to device via USB"
        case .deviceNotFound:
            return "Device not found in usbmuxd device list"
        case .connectionRefused:
            return "Device refused the connection"
        }
    }
}

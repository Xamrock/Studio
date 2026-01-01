import Foundation
import Combine

@MainActor
class DeviceManager: ObservableObject, DeviceManaging {
    @Published var availableDevices: [Device] = []
    @Published var selectedDevice: Device?
    @Published var isLoadingDevices = false
    @Published var errorMessage: String?

    private let deviceService: DeviceService

    init(deviceService: DeviceService = IOSDeviceService()) {
        self.deviceService = deviceService
    }

    func loadDevices() async throws -> [Device] {
        isLoadingDevices = true
        errorMessage = nil

        defer { isLoadingDevices = false }

        do {
            let allDevices = try await deviceService.fetchDevices()
            availableDevices = allDevices.filter { $0.isAvailable }

            if selectedDevice == nil {
                selectedDevice = try await findDefaultDevice()
            }

            return availableDevices
        } catch {
            errorMessage = "Failed to load devices: \(error.localizedDescription)"
            throw error
        }
    }

    func findDefaultDevice() async throws -> Device? {
        try await deviceService.findDefaultDevice()
    }
}

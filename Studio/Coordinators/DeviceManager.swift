import Foundation
import Combine

@MainActor
class DeviceManager: ObservableObject, DeviceManaging {
    @Published var availableDevices: [Device] = []
    @Published var selectedDevice: Device?
    @Published var isLoadingDevices = false
    @Published var errorMessage: String?

    private let iosDeviceService: DeviceService
    private let androidDeviceService: DeviceService

    init(
        iosDeviceService: DeviceService = IOSDeviceService(),
        androidDeviceService: DeviceService = AndroidDeviceService()
    ) {
        self.iosDeviceService = iosDeviceService
        self.androidDeviceService = androidDeviceService
    }

    func loadDevices() async throws -> [Device] {
        isLoadingDevices = true
        errorMessage = nil

        defer { isLoadingDevices = false }

        // Fetch devices from both platforms, handling errors individually
        var allDevices: [Device] = []

        // Try to fetch iOS devices
        do {
            let iosDevices = try await iosDeviceService.fetchDevices()
            allDevices.append(contentsOf: iosDevices)
        } catch {
            // Continue to try Android devices
        }

        // Try to fetch Android devices
        do {
            let androidDevices = try await androidDeviceService.fetchDevices()
            allDevices.append(contentsOf: androidDevices)
        } catch {
            // Continue with whatever devices we have
        }

        // Filter available devices
        availableDevices = allDevices.filter { $0.isAvailable }

        // Sort devices: physical first, then by platform (iOS, Android), then by name
        availableDevices.sort { lhs, rhs in
            if lhs.isPhysical != rhs.isPhysical {
                return lhs.isPhysical
            }
            if lhs.platform != rhs.platform {
                return lhs.platform == .ios
            }
            return lhs.name < rhs.name
        }

        if selectedDevice == nil {
            selectedDevice = try await findDefaultDevice()
        }

        return availableDevices
    }

    func findDefaultDevice() async throws -> Device? {
        // Prefer iOS physical device
        if let iosDevice = try await iosDeviceService.findDefaultDevice() {
            return iosDevice
        }

        // Fall back to Android device
        return try await androidDeviceService.findDefaultDevice()
    }
}

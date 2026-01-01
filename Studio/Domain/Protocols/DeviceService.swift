import Foundation

protocol DeviceService {
    func fetchDevices() async throws -> [Device]
    func findDefaultDevice() async throws -> Device?
}

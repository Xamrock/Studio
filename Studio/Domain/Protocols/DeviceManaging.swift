import Foundation

protocol DeviceManaging {
    func loadDevices() async throws -> [Device]
    func findDefaultDevice() async throws -> Device?
}

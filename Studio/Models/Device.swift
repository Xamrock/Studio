import Foundation

enum DevicePlatform: String, Codable {
    case ios = "ios"
    case android = "android"
}

struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let runtime: String
    let state: String
    let isAvailable: Bool
    let isPhysical: Bool
    let platform: DevicePlatform

    var displayName: String {
        let platformPrefix = platform == .android ? "📱" : "🍎"

        if isPhysical {
            return "\(platformPrefix) \(name) (Physical Device)"
        } else {
            return "\(platformPrefix) \(name) (\(runtime))"
        }
    }
}

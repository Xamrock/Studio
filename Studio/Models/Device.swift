import Foundation

struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let runtime: String
    let state: String
    let isAvailable: Bool
    let isPhysical: Bool

    var displayName: String {
        if isPhysical {
            return "\(name) (Physical Device)"
        } else {
            return "\(name) (\(runtime))"
        }
    }
}

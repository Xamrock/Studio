import SwiftUI

struct FlowGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: FlowColor
    var collapsed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        color: FlowColor = .blue,
        collapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.collapsed = collapsed
    }

    enum FlowColor: String, Codable, CaseIterable {
        case blue, green, orange, purple, red, teal, pink

        var color: Color {
            switch self {
            case .blue: return .blue
            case .green: return .green
            case .orange: return .orange
            case .purple: return .purple
            case .red: return .red
            case .teal: return .teal
            case .pink: return .pink
            }
        }
    }
}

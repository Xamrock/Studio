import Foundation
import AppKit

struct CapturedScreen: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    var name: String
    let snapshot: HierarchySnapshot
    let screenshot: NSImage?

    var graphPosition: CGPoint?

    var flowGroupIds: Set<UUID> = []

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CapturedScreen, rhs: CapturedScreen) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, name, snapshot
        case graphPosition, flowGroupIds
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        name: String = "Untitled Screen",
        snapshot: HierarchySnapshot,
        screenshot: NSImage? = nil,
        graphPosition: CGPoint? = nil,
        flowGroupIds: Set<UUID> = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.snapshot = snapshot
        self.screenshot = screenshot
        self.graphPosition = graphPosition
        self.flowGroupIds = flowGroupIds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(name, forKey: .name)
        try container.encode(snapshot, forKey: .snapshot)
        try container.encodeIfPresent(graphPosition, forKey: .graphPosition)
        try container.encode(flowGroupIds, forKey: .flowGroupIds)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        name = try container.decode(String.self, forKey: .name)
        snapshot = try container.decode(HierarchySnapshot.self, forKey: .snapshot)
        screenshot = nil
        graphPosition = try container.decodeIfPresent(CGPoint.self, forKey: .graphPosition)
        flowGroupIds = (try? container.decode(Set<UUID>.self, forKey: .flowGroupIds)) ?? []
    }

    var hasWebView: Bool {
        snapshot.elements.contains { $0.containsWebView }
    }

    var accessibilityStatus: String {
        let interactiveElements = snapshot.elements.flatMap { $0.allInteractiveElements }

        guard !interactiveElements.isEmpty else {
            return "complete"
        }

        let allHaveLabels = interactiveElements.allSatisfy { element in
            !element.label.isEmpty || !element.title.isEmpty || !element.identifier.isEmpty
        }

        return allHaveLabels ? "complete" : "incomplete"
    }
}

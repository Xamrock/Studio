import Foundation

class InteractionService {
    private let communicationService: CommunicationService

    init(communicationService: CommunicationService) {
        self.communicationService = communicationService
    }

    func tap(element: SnapshotElement) async throws -> HierarchySnapshot {
        let query = createQuery(from: element)
        let command = Command.tap(query: query)
        return try await executeInteraction(command)
    }

    func doubleTap(element: SnapshotElement) async throws -> HierarchySnapshot {
        let query = createQuery(from: element)
        let command = Command.doubleTap(query: query)
        return try await executeInteraction(command)
    }

    func longPress(element: SnapshotElement, duration: TimeInterval = 1.0) async throws -> HierarchySnapshot {
        let query = createQuery(from: element)
        let command = Command.longPress(query: query, duration: duration)
        return try await executeInteraction(command)
    }

    func swipe(element: SnapshotElement? = nil, direction: SwipeDirection) async throws -> HierarchySnapshot {
        let query = element.map { createQuery(from: $0) }
        let command = Command.swipe(direction: direction, query: query)
        return try await executeInteraction(command)
    }

    func typeText(_ text: String, in element: SnapshotElement? = nil) async throws {
        let query = element.map { createQuery(from: $0) }
        let command = Command.typeText(text: text, query: query)
        _ = try await executeInteraction(command)
    }

    func tapAtCoordinate(x: Double, y: Double) async throws -> HierarchySnapshot {
        let command = Command.tapCoordinate(x: x, y: y)
        return try await executeInteraction(command)
    }

    func swipeAtCoordinate(x: Double, y: Double, direction: SwipeDirection) async throws -> HierarchySnapshot {
        let command = Command.swipeCoordinate(x: x, y: y, direction: direction)
        return try await executeInteraction(command)
    }

    private func createQuery(from element: SnapshotElement) -> ElementQuery {
        let isUUID = isUUIDPattern(element.identifier)

        let hasIdentifier = !element.identifier.isEmpty && !isUUID
        let hasLabel = !element.label.isEmpty
        let hasTitle = !element.title.isEmpty

        if hasIdentifier || hasLabel || hasTitle {
            return ElementQuery(
                identifier: hasIdentifier ? element.identifier : nil,
                label: hasLabel ? element.label : nil,
                title: hasTitle ? element.title : nil,
                elementType: element.elementType
            )
        }

        if !element.identifier.isEmpty {
            return ElementQuery(
                identifier: element.identifier,
                elementType: element.elementType
            )
        }

        return ElementQuery(
            elementType: element.elementType
        )
    }

    private func isUUIDPattern(_ string: String) -> Bool {
        let uuidPattern = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        return string.range(of: uuidPattern, options: .regularExpression) != nil
    }

    private func executeInteraction(_ command: Command) async throws -> HierarchySnapshot {
        guard let jsonString = try await communicationService.sendCommand(command),
              let jsonData = jsonString.data(using: .utf8) else {
            throw InteractionError.noResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HierarchySnapshot.self, from: jsonData)
    }
}

enum InteractionError: Error {
    case noResponse
}

import Foundation

struct NavigationEdge: Codable, Identifiable {
    let id: UUID
    let sourceScreenId: UUID
    let targetScreenId: UUID
    var interactionType: InteractionType  // Mutable for editing
    var elementLabel: String  // Mutable for editing
    let elementIdentifier: String
    let timestamp: Date

    var duration: Double?  // For long press (in seconds)
    var coordinateX: Double?  // For coordinate tap (normalized 0-1)
    var coordinateY: Double?  // For coordinate tap (normalized 0-1)
    var cellIndex: Int?  // For cell interactions
    var elementType: UInt?  // XCUIElement.ElementType raw value from recording

    init(
        id: UUID = UUID(),
        sourceScreenId: UUID,
        targetScreenId: UUID,
        interactionType: InteractionType,
        elementLabel: String,
        elementIdentifier: String,
        timestamp: Date = Date(),
        duration: Double? = nil,
        coordinateX: Double? = nil,
        coordinateY: Double? = nil,
        cellIndex: Int? = nil,
        elementType: UInt? = nil
    ) {
        self.id = id
        self.sourceScreenId = sourceScreenId
        self.targetScreenId = targetScreenId
        self.interactionType = interactionType
        self.elementLabel = elementLabel
        self.elementIdentifier = elementIdentifier
        self.timestamp = timestamp
        self.duration = duration
        self.coordinateX = coordinateX
        self.coordinateY = coordinateY
        self.cellIndex = cellIndex
        self.elementType = elementType
    }
}

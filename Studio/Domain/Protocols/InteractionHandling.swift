import Foundation

enum UserInteraction {
    case tap(element: SnapshotElement)
    case doubleTap(element: SnapshotElement)
    case longPress(element: SnapshotElement, duration: Double)
    case swipe(element: SnapshotElement?, direction: SwipeDirection)
    case typeText(text: String, element: SnapshotElement)
    case tapCoordinate(coordinate: CGPoint)
    case swipeAtCoordinate(coordinate: CGPoint, direction: SwipeDirection)
}

protocol InteractionHandling {
    func executeInteraction(
        _ interaction: UserInteraction,
        sourceScreenId: UUID,
        screenName: String?
    ) async throws -> HierarchySnapshot
}

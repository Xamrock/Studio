import Foundation
import AppKit

@MainActor
class InteractionCoordinator {
    private let interactionService: InteractionService
    private var currentInteractionTask: Task<Void, Never>?

    private(set) var isInteracting = false

    init(interactionService: InteractionService) {
        self.interactionService = interactionService
    }

    func cancelOngoingInteractions() {
        currentInteractionTask?.cancel()
        currentInteractionTask = nil
        isInteracting = false
    }

    struct InteractionResult {
        let capturedScreen: CapturedScreen
        let navigationEdge: NavigationEdge
    }

    // MARK: - Tap Interaction

    func tap(
        element: SnapshotElement,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        let newSnapshot = try await interactionService.tap(element: element)

        let finalName = !screenName.isEmpty
            ? screenName
            : "After tap on \(element.displayLabel)"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let edge = createNavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: element.interactionType,
            element: element
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Type Text Interaction

    func typeText(
        _ text: String,
        in element: SnapshotElement,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        _ = try await interactionService.tap(element: element)
        try Task.checkCancellation()

        try await interactionService.typeText(text, in: element)
        try Task.checkCancellation()

        try await Task.sleep(nanoseconds: 500_000_000)
        try Task.checkCancellation()

        let newSnapshot = try await interactionService.tap(element: element)

        let finalName = !screenName.isEmpty
            ? screenName
            : "After typing '\(text)' into \(element.displayLabel)"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let edge = createNavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: .textInput,
            element: element
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Double Tap Interaction

    func doubleTap(
        element: SnapshotElement,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        let newSnapshot = try await interactionService.doubleTap(element: element)

        let finalName = !screenName.isEmpty
            ? screenName
            : "After double-tap on \(element.displayLabel)"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let edge = createNavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: .doubleTap,
            element: element
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Long Press Interaction

    func longPress(
        element: SnapshotElement,
        duration: Double,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        let newSnapshot = try await interactionService.longPress(element: element, duration: duration)

        let finalName = !screenName.isEmpty
            ? screenName
            : "After \(duration)s press on \(element.displayLabel)"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let edge = createNavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: .longPress,
            element: element,
            duration: duration
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Coordinate Tap Interaction

    func tapAtCoordinate(
        _ coordinate: CGPoint,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        let newSnapshot = try await interactionService.tapAtCoordinate(
            x: coordinate.x,
            y: coordinate.y
        )

        let finalName = !screenName.isEmpty
            ? screenName
            : "After tap at (\(Int(coordinate.x)), \(Int(coordinate.y)))"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let edge = NavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: .coordinateTap,
            elementLabel: "Coordinate tap",
            elementIdentifier: ""
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Coordinate Swipe Interaction

    func swipeAtCoordinate(
        _ coordinate: CGPoint,
        direction: SwipeDirection,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        let newSnapshot = try await interactionService.swipeAtCoordinate(
            x: coordinate.x,
            y: coordinate.y,
            direction: direction
        )

        let finalName = !screenName.isEmpty
            ? screenName
            : "After swipe \(direction.rawValue) at (\(Int(coordinate.x)), \(Int(coordinate.y)))"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let interactionType: InteractionType
        switch direction {
        case .up: interactionType = .swipeUp
        case .down: interactionType = .swipeDown
        case .left: interactionType = .swipeLeft
        case .right: interactionType = .swipeRight
        }

        let edge = NavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: interactionType,
            elementLabel: "Swipe \(direction.rawValue) at coordinate",
            elementIdentifier: ""
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Element Swipe Interaction

    func swipe(
        element: SnapshotElement,
        direction: SwipeDirection,
        sourceScreenId: UUID,
        screenName: String = ""
    ) async throws -> InteractionResult {
        guard !isInteracting else {
            throw InteractionCoordinatorError.alreadyInteracting
        }

        isInteracting = true
        defer { isInteracting = false }

        let newSnapshot = try await interactionService.swipe(element: element, direction: direction)

        let finalName = !screenName.isEmpty
            ? screenName
            : "After swipe \(direction.rawValue) on \(element.displayLabel)"

        let newScreen = createCapturedScreen(
            name: finalName,
            snapshot: newSnapshot
        )

        let interactionType: InteractionType
        switch direction {
        case .up: interactionType = .swipeUp
        case .down: interactionType = .swipeDown
        case .left: interactionType = .swipeLeft
        case .right: interactionType = .swipeRight
        }

        let edge = createNavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: newScreen.id,
            interactionType: interactionType,
            element: element
        )

        return InteractionResult(capturedScreen: newScreen, navigationEdge: edge)
    }

    // MARK: - Private Helpers

    private func createCapturedScreen(
        name: String,
        snapshot: HierarchySnapshot
    ) -> CapturedScreen {
        var screenshotImage: NSImage?
        if let base64Screenshot = snapshot.screenshot,
           let imageData = Data(base64Encoded: base64Screenshot) {
            screenshotImage = NSImage(data: imageData)
        }

        return CapturedScreen(
            timestamp: Date(),
            name: name,
            snapshot: snapshot,
            screenshot: screenshotImage
        )
    }

    private func createNavigationEdge(
        sourceScreenId: UUID,
        targetScreenId: UUID,
        interactionType: InteractionType,
        element: SnapshotElement,
        duration: Double? = nil
    ) -> NavigationEdge {
        NavigationEdge(
            sourceScreenId: sourceScreenId,
            targetScreenId: targetScreenId,
            interactionType: interactionType,
            elementLabel: element.displayLabel,
            elementIdentifier: element.identifier,
            duration: duration,
            elementType: element.elementType
        )
    }
}

// MARK: - Helper Extension

private extension SnapshotElement {
    var displayLabel: String {
        if !label.isEmpty {
            return label
        } else if !title.isEmpty {
            return title
        } else {
            return identifier
        }
    }
}

// MARK: - Error

enum InteractionCoordinatorError: Error {
    case alreadyInteracting
}

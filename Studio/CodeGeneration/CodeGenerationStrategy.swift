import Foundation

// MARK: - Shared Types

struct TestStep {
    enum Action {
        case tap(identifier: String, label: String)
        case typeText(identifier: String, text: String)
        case wait(seconds: Double)
        case verify(condition: String)
        case swipe(direction: SwipeDirection, identifier: String, label: String)
        case longPress(identifier: String, label: String, duration: Double)
        case doubleTap(identifier: String, label: String)
        case tapCoordinate(x: Double, y: Double)
        case tapCell(index: Int, identifier: String, label: String)
    }

    let description: String
    let action: Action
}

// MARK: - Strategy Protocol

protocol CodeGenerationStrategy {
    func generate(
        flowGroup: FlowGroup,
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        bundleID: String
    ) -> String
}

// MARK: - Shared Utilities

class CodeGenerationUtilities {
    static func buildTestPath(screens: [CapturedScreen], edges: [NavigationEdge]) -> [TestStep] {
        var steps: [TestStep] = []

        let relevantEdges = edges.filter { edge in
            screens.contains { $0.id == edge.sourceScreenId } &&
            screens.contains { $0.id == edge.targetScreenId }
        }

        let sortedEdges = relevantEdges.sorted { $0.timestamp < $1.timestamp }

        for edge in sortedEdges {
            let sourceScreen = screens.first { $0.id == edge.sourceScreenId }
            let targetScreen = screens.first { $0.id == edge.targetScreenId }

            let stepDescription = "Navigate from '\(sourceScreen?.name ?? "Unknown")' to '\(targetScreen?.name ?? "Unknown")'"

            switch edge.interactionType {
            case .button, .navigation, .selection:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .tap(identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .textInput:
                let text = extractTextFromScreenName(targetScreen?.name ?? "")
                steps.append(TestStep(
                    description: stepDescription,
                    action: .typeText(identifier: edge.elementIdentifier, text: text)
                ))

            case .toggle, .picker, .adjustment:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .tap(identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .swipeUp:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .swipe(direction: .up, identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .swipeDown:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .swipe(direction: .down, identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .swipeLeft:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .swipe(direction: .left, identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .swipeRight:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .swipe(direction: .right, identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .longPress:
                let duration = edge.duration ?? 1.0
                steps.append(TestStep(
                    description: stepDescription,
                    action: .longPress(identifier: edge.elementIdentifier, label: edge.elementLabel, duration: duration)
                ))

            case .doubleTap:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .doubleTap(identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .coordinateTap:
                let x = edge.coordinateX ?? 0.5
                let y = edge.coordinateY ?? 0.5
                steps.append(TestStep(
                    description: stepDescription,
                    action: .tapCoordinate(x: x, y: y)
                ))

            case .cellInteraction:
                let index = edge.cellIndex ?? 0
                steps.append(TestStep(
                    description: stepDescription,
                    action: .tapCell(index: index, identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))

            case .none, .other:
                steps.append(TestStep(
                    description: stepDescription,
                    action: .tap(identifier: edge.elementIdentifier, label: edge.elementLabel)
                ))
            }

            steps.append(TestStep(
                description: "Wait for UI to settle",
                action: .wait(seconds: 0.5)
            ))
        }

        return steps
    }

    static func sanitizeClassName(_ name: String) -> String {
        let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }

    static func sanitizeFunctionName(_ name: String) -> String {
        let className = sanitizeClassName(name)
        guard let first = className.first else { return "test" }
        return first.lowercased() + className.dropFirst()
    }

    static func extractTextFromScreenName(_ screenName: String) -> String {
        if let range = screenName.range(of: "'([^']+)'", options: .regularExpression) {
            let match = screenName[range]
            return String(match.dropFirst().dropLast())
        }
        return "test input"
    }
}

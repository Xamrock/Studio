import Foundation

class CodeGenerationService {
    enum TestFramework {
        case xcuiTest
        case maestro
        case appium
    }

    private let xcuiTestGenerator = XCUITestGenerator()
    private let maestroGenerator = MaestroGenerator()
    private let appiumGenerator = AppiumGenerator()

    /// Maps XCUIElement.ElementType raw values to script command element type strings
    private func elementTypeString(for rawType: UInt?) -> String? {
        guard let rawType = rawType else { return nil }
        switch rawType {
        case 9, 17:  // Button, ToolbarButton
            return "button"
        case 45:  // SearchField
            return "searchField"
        case 49:  // TextField
            return "textField"
        case 50:  // SecureTextField
            return "secureTextField"
        case 52:  // TextView
            return "textView"
        case 40, 41:  // Switch, Toggle
            return "switch"
        case 33:  // Slider
            return "slider"
        case 38, 39:  // Picker, PickerWheel
            return "picker"
        case 60:  // Cell
            return "cell"
        case 47:  // StaticText
            return "staticText"
        case 48:  // Image
            return "image"
        case 62:  // Table
            return "table"
        case 63:  // CollectionView
            return "collectionView"
        case 54:  // ScrollView
            return "scrollView"
        case 72:  // NavigationBar
            return "navigationBar"
        case 81:  // TabBar
            return "tabBar"
        case 75:  // Toolbar
            return "toolbar"
        default:
            return "other"
        }
    }

    func generate(
        framework: TestFramework,
        flowGroup: FlowGroup,
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        bundleID: String
    ) -> String {
        let strategy: CodeGenerationStrategy

        switch framework {
        case .xcuiTest:
            strategy = xcuiTestGenerator
        case .maestro:
            strategy = maestroGenerator
        case .appium:
            strategy = appiumGenerator
        }

        return strategy.generate(
            flowGroup: flowGroup,
            screens: screens,
            edges: edges,
            bundleID: bundleID
        )
    }

    /// Generates JSON commands for the scripted test runner
    /// This is used when running tests from the bundled app without source code access
    func generateScriptCommands(
        flowGroup: FlowGroup,
        screens: [CapturedScreen],
        edges: [NavigationEdge]
    ) -> String {
        let flowScreens = screens.filter { screen in
            screen.flowGroupIds.contains(flowGroup.id)
        }

        let steps = CodeGenerationUtilities.buildTestPath(screens: flowScreens, edges: edges)
        var commands: [[String: Any]] = []

        for step in steps {
            var command: [String: Any] = [:]

            switch step.action {
            case .tap(let identifier, let label, let elementType):
                command["action"] = "tap"
                if let typeString = elementTypeString(for: elementType) {
                    command["elementType"] = typeString
                } else {
                    command["elementType"] = "button"
                }
                if !identifier.isEmpty && identifier != "manual_edge" {
                    command["identifier"] = identifier
                } else if !label.isEmpty {
                    command["label"] = label
                }

            case .typeText(let identifier, let text, let elementType):
                command["action"] = "typeText"
                if let typeString = elementTypeString(for: elementType) {
                    command["elementType"] = typeString
                } else {
                    command["elementType"] = "textField"
                }
                command["identifier"] = identifier
                command["text"] = text

            case .wait(let seconds):
                command["action"] = "wait"
                command["duration"] = seconds

            case .verify(let condition):
                command["action"] = "verify"
                command["identifier"] = condition

            case .swipe(let direction, let identifier, let label, let elementType):
                command["action"] = "swipe\(direction.rawValue.capitalized)"
                if !identifier.isEmpty && identifier != "manual_edge" {
                    command["identifier"] = identifier
                    if let typeString = elementTypeString(for: elementType) {
                        command["elementType"] = typeString
                    } else {
                        command["elementType"] = "other"
                    }
                } else if !label.isEmpty {
                    command["label"] = label
                    if let typeString = elementTypeString(for: elementType) {
                        command["elementType"] = typeString
                    } else {
                        command["elementType"] = "other"
                    }
                }

            case .longPress(let identifier, let label, let duration, let elementType):
                command["action"] = "longPress"
                if let typeString = elementTypeString(for: elementType) {
                    command["elementType"] = typeString
                } else {
                    command["elementType"] = "button"
                }
                command["duration"] = duration
                if !identifier.isEmpty && identifier != "manual_edge" {
                    command["identifier"] = identifier
                } else if !label.isEmpty {
                    command["label"] = label
                }

            case .doubleTap(let identifier, let label, let elementType):
                command["action"] = "doubleTap"
                if let typeString = elementTypeString(for: elementType) {
                    command["elementType"] = typeString
                } else {
                    command["elementType"] = "button"
                }
                if !identifier.isEmpty && identifier != "manual_edge" {
                    command["identifier"] = identifier
                } else if !label.isEmpty {
                    command["label"] = label
                }

            case .tapCoordinate(let x, let y):
                command["action"] = "tapCoordinate"
                command["x"] = x
                command["y"] = y

            case .tapCell(let index, let identifier, let label, let elementType):
                command["action"] = "tap"
                if let typeString = elementTypeString(for: elementType) {
                    command["elementType"] = typeString
                } else {
                    command["elementType"] = "cell"
                }
                command["index"] = index
                if !identifier.isEmpty && identifier != "manual_edge" {
                    command["identifier"] = identifier
                } else if !label.isEmpty {
                    command["label"] = label
                }
            }

            if !command.isEmpty {
                commands.append(command)
            }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: commands, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }

        return jsonString
    }
}

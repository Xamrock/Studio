import Foundation

class XCUITestGenerator: CodeGenerationStrategy {
    /// Maps XCUIElement.ElementType raw values to XCUITest query names
    private func xcuiQueryName(for rawType: UInt?) -> String {
        guard let rawType = rawType else { return "buttons" }
        switch rawType {
        case 9, 17:  // Button, ToolbarButton
            return "buttons"
        case 45:  // SearchField
            return "searchFields"
        case 49:  // TextField
            return "textFields"
        case 50:  // SecureTextField
            return "secureTextFields"
        case 52:  // TextView
            return "textViews"
        case 40, 41:  // Switch, Toggle
            return "switches"
        case 33:  // Slider
            return "sliders"
        case 38, 39:  // Picker, PickerWheel
            return "pickers"
        case 60:  // Cell
            return "cells"
        case 47:  // StaticText
            return "staticTexts"
        case 48:  // Image
            return "images"
        case 62:  // Table
            return "tables"
        case 63:  // CollectionView
            return "collectionViews"
        case 54:  // ScrollView
            return "scrollViews"
        case 72:  // NavigationBar
            return "navigationBars"
        case 81:  // TabBar
            return "tabBars"
        case 75:  // Toolbar
            return "toolbars"
        default:
            return "otherElements"
        }
    }

    func generate(
        flowGroup: FlowGroup,
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        bundleID: String
    ) -> String {
        var code = """
        import XCTest

        final class \(CodeGenerationUtilities.sanitizeClassName(flowGroup.name))UITests: XCTestCase {

            var app: XCUIApplication!

            override func setUpWithError() throws {
                continueAfterFailure = false
                app = XCUIApplication(bundleIdentifier: "\(bundleID)")
                app.launch()
            }

            override func tearDownWithError() throws {
                app.terminate()
            }

            func test\(CodeGenerationUtilities.sanitizeFunctionName(flowGroup.name))() throws {

        """

        let flowScreens = screens.filter { screen in
            screen.flowGroupIds.contains(flowGroup.id)
        }

        let path = CodeGenerationUtilities.buildTestPath(screens: flowScreens, edges: edges)

        for step in path {
            code += generateStep(step, indentation: "        ")
        }

        code += """
            }
        }

        """

        return code
    }

    private func generateStep(_ step: TestStep, indentation: String) -> String {
        var code = "\n"
        code += "\(indentation)// \(step.description)\n"

        switch step.action {
        case .tap(let identifier, let label, let elementType):
            let query = xcuiQueryName(for: elementType)
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.\(query)[\"\(identifier)\"].tap()\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.\(query)[\"\(label)\"].tap()\n"
            } else {
                code += "\(indentation)// TODO: Tap element (identifier unknown)\n"
            }

        case .typeText(let identifier, let text, let elementType):
            let query = xcuiQueryName(for: elementType)
            code += "\(indentation)app.\(query)[\"\(identifier)\"].tap()\n"
            code += "\(indentation)app.\(query)[\"\(identifier)\"].typeText(\"\(text)\")\n"

        case .wait(let seconds):
            code += "\(indentation)Thread.sleep(forTimeInterval: \(seconds))\n"

        case .verify(let condition):
            code += "\(indentation)XCTAssertTrue(\(condition))\n"

        case .swipe(let direction, let identifier, let label, let elementType):
            let query = xcuiQueryName(for: elementType)
            let element = !identifier.isEmpty && identifier != "manual_edge"
                ? "app.\(query)[\"\(identifier)\"]"
                : (!label.isEmpty ? "app.\(query)[\"\(label)\"]" : "app")
            code += "\(indentation)\(element).swipe\(direction.rawValue.capitalized)()\n"

        case .longPress(let identifier, let label, let duration, let elementType):
            let query = xcuiQueryName(for: elementType)
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.\(query)[\"\(identifier)\"].press(forDuration: \(duration))\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.\(query)[\"\(label)\"].press(forDuration: \(duration))\n"
            } else {
                code += "\(indentation)// TODO: Long press element (identifier unknown)\n"
            }

        case .doubleTap(let identifier, let label, let elementType):
            let query = xcuiQueryName(for: elementType)
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.\(query)[\"\(identifier)\"].doubleTap()\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.\(query)[\"\(label)\"].doubleTap()\n"
            } else {
                code += "\(indentation)// TODO: Double tap element (identifier unknown)\n"
            }

        case .tapCoordinate(let x, let y):
            code += "\(indentation)app.coordinate(withNormalizedOffset: CGVector(dx: \(x), dy: \(y))).tap()\n"

        case .tapCell(let index, let identifier, let label, let elementType):
            let query = xcuiQueryName(for: elementType)
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.tables[\"\(identifier)\"].\(query).element(boundBy: \(index)).tap()\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.tables.\(query).matching(identifier: \"\(label)\").element(boundBy: \(index)).tap()\n"
            } else {
                code += "\(indentation)app.tables.\(query).element(boundBy: \(index)).tap()\n"
            }
        }

        return code
    }
}

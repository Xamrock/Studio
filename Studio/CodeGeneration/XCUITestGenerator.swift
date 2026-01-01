import Foundation

class XCUITestGenerator: CodeGenerationStrategy {
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
                app = XCUIApplication()
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
        case .tap(let identifier, let label):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.buttons[\"\(identifier)\"].tap()\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.buttons[\"\(label)\"].tap()\n"
            } else {
                code += "\(indentation)// TODO: Tap element (identifier unknown)\n"
            }

        case .typeText(let identifier, let text):
            code += "\(indentation)let textField = app.textFields[\"\(identifier)\"]\n"
            code += "\(indentation)textField.tap()\n"
            code += "\(indentation)textField.typeText(\"\(text)\")\n"

        case .wait(let seconds):
            code += "\(indentation)Thread.sleep(forTimeInterval: \(seconds))\n"

        case .verify(let condition):
            code += "\(indentation)XCTAssertTrue(\(condition))\n"

        case .swipe(let direction, let identifier, let label):
            let element = !identifier.isEmpty && identifier != "manual_edge"
                ? "app.otherElements[\"\(identifier)\"]"
                : (!label.isEmpty ? "app.otherElements[\"\(label)\"]" : "app")
            code += "\(indentation)\(element).swipe\(direction.rawValue.capitalized)()\n"

        case .longPress(let identifier, let label, let duration):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.buttons[\"\(identifier)\"].press(forDuration: \(duration))\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.buttons[\"\(label)\"].press(forDuration: \(duration))\n"
            } else {
                code += "\(indentation)// TODO: Long press element (identifier unknown)\n"
            }

        case .doubleTap(let identifier, let label):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.buttons[\"\(identifier)\"].doubleTap()\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.buttons[\"\(label)\"].doubleTap()\n"
            } else {
                code += "\(indentation)// TODO: Double tap element (identifier unknown)\n"
            }

        case .tapCoordinate(let x, let y):
            code += "\(indentation)let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: \(x), dy: \(y)))\n"
            code += "\(indentation)coordinate.tap()\n"

        case .tapCell(let index, let identifier, let label):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)app.tables[\"\(identifier)\"].cells.element(boundBy: \(index)).tap()\n"
            } else if !label.isEmpty {
                code += "\(indentation)app.tables.cells.matching(identifier: \"\(label)\").element(boundBy: \(index)).tap()\n"
            } else {
                code += "\(indentation)app.tables.cells.element(boundBy: \(index)).tap()\n"
            }
        }

        return code
    }
}

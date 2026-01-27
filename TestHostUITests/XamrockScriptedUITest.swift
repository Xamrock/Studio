//
//  XamrockScriptedUITest.swift
//  TestHostUITests
//
//  Executes scripted UI test commands passed via environment variables.
//  This allows the bundled test runner to execute generated tests without recompilation.
//

import XCTest

/// A scriptable UI test that reads commands from environment variables and executes them.
/// This enables running generated tests from a distributed app without source code access.
final class XamrockScriptedUITest: XCTestCase {

    private var app: XCUIApplication!
    private var commands: [ScriptCommand] = []

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Read configuration from environment variables
        // Note: xcodebuild strips TEST_RUNNER_ prefix before passing to test process
        let env = ProcessInfo.processInfo.environment

        guard let bundleID = env["XAMROCK_BUNDLE_ID"], !bundleID.isEmpty else {
            throw ScriptedTestError.missingBundleID
        }

        guard let commandsJSON = env["XAMROCK_COMMANDS"], !commandsJSON.isEmpty else {
            throw ScriptedTestError.missingCommands
        }

        // Parse commands
        guard let data = commandsJSON.data(using: .utf8) else {
            throw ScriptedTestError.invalidCommandsFormat
        }

        let decoder = JSONDecoder()
        commands = try decoder.decode([ScriptCommand].self, from: data)

        // Initialize and launch the app
        app = XCUIApplication(bundleIdentifier: bundleID)
        app.launch()

        // Wait for app to fully launch and settle
        Thread.sleep(forTimeInterval: 2.0)

        // Additional wait for the app to become idle
        _ = app.wait(for: .runningForeground, timeout: 10.0)
    }

    override func tearDownWithError() throws {
        app?.terminate()
    }

    func testExecuteScript() throws {
        print("Starting script execution with \(commands.count) commands")
        print("Target app is running: \(app.state == .runningForeground)")

        for (index, command) in commands.enumerated() {
            print("\n--- Step \(index + 1)/\(commands.count) ---")
            print("Action: \(command.action)")
            if let identifier = command.identifier {
                print("Identifier: \(identifier)")
            }
            if let label = command.label {
                print("Label: \(label)")
            }
            if let elementType = command.elementType {
                print("Element type hint: \(elementType)")
            }

            try executeCommand(command)

            // Wait between commands for UI to settle
            let waitTime = command.waitAfter ?? 0.5
            if waitTime > 0 {
                Thread.sleep(forTimeInterval: waitTime)
            }

            print("Step \(index + 1) completed successfully")
        }

        print("\n=== Script completed successfully! ===")
    }

    private func executeCommand(_ command: ScriptCommand) throws {
        switch command.action {
        case "tap":
            try executeTap(command)

        case "typeText":
            try executeTypeText(command)

        case "swipeUp", "swipeDown", "swipeLeft", "swipeRight":
            try executeSwipe(command)

        case "doubleTap":
            try executeDoubleTap(command)

        case "longPress":
            try executeLongPress(command)

        case "tapCoordinate":
            try executeTapCoordinate(command)

        case "wait":
            if let duration = command.duration {
                Thread.sleep(forTimeInterval: duration)
            }

        case "verify":
            try executeVerify(command)

        default:
            print("Unknown action: \(command.action), skipping...")
        }
    }

    private func executeTap(_ command: ScriptCommand) throws {
        let element = try findElement(command)
        element.tap()
    }

    private func executeTypeText(_ command: ScriptCommand) throws {
        guard let text = command.text else {
            throw ScriptedTestError.missingText
        }

        let element = try findElement(command)
        element.tap()
        element.typeText(text)
    }

    private func executeSwipe(_ command: ScriptCommand) throws {
        let element: XCUIElement
        if command.identifier != nil || command.label != nil {
            element = try findElement(command)
        } else {
            element = app
        }

        switch command.action {
        case "swipeUp":
            element.swipeUp()
        case "swipeDown":
            element.swipeDown()
        case "swipeLeft":
            element.swipeLeft()
        case "swipeRight":
            element.swipeRight()
        default:
            break
        }
    }

    private func executeDoubleTap(_ command: ScriptCommand) throws {
        let element = try findElement(command)
        element.doubleTap()
    }

    private func executeLongPress(_ command: ScriptCommand) throws {
        let element = try findElement(command)
        let duration = command.duration ?? 1.0
        element.press(forDuration: duration)
    }

    private func executeTapCoordinate(_ command: ScriptCommand) throws {
        guard let x = command.x, let y = command.y else {
            throw ScriptedTestError.missingCoordinate
        }

        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let coordinate = normalized.withOffset(CGVector(dx: x, dy: y))
        coordinate.tap()
    }

    private func executeVerify(_ command: ScriptCommand) throws {
        let element = try findElement(command)
        XCTAssertTrue(element.exists, "Element should exist: \(command.identifier ?? command.label ?? "unknown")")
    }

    private func findElement(_ command: ScriptCommand) throws -> XCUIElement {
        let timeout = command.timeout ?? 10.0
        let identifier = command.identifier
        let label = command.label

        // First, try the specific element type if provided
        if let elementType = command.elementType {
            if let element = tryFindInQuery(getQueryForType(elementType), identifier: identifier, label: label, index: command.index, timeout: timeout) {
                return element
            }
        }

        // If not found, try common element types for the action
        // For text input, try textFields, searchFields, and secureTextFields
        let typesToTry: [XCUIElementQuery]
        switch command.action {
        case "typeText":
            typesToTry = [app.textFields, app.searchFields, app.secureTextFields, app.textViews]
        case "tap":
            typesToTry = [app.buttons, app.staticTexts, app.cells, app.images, app.otherElements]
        default:
            typesToTry = [app.descendants(matching: .any)]
        }

        for query in typesToTry {
            if let element = tryFindInQuery(query, identifier: identifier, label: label, index: command.index, timeout: 2.0) {
                return element
            }
        }

        // Last resort: try to find by identifier across all descendants
        if let identifier = identifier, !identifier.isEmpty {
            let element = app.descendants(matching: .any)[identifier]
            if element.waitForExistence(timeout: timeout) {
                return element
            }
        }

        // Try by label across all descendants
        if let label = label, !label.isEmpty {
            let predicate = NSPredicate(format: "label == %@ OR identifier == %@", label, label)
            let element = app.descendants(matching: .any).matching(predicate).firstMatch
            if element.waitForExistence(timeout: timeout) {
                return element
            }
        }

        throw ScriptedTestError.elementNotFound(
            identifier: identifier,
            label: label,
            elementType: command.elementType
        )
    }

    private func tryFindInQuery(_ query: XCUIElementQuery, identifier: String?, label: String?, index: Int?, timeout: TimeInterval) -> XCUIElement? {
        let element: XCUIElement

        if let identifier = identifier, !identifier.isEmpty {
            element = query[identifier]
        } else if let label = label, !label.isEmpty {
            element = query[label]
        } else if let index = index {
            element = query.element(boundBy: index)
        } else {
            element = query.firstMatch
        }

        if element.waitForExistence(timeout: timeout) {
            return element
        }

        return nil
    }

    private func getQueryForType(_ elementType: String) -> XCUIElementQuery {
        switch elementType {
        case "button":
            return app.buttons
        case "textField":
            return app.textFields
        case "searchField":
            return app.searchFields
        case "secureTextField":
            return app.secureTextFields
        case "staticText":
            return app.staticTexts
        case "image":
            return app.images
        case "cell":
            return app.cells
        case "table":
            return app.tables
        case "collectionView":
            return app.collectionViews
        case "scrollView":
            return app.scrollViews
        case "switch":
            return app.switches
        case "slider":
            return app.sliders
        case "picker":
            return app.pickers
        case "navigationBar":
            return app.navigationBars
        case "tabBar":
            return app.tabBars
        case "toolbar":
            return app.toolbars
        case "textView":
            return app.textViews
        case "other":
            return app.otherElements
        default:
            return app.descendants(matching: .any)
        }
    }
}

// MARK: - Models

struct ScriptCommand: Codable {
    let action: String
    let elementType: String?
    let identifier: String?
    let label: String?
    let text: String?
    let index: Int?
    let x: Double?
    let y: Double?
    let duration: Double?
    let timeout: Double?
    let waitAfter: Double?
}

enum ScriptedTestError: Error, LocalizedError {
    case missingBundleID
    case missingCommands
    case invalidCommandsFormat
    case missingText
    case missingCoordinate
    case elementNotFound(identifier: String?, label: String?, elementType: String?)

    var errorDescription: String? {
        switch self {
        case .missingBundleID:
            return "XAMROCK_BUNDLE_ID environment variable not set"
        case .missingCommands:
            return "XAMROCK_COMMANDS environment variable not set"
        case .invalidCommandsFormat:
            return "XAMROCK_COMMANDS is not valid JSON"
        case .missingText:
            return "typeText command requires 'text' field"
        case .missingCoordinate:
            return "tapCoordinate command requires 'x' and 'y' fields"
        case .elementNotFound(let identifier, let label, let elementType):
            return "Element not found - identifier: \(identifier ?? "nil"), label: \(label ?? "nil"), type: \(elementType ?? "any")"
        }
    }
}

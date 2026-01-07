//
//  PrometheusRecorderUITest.swift
//  TestHostUITests
//
//  Created by Kilo Loco on 12/23/25.
//

import XCTest
import Network
import ImageIO

/// UI Test that launches a target app by bundle ID and captures hierarchy snapshots
final class StudioRecorderUITest: XCTestCase {

    private var app: XCUIApplication!
    private var communicationPath: String!
    private var targetBundleID: String!
    private var skipAppLaunch: Bool = false
    private var listener: NWListener?
    private var shouldStop = false

    // Dedicated queue for network operations to avoid blocking main queue
    private let networkQueue = DispatchQueue(label: "com.prometheus.network", qos: .userInitiated)

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Read configuration from environment variables
        // Note: xcodebuild strips TEST_RUNNER_ prefix before passing to test process
        let env = ProcessInfo.processInfo.environment

        targetBundleID = env["PROMETHEUS_BUNDLE_ID"] ?? "com.apple.Maps"
        communicationPath = env["PROMETHEUS_COMMUNICATION_PATH"] ?? "/tmp/prometheus_test"
        skipAppLaunch = env["PROMETHEUS_SKIP_APP_LAUNCH"] == "true"

        // Initialize app with the target bundle ID
        app = XCUIApplication(bundleIdentifier: targetBundleID)
    }

    @MainActor
    func testRecordingSession() throws {
        // Conditionally launch the target app
        if !skipAppLaunch {
            app.launch()
            // Give app time to fully launch
            sleep(2)
        }

        // Start HTTP server on port 8080
        try startHTTPServer()

        // Keep test running until stop command received
        while !shouldStop {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    private func startHTTPServer() throws {
        let port: NWEndpoint.Port = 8080
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        // Configure TCP options for faster timeout detection
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 10  // 10 seconds connection timeout
        params.defaultProtocolStack.transportProtocol = tcpOptions

        listener = try NWListener(using: params, on: port)

        listener?.stateUpdateHandler = { state in
            if case .failed(let error) = state {
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: networkQueue)
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: networkQueue)

        // Accumulate all data from the connection
        var accumulatedData = Data()
        var hasProcessed = false

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self = self, !hasProcessed else {
                    connection.cancel()
                    return
                }

                if let data = data, !data.isEmpty {
                    accumulatedData.append(data)
                }

                // Check if we have a complete HTTP request (ends with \r\n\r\n for headers, or has Content-Length satisfied)
                if let requestString = String(data: accumulatedData, encoding: .utf8) {
                    let hasCompleteHeaders = requestString.contains("\r\n\r\n")

                    if hasCompleteHeaders {
                        // Extract Content-Length if present
                        var expectedBodyLength = 0
                        if let contentLengthRange = requestString.range(of: "Content-Length: "),
                           let lineEndRange = requestString[contentLengthRange.upperBound...].range(of: "\r\n") {
                            let lengthString = requestString[contentLengthRange.upperBound..<lineEndRange.lowerBound]
                            expectedBodyLength = Int(lengthString) ?? 0
                        }

                        // Calculate how much body we have
                        if let bodyStart = requestString.range(of: "\r\n\r\n")?.upperBound {
                            let bodyStartIndex = requestString.distance(from: requestString.startIndex, to: bodyStart)
                            let actualBodyLength = accumulatedData.count - bodyStartIndex

                            // Process if we have all the expected body data
                            if actualBodyLength >= expectedBodyLength {
                                hasProcessed = true
                                self.processHTTPRequest(requestString, connection: connection)
                                return
                            }
                        }
                    }
                }

                // If more data might be coming, keep receiving
                if !isComplete && error == nil {
                    receiveMore()
                } else {
                    // Connection complete - process whatever we have
                    if !hasProcessed && !accumulatedData.isEmpty, let request = String(data: accumulatedData, encoding: .utf8) {
                        hasProcessed = true
                        self.processHTTPRequest(request, connection: connection)
                    }
                }
            }
        }

        receiveMore()
    }

    private func processHTTPRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let method = components[0]
        let path = components[1]

        switch (method, path) {
        case ("GET", "/health"):
            sendHTTPResponse(connection: connection, statusCode: 200, body: "OK")

        case ("POST", "/capture"):
            do {
                // Execute snapshot capture on main queue (required by XCUITest)
                let snapshotJSON = try DispatchQueue.main.sync {
                    try captureSnapshot()
                }
                sendHTTPResponse(connection: connection, statusCode: 200, body: snapshotJSON)
            } catch {
                sendHTTPResponse(connection: connection, statusCode: 500, body: "Error: \(error)")
            }

        case ("POST", "/interact"):
            do {
                // Extract JSON body from request
                if let bodyStart = request.range(of: "\r\n\r\n")?.upperBound {
                    let body = String(request[bodyStart...])
                    let jsonData = body.data(using: .utf8) ?? Data()

                    // Decode command
                    let decoder = JSONDecoder()
                    let command = try decoder.decode(InteractionCommand.self, from: jsonData)

                    // Execute interaction and capture on main queue (required by XCUITest)
                    let snapshotJSON = try DispatchQueue.main.sync {
                        // Execute interaction
                        try executeInteraction(command)

                        // Wait a bit for UI to settle
                        sleep(1)

                        // Capture new snapshot
                        return try captureSnapshot()
                    }

                    sendHTTPResponse(connection: connection, statusCode: 200, body: snapshotJSON)
                } else {
                    sendHTTPResponse(connection: connection, statusCode: 400, body: "No body found")
                }
            } catch {
                sendHTTPResponse(connection: connection, statusCode: 500, body: "Error: \(error.localizedDescription)")
            }

        case ("POST", "/stop"):
            // Set stop flag on main queue for thread safety
            DispatchQueue.main.async { [weak self] in
                self?.shouldStop = true
            }
            sendHTTPResponse(connection: connection, statusCode: 200, body: "Stopping")
            listener?.cancel()

        default:
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText = statusCode == 200 ? "OK" : statusCode == 404 ? "Not Found" : statusCode == 500 ? "Internal Server Error" : "Bad Request"
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: text/plain\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
            }
            connection.cancel()
        })
    }

    private func captureSnapshot() throws -> String {
        // Get the root element snapshot
        let snapshot = try app.snapshot()

        // Capture screenshot
        let screenshot = XCUIScreen.main.screenshot()
        let screenshotData = screenshot.pngRepresentation
        let screenshotBase64 = screenshotData.base64EncodedString()

        // Convert to dictionary representation
        let snapshotDict = serializeSnapshot(snapshot)

        // Get app window frame to calculate offset
        let appFrame = app.frame

        // Get actual pixel dimensions from PNG data
        let screenshotPixelSize: CGSize
        if let imageSource = CGImageSourceCreateWithData(screenshotData as CFData, nil),
           let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
           let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as String] as? CGFloat,
           let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as String] as? CGFloat {
            screenshotPixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        } else {
            // Fallback to image.size (which is in points)
            screenshotPixelSize = screenshot.image.size
        }

        // Calculate display scale: element frames are in points, screenshot is in pixels
        let displayScale = screenshotPixelSize.width / appFrame.width


        // Create hierarchy snapshot with screenshot and frame info
        let hierarchySnapshot: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "elements": [snapshotDict],
            "screenshot": screenshotBase64,
            "appFrame": [
                "x": appFrame.origin.x,
                "y": appFrame.origin.y,
                "width": appFrame.size.width,
                "height": appFrame.size.height
            ],
            "screenBounds": [
                "width": screenshotPixelSize.width,
                "height": screenshotPixelSize.height
            ],
            "displayScale": displayScale,
            "platform": "ios"
        ]

        // Convert to JSON string
        let jsonData = try JSONSerialization.data(withJSONObject: hierarchySnapshot, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        return jsonString
    }

    private func serializeSnapshot(_ snapshot: XCUIElementSnapshot) -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["elementType"] = snapshot.elementType.rawValue
        dict["identifier"] = snapshot.identifier
        dict["label"] = snapshot.label
        dict["title"] = snapshot.title
        dict["value"] = snapshot.value as? String ?? ""
        dict["placeholderValue"] = snapshot.placeholderValue ?? ""
        dict["isEnabled"] = snapshot.isEnabled
        dict["isSelected"] = snapshot.isSelected

        // Frame
        let frame = snapshot.frame
        dict["frame"] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]

        // Children
        let children = snapshot.children.map { serializeSnapshot($0) }
        dict["children"] = children

        return dict
    }

    // MARK: - Interaction Execution

    private func executeInteraction(_ command: InteractionCommand) throws {
        switch command.type {
        case "tap":
            guard let query = command.query else {
                throw InteractionError.missingQuery
            }
            let element = try findElement(query)
            element.tap()

        case "doubleTap":
            guard let query = command.query else {
                throw InteractionError.missingQuery
            }
            let element = try findElement(query)
            element.doubleTap()

        case "longPress":
            guard let query = command.query else {
                throw InteractionError.missingQuery
            }
            let element = try findElement(query)
            let duration = command.duration ?? 1.0
            element.press(forDuration: duration)

        case "swipe":
            guard let direction = command.direction else {
                throw InteractionError.missingDirection
            }
            switch direction {
            case "up":
                app.swipeUp()
            case "down":
                app.swipeDown()
            case "left":
                app.swipeLeft()
            case "right":
                app.swipeRight()
            default:
                throw InteractionError.invalidDirection
            }

        case "typeText":
            guard let text = command.text else {
                throw InteractionError.missingText
            }
            if let query = command.query {
                let element = try findElement(query)
                element.tap()
                element.typeText(text)
            } else {
                app.typeText(text)
            }

        case "scroll":
            guard let direction = command.direction else {
                throw InteractionError.missingDirection
            }
            // Scroll is done via swipe on the element or app
            if let query = command.query {
                let element = try findElement(query)
                switch direction {
                case "up":
                    element.swipeUp()
                case "down":
                    element.swipeDown()
                case "left":
                    element.swipeLeft()
                case "right":
                    element.swipeRight()
                default:
                    throw InteractionError.invalidDirection
                }
            } else {
                switch direction {
                case "up":
                    app.swipeUp()
                case "down":
                    app.swipeDown()
                case "left":
                    app.swipeLeft()
                case "right":
                    app.swipeRight()
                default:
                    throw InteractionError.invalidDirection
                }
            }

        case "tapCoordinate":
            guard let x = command.x, let y = command.y else {
                throw InteractionError.missingCoordinate
            }

            // Get the app's coordinate and tap it
            let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let coordinate = normalized.withOffset(CGVector(dx: x, dy: y))
            coordinate.tap()

        case "swipeCoordinate":
            guard let x = command.x, let y = command.y else {
                throw InteractionError.missingCoordinate
            }
            guard let direction = command.direction else {
                throw InteractionError.missingDirection
            }

            // Get the app's coordinate
            let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let coordinate = normalized.withOffset(CGVector(dx: x, dy: y))

            // Perform swipe in the specified direction
            switch direction {
            case "up":
                coordinate.press(forDuration: 0.1, thenDragTo: coordinate.withOffset(CGVector(dx: 0, dy: -100)))
            case "down":
                coordinate.press(forDuration: 0.1, thenDragTo: coordinate.withOffset(CGVector(dx: 0, dy: 100)))
            case "left":
                coordinate.press(forDuration: 0.1, thenDragTo: coordinate.withOffset(CGVector(dx: -100, dy: 0)))
            case "right":
                coordinate.press(forDuration: 0.1, thenDragTo: coordinate.withOffset(CGVector(dx: 100, dy: 0)))
            default:
                throw InteractionError.invalidDirection
            }

        default:
            throw InteractionError.unknownCommand
        }
    }

    private func findElement(_ query: ElementQuery) throws -> XCUIElement {

        // Start with all descendants
        var queryBuilder = app.descendants(matching: .any)

        // Filter by element type if specified
        if let type = query.elementType {
            if let elementType = XCUIElement.ElementType(rawValue: type) {
                queryBuilder = app.descendants(matching: elementType)
            }
        }

        // Filter by identifier (exact match)
        if let identifier = query.identifier, !identifier.isEmpty {
            queryBuilder = queryBuilder.matching(identifier: identifier)
        }

        // Filter by label (exact match to avoid matching wrong elements)
        if let label = query.label, !label.isEmpty {
            queryBuilder = queryBuilder.matching(NSPredicate(format: "label == %@", label))
        }

        // Filter by title (exact match)
        if let title = query.title, !title.isEmpty {
            queryBuilder = queryBuilder.matching(NSPredicate(format: "title == %@", title))
        }


        // Get element by index or first match
        let element: XCUIElement
        if let index = query.index {
            element = queryBuilder.element(boundBy: index)
        } else {
            element = queryBuilder.firstMatch
        }

        // Verify element exists
        guard element.exists else {
            throw InteractionError.elementNotFound
        }


        return element
    }
}

// MARK: - Models

struct InteractionCommand: Codable {
    let type: String
    let query: ElementQuery?
    let duration: TimeInterval?
    let direction: String?
    let text: String?
    let x: Double?
    let y: Double?
}

struct ElementQuery: Codable {
    let identifier: String?
    let label: String?
    let title: String?
    let elementType: UInt?
    let index: Int?
}

enum InteractionError: Error {
    case missingQuery
    case missingDirection
    case missingText
    case missingCoordinate
    case invalidDirection
    case unknownCommand
    case elementNotFound
}

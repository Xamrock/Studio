//
//  PrometheusRecorderUITest.swift
//  PrometheusUITests
//
//  Created by Kilo Loco on 12/23/25.
//

import XCTest

/// UI Test that launches a target app by bundle ID and captures hierarchy snapshots
final class StudioRecorderUITest: XCTestCase {

    private var app: XCUIApplication!
    private var communicationPath: String!
    private var targetBundleID: String!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Read configuration from environment variables
        // These will be set by TestRunnerService when launching xcodebuild
        guard let bundleID = ProcessInfo.processInfo.environment["PROMETHEUS_TARGET_BUNDLE_ID"] else {
            XCTFail("PROMETHEUS_TARGET_BUNDLE_ID environment variable not set")
            return
        }

        guard let commPath = ProcessInfo.processInfo.environment["PROMETHEUS_COMMUNICATION_PATH"] else {
            XCTFail("PROMETHEUS_COMMUNICATION_PATH environment variable not set")
            return
        }

        targetBundleID = bundleID
        communicationPath = commPath

        // Initialize app with the target bundle ID
        app = XCUIApplication(bundleIdentifier: bundleID)
    }

    @MainActor
    func testRecordingSession() throws {
        // Launch the target app
        app.launch()

        // Give app time to fully launch
        sleep(2)


        // Enter a loop waiting for commands from Prometheus
        while true {
            // Check for command file
            let commandPath = "\(communicationPath!)/command.json"
            let commandURL = URL(fileURLWithPath: commandPath)

            // If command file exists, process it
            if FileManager.default.fileExists(atPath: commandPath) {
                do {
                    let data = try Data(contentsOf: commandURL)
                    let command = try JSONDecoder().decode(Command.self, from: data)


                    switch command.type {
                    case "capture":
                        try captureAndSendSnapshot()
                    case "stop":
                        // Delete command file
                        try? FileManager.default.removeItem(at: commandURL)
                        return
                    default:
                    }

                    // Delete command file after processing
                    try FileManager.default.removeItem(at: commandURL)

                } catch {
                }
            }

            // Sleep briefly before checking again
            usleep(100_000) // 100ms
        }
    }

    private func captureAndSendSnapshot() throws {

        // Get the root element snapshot
        let snapshot = try app.snapshot()

        // Convert to dictionary representation
        let snapshotDict = serializeSnapshot(snapshot)

        // Create hierarchy snapshot
        let hierarchySnapshot: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "elements": [snapshotDict]
        ]

        // Write to results directory
        let jsonData = try JSONSerialization.data(withJSONObject: hierarchySnapshot, options: .prettyPrinted)
        let filename = "snapshot_\(Date().timeIntervalSince1970).json"
        let resultPath = "\(communicationPath!)/results/\(filename)"

        // Ensure results directory exists
        let resultsDir = "\(communicationPath!)/results"
        try FileManager.default.createDirectory(atPath: resultsDir, withIntermediateDirectories: true)

        // Write snapshot
        try jsonData.write(to: URL(fileURLWithPath: resultPath))

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
}

// MARK: - Command Model

struct Command: Codable {
    let type: String
    let timestamp: String
}

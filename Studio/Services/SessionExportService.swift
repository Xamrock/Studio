import Foundation
import AppKit

class SessionExportService {
    func exportSession(
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        flowGroups: [FlowGroup]
    ) throws -> URL {
        let exportFolder = try createExportFolder()

        try saveScreenshots(screens, to: exportFolder)
        try saveHierarchyJSON(screens, to: exportFolder)
        try saveNavigationEdges(edges, to: exportFolder)
        try saveMetadata(screens: screens, edges: edges, to: exportFolder)

        return exportFolder
    }

    private func createExportFolder() throws -> URL {
        let documentsPath = try getDocumentsDirectory()
        let timestamp = createSafeTimestamp()
        let folderName = "studio_export_\(timestamp)"
        let exportFolder = documentsPath.appendingPathComponent(folderName)

        try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)

        let screenshotsFolder = exportFolder.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true)

        return exportFolder
    }

    private func getDocumentsDirectory() throws -> URL {
        guard let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw ExportError.documentsDirectoryNotFound
        }
        return documentsPath
    }

    private func createSafeTimestamp() -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let invalidChars = CharacterSet(charactersIn: ":<>|?*\\/")
        return timestamp.components(separatedBy: invalidChars).joined(separator: "-")
    }

    private func saveScreenshots(_ screens: [CapturedScreen], to exportFolder: URL) throws {
        let screenshotsFolder = exportFolder.appendingPathComponent("screenshots")

        for screen in screens {
            guard let screenshot = screen.screenshot else { continue }

            let pngData = try convertToPNG(screenshot)
            let filename = "\(screen.id).png"
            let screenshotURL = screenshotsFolder.appendingPathComponent(filename)

            try pngData.write(to: screenshotURL)
        }
    }

    private func convertToPNG(_ image: NSImage) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw ExportError.imageConversionFailed
        }
        return pngData
    }

    private func saveHierarchyJSON(_ screens: [CapturedScreen], to exportFolder: URL) throws {
        let encoder = createJSONEncoder()
        let data = try encoder.encode(screens)
        let jsonURL = exportFolder.appendingPathComponent("hierarchy.json")
        try data.write(to: jsonURL)
    }

    private func saveNavigationEdges(_ edges: [NavigationEdge], to exportFolder: URL) throws {
        let encoder = createJSONEncoder()
        let data = try encoder.encode(edges)
        let edgesURL = exportFolder.appendingPathComponent("navigation_edges.json")
        try data.write(to: edgesURL)
    }

    private func saveMetadata(
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        to exportFolder: URL
    ) throws {
        let screenshotMappings = createScreenshotMappings(screens)
        let interactiveElementsSummary = createInteractiveElementsSummary(screens)
        let edgesSummary = createEdgesSummary(edges)

        let metadata: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "screenshotMappings": screenshotMappings,
            "screensCount": screens.count,
            "navigationEdgesCount": edges.count,
            "interactiveElements": interactiveElementsSummary,
            "navigationEdges": edgesSummary
        ]

        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        let metadataURL = exportFolder.appendingPathComponent("metadata.json")
        try metadataData.write(to: metadataURL)
    }

    private func createScreenshotMappings(_ screens: [CapturedScreen]) -> [String: String] {
        var mappings: [String: String] = [:]
        for screen in screens where screen.screenshot != nil {
            mappings[screen.id.uuidString] = "\(screen.id).png"
        }
        return mappings
    }

    private func createInteractiveElementsSummary(_ screens: [CapturedScreen]) -> [[String: Any]] {
        screens.map { screen in
            let interactiveElements = screen.snapshot.elements.flatMap { $0.allInteractiveElements }
            let elementsByType = Dictionary(grouping: interactiveElements) { $0.interactionType.rawValue }
            let counts = elementsByType.mapValues { $0.count }

            return [
                "screenId": screen.id.uuidString,
                "screenName": screen.name,
                "totalInteractive": interactiveElements.count,
                "interactionTypeCounts": counts,
                "hasWebView": screen.hasWebView,
                "accessibilityStatus": screen.accessibilityStatus,
                "interactiveElements": interactiveElements.map { element in
                    [
                        "label": element.label.isEmpty ? (element.title.isEmpty ? element.identifier : element.title) : element.label,
                        "type": element.interactionType.rawValue,
                        "frame": [
                            "x": element.frame.x,
                            "y": element.frame.y,
                            "width": element.frame.width,
                            "height": element.frame.height
                        ]
                    ]
                }
            ]
        }
    }

    private func createEdgesSummary(_ edges: [NavigationEdge]) -> [[String: Any]] {
        edges.map { edge in
            [
                "source": edge.sourceScreenId.uuidString,
                "target": edge.targetScreenId.uuidString,
                "interactionType": edge.interactionType.rawValue,
                "elementLabel": edge.elementLabel,
                "elementIdentifier": edge.elementIdentifier,
                "timestamp": ISO8601DateFormatter().string(from: edge.timestamp)
            ]
        }
    }

    private func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

enum ExportError: Error, LocalizedError {
    case documentsDirectoryNotFound
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "Could not locate documents directory"
        case .imageConversionFailed:
            return "Failed to convert screenshot to PNG format"
        }
    }
}

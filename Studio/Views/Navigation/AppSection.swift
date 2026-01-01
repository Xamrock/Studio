import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case record = "Record"
    case flow = "Flow"
    case export = "Export"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .record:
            return "record.circle"
        case .flow:
            return "flowchart"
        case .export:
            return "doc.text.fill"
        }
    }

    var description: String {
        switch self {
        case .record:
            return "Record and capture UI interactions"
        case .flow:
            return "Visualize and edit navigation flow graph"
        case .export:
            return "Generate and export test code"
        }
    }
}

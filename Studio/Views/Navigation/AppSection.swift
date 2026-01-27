import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case record = "Record"
    case flow = "Flow"
    case test = "Test"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .record:
            return "record.circle"
        case .flow:
            return "flowchart"
        case .test:
            return "play.rectangle.fill"
        }
    }

    var description: String {
        switch self {
        case .record:
            return "Record and capture UI interactions"
        case .flow:
            return "Visualize and edit navigation flow graph"
        case .test:
            return "Generate and run tests on devices"
        }
    }
}

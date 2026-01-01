import Foundation
import CoreGraphics

struct HierarchySnapshot: Codable {
    let timestamp: Date
    let elements: [SnapshotElement]
    let screenshot: String?
    let appFrame: FrameData?
    let screenBounds: SizeData?
    let displayScale: Double?

    enum CodingKeys: String, CodingKey {
        case timestamp, elements, screenshot, appFrame, screenBounds, displayScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elements = try container.decode([SnapshotElement].self, forKey: .elements)
        screenshot = try container.decodeIfPresent(String.self, forKey: .screenshot)
        appFrame = try container.decodeIfPresent(FrameData.self, forKey: .appFrame)
        screenBounds = try container.decodeIfPresent(SizeData.self, forKey: .screenBounds)
        displayScale = try container.decodeIfPresent(Double.self, forKey: .displayScale)
    }
}

struct SnapshotElement: Codable, Identifiable {
    let id: UUID
    let elementType: UInt
    let label: String
    let title: String
    let value: String
    let placeholderValue: String
    let isEnabled: Bool
    let isSelected: Bool
    let frame: FrameData
    let identifier: String
    let children: [SnapshotElement]

    enum CodingKeys: String, CodingKey {
        case elementType, label, title, value, placeholderValue
        case isEnabled, isSelected, frame, identifier, children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.elementType = try container.decode(UInt.self, forKey: .elementType)
        self.label = try container.decode(String.self, forKey: .label)
        self.title = try container.decode(String.self, forKey: .title)
        self.value = try container.decode(String.self, forKey: .value)
        self.placeholderValue = try container.decode(String.self, forKey: .placeholderValue)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.isSelected = try container.decode(Bool.self, forKey: .isSelected)
        self.frame = try container.decode(FrameData.self, forKey: .frame)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.children = try container.decode([SnapshotElement].self, forKey: .children)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(elementType, forKey: .elementType)
        try container.encode(label, forKey: .label)
        try container.encode(title, forKey: .title)
        try container.encode(value, forKey: .value)
        try container.encode(placeholderValue, forKey: .placeholderValue)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isSelected, forKey: .isSelected)
        try container.encode(frame, forKey: .frame)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(children, forKey: .children)
    }

    var cgRect: CGRect {
        CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
    }

    var isInteractive: Bool {
        guard isEnabled else { return false }

        let definitelyInteractiveTypes: Set<UInt> = [
            9,  // Button
            10, // RadioButton
            12, // CheckBox
            13, // DisclosureTriangle
            14, // PopUpButton
            15, // ComboBox
            16, // MenuButton
            17, // ToolbarButton
            33, // Slider
            37, // SegmentedControl
            38, // Picker
            39, // PickerWheel
            40, // Switch
            41, // Toggle
            42, // Link
            45, // SearchField
            49, // TextField
            50, // SecureTextField
            51, // DatePicker
            52, // TextView
            54, // MenuItem
            60, // Cell
            79, // Stepper
            80, // Tab
        ]

        if definitelyInteractiveTypes.contains(elementType) {
            return true
        }

        if elementType == 1 {
            return isLikelyInteractiveCell
        }

        return false
    }

    private var isLikelyInteractiveCell: Bool {
        let hasIdentifier = !identifier.isEmpty && !isUUIDPattern(identifier)

        let hasLabel = !label.isEmpty && label != " "
        let hasTitle = !title.isEmpty && title != " "

        guard hasIdentifier || hasLabel || hasTitle else { return false }

        let frameArea = frame.width * frame.height
        guard frameArea > 100 else { return false }  // At least 10x10 points

        guard frame.height < 500 else { return false }

        guard children.count < 20 else { return false }

        return true
    }

    private func isUUIDPattern(_ string: String) -> Bool {
        let uuidPattern = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        return string.range(of: uuidPattern, options: .regularExpression) != nil
    }

    var interactionType: InteractionType {
        guard isInteractive else { return .none }

        switch elementType {
        case 1:  // Other (custom cells/views that passed isLikelyInteractiveCell)
            return .cellInteraction
        case 9, 17:  // Button, ToolbarButton
            return .button
        case 49, 50, 45, 52:  // TextField, SecureTextField, SearchField, TextView
            return .textInput
        case 40, 41, 12:  // Switch, Toggle, CheckBox
            return .toggle
        case 42:  // Link
            return .navigation
        case 10, 11:  // RadioButton, RadioGroup
            return .selection
        case 14, 15, 38, 39:  // PopUpButton, ComboBox, Picker, PickerWheel
            return .picker
        case 33, 79:  // Slider, Stepper
            return .adjustment
        case 60:  // Cell
            return .cellInteraction
        case 80:  // Tab
            return .navigation
        default:
            return .other
        }
    }

    var allInteractiveElements: [SnapshotElement] {
        allInteractiveElements(maxDepth: 100)
    }

    func allInteractiveElements(maxDepth: Int = 100, currentDepth: Int = 0) -> [SnapshotElement] {
        guard currentDepth < maxDepth else {
            return []
        }

        var result: [SnapshotElement] = []

        if isInteractive {
            result.append(self)
        }

        for child in children {
            result.append(contentsOf: child.allInteractiveElements(
                maxDepth: maxDepth,
                currentDepth: currentDepth + 1
            ))
        }

        return result
    }

    var allElementTypes: [UInt] {
        allElementTypes(maxDepth: 100)
    }

    func allElementTypes(maxDepth: Int = 100, currentDepth: Int = 0) -> [UInt] {
        guard currentDepth < maxDepth else {
            return []
        }

        var types: [UInt] = [elementType]
        for child in children {
            types.append(contentsOf: child.allElementTypes(
                maxDepth: maxDepth,
                currentDepth: currentDepth + 1
            ))
        }
        return types
    }

    var containsWebView: Bool {
        containsWebView(maxDepth: 100)
    }

    func containsWebView(maxDepth: Int = 100, currentDepth: Int = 0) -> Bool {
        guard currentDepth < maxDepth else {
            return false
        }

        if elementType == 56 {
            return true
        }

        return children.contains {
            $0.containsWebView(maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }
    }
}

enum InteractionType: String, Codable {
    case none
    case button
    case textInput
    case toggle
    case navigation
    case selection
    case picker
    case adjustment
    case other

    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case longPress
    case doubleTap
    case coordinateTap
    case cellInteraction
}

struct FrameData: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct SizeData: Codable {
    let width: Double
    let height: Double
}

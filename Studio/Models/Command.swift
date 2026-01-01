import Foundation

enum Command: Codable {
    case captureSnapshot
    case stop
    case tap(query: ElementQuery)
    case doubleTap(query: ElementQuery)
    case longPress(query: ElementQuery, duration: TimeInterval)
    case swipe(direction: SwipeDirection, query: ElementQuery?)
    case typeText(text: String, query: ElementQuery?)
    case tapCoordinate(x: Double, y: Double)
    case swipeCoordinate(x: Double, y: Double, direction: SwipeDirection)

    enum CodingKeys: String, CodingKey {
        case type
        case query
        case duration
        case direction
        case text
        case x
        case y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "captureSnapshot":
            self = .captureSnapshot
        case "stop":
            self = .stop
        case "tap":
            let query = try container.decode(ElementQuery.self, forKey: .query)
            self = .tap(query: query)
        case "doubleTap":
            let query = try container.decode(ElementQuery.self, forKey: .query)
            self = .doubleTap(query: query)
        case "longPress":
            let query = try container.decode(ElementQuery.self, forKey: .query)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .longPress(query: query, duration: duration)
        case "swipe":
            let direction = try container.decode(SwipeDirection.self, forKey: .direction)
            let query = try container.decodeIfPresent(ElementQuery.self, forKey: .query)
            self = .swipe(direction: direction, query: query)
        case "typeText":
            let text = try container.decode(String.self, forKey: .text)
            let query = try container.decodeIfPresent(ElementQuery.self, forKey: .query)
            self = .typeText(text: text, query: query)
        case "tapCoordinate":
            let x = try container.decode(Double.self, forKey: .x)
            let y = try container.decode(Double.self, forKey: .y)
            self = .tapCoordinate(x: x, y: y)
        case "swipeCoordinate":
            let x = try container.decode(Double.self, forKey: .x)
            let y = try container.decode(Double.self, forKey: .y)
            let direction = try container.decode(SwipeDirection.self, forKey: .direction)
            self = .swipeCoordinate(x: x, y: y, direction: direction)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown command type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .captureSnapshot:
            try container.encode("captureSnapshot", forKey: .type)
        case .stop:
            try container.encode("stop", forKey: .type)
        case .tap(let query):
            try container.encode("tap", forKey: .type)
            try container.encode(query, forKey: .query)
        case .doubleTap(let query):
            try container.encode("doubleTap", forKey: .type)
            try container.encode(query, forKey: .query)
        case .longPress(let query, let duration):
            try container.encode("longPress", forKey: .type)
            try container.encode(query, forKey: .query)
            try container.encode(duration, forKey: .duration)
        case .swipe(let direction, let query):
            try container.encode("swipe", forKey: .type)
            try container.encode(direction, forKey: .direction)
            try container.encodeIfPresent(query, forKey: .query)
        case .typeText(let text, let query):
            try container.encode("typeText", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(query, forKey: .query)
        case .tapCoordinate(let x, let y):
            try container.encode("tapCoordinate", forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
        case .swipeCoordinate(let x, let y, let direction):
            try container.encode("swipeCoordinate", forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encode(direction, forKey: .direction)
        }
    }
}

struct ElementQuery: Codable {
    let identifier: String?
    let label: String?
    let title: String?
    let elementType: UInt?
    let index: Int?

    init(identifier: String? = nil, label: String? = nil, title: String? = nil, elementType: UInt? = nil, index: Int? = nil) {
        self.identifier = identifier
        self.label = label
        self.title = title
        self.elementType = elementType
        self.index = index
    }
}

enum SwipeDirection: String, Codable {
    case up
    case down
    case left
    case right
}

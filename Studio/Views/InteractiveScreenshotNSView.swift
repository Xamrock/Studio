import AppKit
import SwiftUI

class InteractiveScreenshotNSView: NSView {
    var screenshot: NSImage?
    var elements: [SnapshotElement] = []
    var filteredElements: [SnapshotElement] = []
    var hoveredElementId: UUID?
    var onElementTap: ((SnapshotElement) -> Void)?
    var onCoordinateTap: ((CGPoint) -> Void)?
    var onCoordinateSwipe: ((CGPoint, SwipeDirection) -> Void)?
    var appFrameOffset: CGPoint = .zero  // Offset from screen to app frame
    var displayScale: CGFloat = 1.0  // Display scale (points to pixels)

    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool {
        return true  // Use top-left origin like UIKit
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .mouseEnteredAndExited
        ]
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        setupTrackingArea()
    }

    func update(screenshot: NSImage?, elements: [SnapshotElement], filteredElements: [SnapshotElement], appFrameOffset: CGPoint = .zero, displayScale: CGFloat = 1.0) {
        self.screenshot = screenshot
        self.elements = elements
        self.filteredElements = filteredElements
        self.appFrameOffset = appFrameOffset
        self.displayScale = displayScale
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let screenshot = screenshot else {
            NSColor.windowBackgroundColor.setFill()
            dirtyRect.fill()
            return
        }

        let imageSize = screenshot.size
        let containerSize = bounds.size

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        let displayedSize: NSSize
        let offsetX: CGFloat
        let offsetY: CGFloat

        if containerAspect > imageAspect {
            let height = containerSize.height
            let width = height * imageAspect
            displayedSize = NSSize(width: width, height: height)
            offsetX = (containerSize.width - width) / 2
            offsetY = 0
        } else {
            let width = containerSize.width
            let height = width / imageAspect
            displayedSize = NSSize(width: width, height: height)
            offsetX = 0
            offsetY = (containerSize.height - height) / 2
        }

        let scale = displayedSize.width / imageSize.width

        let imageRect = NSRect(
            x: offsetX,
            y: offsetY,
            width: displayedSize.width,
            height: displayedSize.height
        )
        screenshot.draw(in: imageRect)

        var hoveredElement: SnapshotElement?
        var hoveredRect: NSRect?

        for (index, element) in elements.enumerated() {
            let isFiltered = !filteredElements.contains(where: { $0.id == element.id })
            let isHovered = hoveredElementId == element.id

            let frame = element.cgRect

            let pixelX = frame.origin.x * displayScale
            let pixelY = frame.origin.y * displayScale
            let pixelWidth = frame.width * displayScale
            let pixelHeight = frame.height * displayScale

            let adjustedX = pixelX - (appFrameOffset.x * displayScale)
            let adjustedY = pixelY - (appFrameOffset.y * displayScale)

            let scaledX = offsetX + (adjustedX * scale)
            let scaledY = offsetY + (adjustedY * scale)
            let scaledWidth = pixelWidth * scale
            let scaledHeight = pixelHeight * scale

            let scaledRect = NSRect(
                x: scaledX,
                y: scaledY,
                width: scaledWidth,
                height: scaledHeight
            )

            if isHovered {
                hoveredElement = element
                hoveredRect = scaledRect
                continue
            }

            if isFiltered && !filteredElements.isEmpty && filteredElements.count < elements.count {
                NSColor.black.withAlphaComponent(0.6).setFill()
                scaledRect.fill()
            } else {
                let color = colorForInteractionType(element.interactionType)

                color.withAlphaComponent(0.15).setFill()
                scaledRect.fill()

                color.setStroke()
                let path = NSBezierPath(rect: scaledRect)
                path.lineWidth = 2
                path.stroke()
            }
        }

        if let hoveredElement = hoveredElement, let hoveredRect = hoveredRect {
            let isFiltered = !filteredElements.contains(where: { $0.id == hoveredElement.id })

            if !isFiltered {
                let color = colorForInteractionType(hoveredElement.interactionType)

                color.withAlphaComponent(0.3).setFill()
                hoveredRect.fill()

                color.setStroke()
                let path = NSBezierPath(rect: hoveredRect)
                path.lineWidth = 3
                path.stroke()

                drawTooltip(for: hoveredElement, at: hoveredRect)
            }
        }
    }

    private func drawTooltip(for element: SnapshotElement, at rect: NSRect) {
        let label = elementLabel(for: element)
        let typeText = element.interactionType.rawValue

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white
        ]

        let typeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7)
        ]

        let labelSize = label.size(withAttributes: labelAttributes)
        let typeSize = typeText.size(withAttributes: typeAttributes)

        let tooltipWidth = max(labelSize.width, typeSize.width) + 16
        let tooltipHeight = labelSize.height + typeSize.height + 12

        var tooltipY = rect.maxY + 10
        if tooltipY + tooltipHeight > bounds.height {
            tooltipY = rect.minY - tooltipHeight - 10
        }

        let tooltipRect = NSRect(
            x: rect.midX - tooltipWidth / 2,
            y: tooltipY,
            width: tooltipWidth,
            height: tooltipHeight
        )

        NSColor.black.withAlphaComponent(0.8).setFill()
        let tooltipPath = NSBezierPath(roundedRect: tooltipRect, xRadius: 6, yRadius: 6)
        tooltipPath.fill()

        label.draw(at: NSPoint(x: tooltipRect.minX + 8, y: tooltipRect.maxY - labelSize.height - 6), withAttributes: labelAttributes)

        typeText.draw(at: NSPoint(x: tooltipRect.minX + 8, y: tooltipRect.minY + 6), withAttributes: typeAttributes)
    }

    private func elementLabel(for element: SnapshotElement) -> String {
        if !element.label.isEmpty {
            return element.label
        } else if !element.title.isEmpty {
            return element.title
        } else if !element.identifier.isEmpty {
            return element.identifier
        } else {
            return "(no label)"
        }
    }

    private func colorForInteractionType(_ type: InteractionType) -> NSColor {
        switch type {
        case .button: return .systemGreen
        case .textInput: return .systemBlue
        case .toggle: return .systemPurple
        case .navigation: return .systemOrange
        case .selection: return .systemIndigo
        case .picker: return .systemTeal
        case .adjustment: return .systemCyan

        case .swipeUp, .swipeDown, .swipeLeft, .swipeRight: return .systemPink
        case .longPress: return .systemRed
        case .doubleTap: return .systemMint
        case .coordinateTap: return .systemYellow
        case .cellInteraction: return .systemBrown

        case .none, .other: return .systemGray
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if event.modifierFlags.contains(.option) || event.type == .rightMouseDown {
            if let coordinate = convertToAppCoordinate(location) {
                onCoordinateTap?(coordinate)
                return
            }
        }

        if let element = element(at: location) {
            onElementTap?(element)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if let coordinate = convertToAppCoordinate(location) {
            showCoordinateMenu(at: event.locationInWindow, coordinate: coordinate)
        }
    }

    private func showCoordinateMenu(at location: NSPoint, coordinate: CGPoint) {
        let menu = NSMenu()

        let tapItem = NSMenuItem(title: "Tap at this location", action: #selector(menuTapAtCoordinate(_:)), keyEquivalent: "")
        tapItem.representedObject = coordinate
        tapItem.target = self
        menu.addItem(tapItem)

        menu.addItem(NSMenuItem.separator())

        let swipeUpItem = NSMenuItem(title: "Swipe Up from here", action: #selector(menuSwipeUp(_:)), keyEquivalent: "")
        swipeUpItem.representedObject = coordinate
        swipeUpItem.target = self
        menu.addItem(swipeUpItem)

        let swipeDownItem = NSMenuItem(title: "Swipe Down from here", action: #selector(menuSwipeDown(_:)), keyEquivalent: "")
        swipeDownItem.representedObject = coordinate
        swipeDownItem.target = self
        menu.addItem(swipeDownItem)

        let swipeLeftItem = NSMenuItem(title: "Swipe Left from here", action: #selector(menuSwipeLeft(_:)), keyEquivalent: "")
        swipeLeftItem.representedObject = coordinate
        swipeLeftItem.target = self
        menu.addItem(swipeLeftItem)

        let swipeRightItem = NSMenuItem(title: "Swipe Right from here", action: #selector(menuSwipeRight(_:)), keyEquivalent: "")
        swipeRightItem.representedObject = coordinate
        swipeRightItem.target = self
        menu.addItem(swipeRightItem)

        menu.popUp(positioning: nil, at: location, in: self)
    }

    @objc private func menuTapAtCoordinate(_ sender: NSMenuItem) {
        if let coordinate = sender.representedObject as? CGPoint {
            onCoordinateTap?(coordinate)
        }
    }

    @objc private func menuSwipeUp(_ sender: NSMenuItem) {
        if let coordinate = sender.representedObject as? CGPoint {
            onCoordinateSwipe?(coordinate, .up)
        }
    }

    @objc private func menuSwipeDown(_ sender: NSMenuItem) {
        if let coordinate = sender.representedObject as? CGPoint {
            onCoordinateSwipe?(coordinate, .down)
        }
    }

    @objc private func menuSwipeLeft(_ sender: NSMenuItem) {
        if let coordinate = sender.representedObject as? CGPoint {
            onCoordinateSwipe?(coordinate, .left)
        }
    }

    @objc private func menuSwipeRight(_ sender: NSMenuItem) {
        if let coordinate = sender.representedObject as? CGPoint {
            onCoordinateSwipe?(coordinate, .right)
        }
    }

    private func convertToAppCoordinate(_ viewLocation: NSPoint) -> CGPoint? {
        guard let screenshot = screenshot else { return nil }

        let imageSize = screenshot.size
        let containerSize = bounds.size

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        let displayedSize: NSSize
        let offsetX: CGFloat
        let offsetY: CGFloat

        if containerAspect > imageAspect {
            let height = containerSize.height
            let width = height * imageAspect
            displayedSize = NSSize(width: width, height: height)
            offsetX = (containerSize.width - width) / 2
            offsetY = 0
        } else {
            let width = containerSize.width
            let height = width / imageAspect
            displayedSize = NSSize(width: width, height: height)
            offsetX = 0
            offsetY = (containerSize.height - height) / 2
        }

        let scale = displayedSize.width / imageSize.width

        let pixelX = (viewLocation.x - offsetX) / scale
        let pixelY = (viewLocation.y - offsetY) / scale

        let pointX = pixelX / displayScale
        let pointY = pixelY / displayScale

        let appX = pointX + appFrameOffset.x
        let appY = pointY + appFrameOffset.y

        return CGPoint(x: appX, y: appY)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        let previousHovered = hoveredElementId
        hoveredElementId = element(at: location)?.id

        if previousHovered != hoveredElementId {
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredElementId != nil {
            hoveredElementId = nil
            needsDisplay = true
        }
    }

    private func element(at point: NSPoint) -> SnapshotElement? {
        guard let screenshot = screenshot else { return nil }

        let imageSize = screenshot.size
        let containerSize = bounds.size

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        let displayedSize: NSSize
        let offsetX: CGFloat
        let offsetY: CGFloat

        if containerAspect > imageAspect {
            let height = containerSize.height
            let width = height * imageAspect
            displayedSize = NSSize(width: width, height: height)
            offsetX = (containerSize.width - width) / 2
            offsetY = 0
        } else {
            let width = containerSize.width
            let height = width / imageAspect
            displayedSize = NSSize(width: width, height: height)
            offsetX = 0
            offsetY = (containerSize.height - height) / 2
        }

        let scale = displayedSize.width / imageSize.width

        for element in filteredElements.reversed() {
            let frame = element.cgRect

            let pixelX = frame.origin.x * displayScale
            let pixelY = frame.origin.y * displayScale
            let pixelWidth = frame.width * displayScale
            let pixelHeight = frame.height * displayScale

            let adjustedX = pixelX - (appFrameOffset.x * displayScale)
            let adjustedY = pixelY - (appFrameOffset.y * displayScale)

            let scaledX = offsetX + (adjustedX * scale)
            let scaledY = offsetY + (adjustedY * scale)
            let scaledWidth = pixelWidth * scale
            let scaledHeight = pixelHeight * scale

            let scaledRect = NSRect(
                x: scaledX,
                y: scaledY,
                width: scaledWidth,
                height: scaledHeight
            )

            if scaledRect.contains(point) {
                return element
            }
        }

        return nil
    }
}

struct InteractiveScreenshotViewAppKit: NSViewRepresentable {
    let screenshot: NSImage?
    let elements: [SnapshotElement]
    let filteredElements: [SnapshotElement]
    let appFrameOffset: CGPoint
    let displayScale: CGFloat
    @Binding var hoveredElementId: UUID?
    let onElementTap: (SnapshotElement) -> Void
    let onCoordinateTap: (CGPoint) -> Void
    let onCoordinateSwipe: (CGPoint, SwipeDirection) -> Void

    func makeNSView(context: Context) -> InteractiveScreenshotNSView {
        let view = InteractiveScreenshotNSView()
        view.onElementTap = onElementTap
        view.onCoordinateTap = onCoordinateTap
        view.onCoordinateSwipe = onCoordinateSwipe
        return view
    }

    func updateNSView(_ nsView: InteractiveScreenshotNSView, context: Context) {
        nsView.update(screenshot: screenshot, elements: elements, filteredElements: filteredElements, appFrameOffset: appFrameOffset, displayScale: displayScale)
        nsView.hoveredElementId = hoveredElementId

        nsView.onElementTap = onElementTap
        nsView.onCoordinateTap = onCoordinateTap
        nsView.onCoordinateSwipe = onCoordinateSwipe

        if nsView.hoveredElementId != hoveredElementId {
            DispatchQueue.main.async {
                hoveredElementId = nsView.hoveredElementId
            }
        }
    }
}

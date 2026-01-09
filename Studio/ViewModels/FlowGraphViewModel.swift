import SwiftUI
import Combine

protocol UndoRedoStateManaging {
    func captureState(screens: [CapturedScreen], edges: [NavigationEdge])
}

@MainActor
class FlowGraphViewModel: ObservableObject, UndoRedoStateManaging {
    @Published var zoom: CGFloat = 1.0
    @Published var offset: CGPoint = .zero
    @Published var selectedNodeIds: Set<UUID> = []
    @Published var selectedEdgeId: UUID?

    @Published var currentTool: CanvasTool = .select
    @Published var showMinimap: Bool = true
    @Published var showGrid: Bool = true

    @Published var edgeCreationSourceId: UUID?
    @Published var edgeCreationTargetId: UUID?
    @Published var showEdgeCreationSheet: Bool = false

    @Published var editingEdge: NavigationEdge?
    @Published var showEdgeEditSheet: Bool = false

    @Published var editingScreenId: UUID?
    @Published var showEditScreenNameSheet: Bool = false

    private var undoStack: [GraphSnapshot] = []
    private var redoStack: [GraphSnapshot] = []
    private let maxUndoStackSize = 50

    enum CanvasTool {
        case select
        case pan
        case addEdge
    }

    struct GraphSnapshot {
        let screens: [CapturedScreen]
        let edges: [NavigationEdge]
        let timestamp: Date

        init(screens: [CapturedScreen], edges: [NavigationEdge], timestamp: Date = Date()) {
            self.screens = screens
            self.edges = edges
            self.timestamp = timestamp
        }
    }

    func handleNodeClickForEdgeCreation(screenId: UUID) {
        if edgeCreationSourceId == nil {
            edgeCreationSourceId = screenId
        } else if edgeCreationSourceId == screenId {
            cancelEdgeCreation()
        } else {
            edgeCreationTargetId = screenId
            showEdgeCreationSheet = true
        }
    }

    func cancelEdgeCreation() {
        edgeCreationSourceId = nil
        edgeCreationTargetId = nil
        currentTool = .select
    }

    func resetEdgeCreation() {
        edgeCreationSourceId = nil
        edgeCreationTargetId = nil
    }


    func initializePositions(screens: inout [CapturedScreen], edges: [NavigationEdge]) {
        let hasPositions = screens.contains { $0.graphPosition != nil }

        if !hasPositions && !screens.isEmpty {
            applyHierarchicalLayout(screens: &screens, edges: edges)
        }
    }

    func applyHierarchicalLayout(screens: inout [CapturedScreen], edges: [NavigationEdge]) {
        let spacing: CGFloat = 300
        let verticalSpacing: CGFloat = 280
        let columns = 3

        for index in screens.indices {
            let col = index % columns
            let row = index / columns

            let newPosition = CGPoint(
                x: CGFloat(col) * spacing + 400,
                y: CGFloat(row) * verticalSpacing + 200
            )

            screens[index].graphPosition = newPosition
        }

        zoom = 1.0
        offset = .zero
    }

    func screenToCanvas(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: (point.x - offset.x) / zoom,
            y: (point.y - offset.y) / zoom
        )
    }

    func canvasToScreen(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * zoom + offset.x,
            y: point.y * zoom + offset.y
        )
    }

    func selectNode(id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            selectedNodeIds.insert(id)
        } else {
            selectedNodeIds = [id]
        }
    }

    func deselectAll() {
        selectedNodeIds.removeAll()
        selectedEdgeId = nil
    }

    func showEditNameDialog(for screenId: UUID) {
        editingScreenId = screenId
        showEditScreenNameSheet = true
    }

    func selectAndEditEdge(_ edge: NavigationEdge) {
        selectedEdgeId = edge.id
        editingEdge = edge
        showEdgeEditSheet = true
    }

    func captureState(screens: [CapturedScreen], edges: [NavigationEdge]) {
        let snapshot = GraphSnapshot(screens: screens, edges: edges)

        undoStack.append(snapshot)

        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }

        redoStack.removeAll()
    }

    func canUndo() -> Bool {
        return !undoStack.isEmpty
    }

    func canRedo() -> Bool {
        return !redoStack.isEmpty
    }

    func undo(currentScreens: [CapturedScreen], currentEdges: [NavigationEdge]) -> (screens: [CapturedScreen], edges: [NavigationEdge])? {
        guard !undoStack.isEmpty else { return nil }

        let currentSnapshot = GraphSnapshot(screens: currentScreens, edges: currentEdges)
        redoStack.append(currentSnapshot)

        let previousSnapshot = undoStack.removeLast()
        return (screens: previousSnapshot.screens, edges: previousSnapshot.edges)
    }

    func redo() -> (screens: [CapturedScreen], edges: [NavigationEdge])? {
        guard !redoStack.isEmpty else { return nil }

        let nextSnapshot = redoStack.removeLast()
        return (screens: nextSnapshot.screens, edges: nextSnapshot.edges)
    }

    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    func detectDropTarget(
        draggedScreenId: UUID,
        draggedPosition: CGPoint,
        screens: [CapturedScreen],
        nodeWidth: CGFloat = 180,
        nodeHeight: CGFloat = 260,
        defaultPositionProvider: (CapturedScreen) -> CGPoint
    ) -> UUID? {
        let draggedBounds = CGRect(
            x: draggedPosition.x - nodeWidth / 2,
            y: draggedPosition.y - nodeHeight / 2,
            width: nodeWidth,
            height: nodeHeight
        )

        for screen in screens {
            guard screen.id != draggedScreenId else { continue }

            let screenPos = screen.graphPosition ?? defaultPositionProvider(screen)
            let screenBounds = CGRect(
                x: screenPos.x - nodeWidth / 2,
                y: screenPos.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )

            if draggedBounds.intersects(screenBounds) {
                return screen.id
            }
        }

        return nil
    }
}

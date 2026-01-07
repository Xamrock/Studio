import SwiftUI
import Combine

@MainActor
class FlowGraphViewModel: ObservableObject {
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
        let snapshot = GraphSnapshot(
            screens: screens,
            edges: edges,
            timestamp: Date()
        )

        undoStack.append(snapshot)

        // Limit stack size to prevent memory issues
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }

        // Clear redo stack when new action is performed
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

        // Save current state to redo stack
        let currentSnapshot = GraphSnapshot(
            screens: currentScreens,
            edges: currentEdges,
            timestamp: Date()
        )
        redoStack.append(currentSnapshot)

        // Pop from undo stack
        let previousSnapshot = undoStack.removeLast()
        return (screens: previousSnapshot.screens, edges: previousSnapshot.edges)
    }

    func redo() -> (screens: [CapturedScreen], edges: [NavigationEdge])? {
        guard !redoStack.isEmpty else { return nil }

        // Pop from redo stack
        let nextSnapshot = redoStack.removeLast()
        return (screens: nextSnapshot.screens, edges: nextSnapshot.edges)
    }

    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

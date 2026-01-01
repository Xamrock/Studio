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

    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []

    enum CanvasTool {
        case select
        case pan
        case addEdge
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

    struct GraphState {
        let positions: [UUID: CGPoint]
        let zoom: CGFloat
        let offset: CGPoint
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

    func undo() {
        guard !undoStack.isEmpty else { return }
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
    }
}

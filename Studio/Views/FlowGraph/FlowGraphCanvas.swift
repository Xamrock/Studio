import SwiftUI

struct FlowGraphCanvas: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @ObservedObject var graphViewModel: FlowGraphViewModel
    @Binding var selectedScreen: CapturedScreen?

    @State private var startOffset: CGPoint = .zero
    @State private var startZoom: CGFloat = 1.0
    @State private var draggedScreenId: UUID?
    @State private var dragStartPosition: CGPoint = .zero
    @State private var dropTargetId: UUID?

    var body: some View {
        GeometryReader { geometry in
            ScrollableCanvas(onScroll: { deltaX, deltaY in
                graphViewModel.offset.x += deltaX
                graphViewModel.offset.y += deltaY
            }) {
                canvasContent(geometry: geometry)
            }
        }
    }

    @ViewBuilder
    private func canvasContent(geometry: GeometryProxy) -> some View {
        ZStack {
                Canvas { context, size in
                    if graphViewModel.showGrid {
                        drawGrid(context: context, size: size)
                    }
                }

                Canvas { context, size in
                    for edge in viewModel.navigationEdges {
                        if let source = viewModel.capturedScreens.first(where: { $0.id == edge.sourceScreenId }),
                           let target = viewModel.capturedScreens.first(where: { $0.id == edge.targetScreenId }) {
                            drawEdge(
                                context: context,
                                edge: edge,
                                source: source,
                                target: target,
                                isSelected: graphViewModel.selectedEdgeId == edge.id,
                                zoom: graphViewModel.zoom,
                                offset: graphViewModel.offset
                            )
                        }
                    }
                }

                ForEach(viewModel.navigationEdges) { edge in
                    if let source = viewModel.capturedScreens.first(where: { $0.id == edge.sourceScreenId }),
                       let target = viewModel.capturedScreens.first(where: { $0.id == edge.targetScreenId }) {
                        edgeLabelView(for: edge, source: source, target: target)
                    }
                }

                ForEach(viewModel.capturedScreens) { screen in
                    let position = screen.graphPosition ?? defaultPosition(for: screen, in: geometry.size)

                    let flowGroups = viewModel.flowGroups.filter { group in
                        screen.flowGroupIds.contains(group.id)
                    }

                    FlowGraphNode(
                        screen: screen,
                        isSelected: graphViewModel.selectedNodeIds.contains(screen.id),
                        isEdgeCreationSource: graphViewModel.edgeCreationSourceId == screen.id,
                        isDropTarget: dropTargetId == screen.id,
                        flowGroups: flowGroups,
                        onTap: {
                            if graphViewModel.currentTool == .addEdge {
                                graphViewModel.handleNodeClickForEdgeCreation(screenId: screen.id)
                            } else {
                                graphViewModel.selectNode(id: screen.id)
                                selectedScreen = screen
                            }
                        },
                        onDelete: {
                            deleteScreen(screen)
                        },
                        onAssignToGroup: { group in
                            assignScreenToGroup(screen, group: group)
                        },
                        onRemoveFromGroup: { group in
                            removeScreenFromGroup(screen, group: group)
                        },
                        onEditName: {
                            graphViewModel.showEditNameDialog(for: screen.id)
                        },
                        availableGroups: viewModel.flowGroups
                    )
                    .scaleEffect(graphViewModel.zoom)
                    .position(
                        x: position.x * graphViewModel.zoom + graphViewModel.offset.x,
                        y: position.y * graphViewModel.zoom + graphViewModel.offset.y
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if graphViewModel.currentTool == .select {
                                    if draggedScreenId != screen.id {
                                        draggedScreenId = screen.id
                                        dragStartPosition = screen.graphPosition ?? defaultPosition(for: screen, in: geometry.size)
                                    }

                                    updateScreenPosition(
                                        screenId: screen.id,
                                        startPosition: dragStartPosition,
                                        translation: value.translation
                                    )

                                    // Check for drop target (node overlap)
                                    if let draggedId = draggedScreenId,
                                       let draggedScreen = viewModel.capturedScreens.first(where: { $0.id == draggedId }) {
                                        let draggedPos = draggedScreen.graphPosition ?? defaultPosition(for: draggedScreen, in: geometry.size)
                                        dropTargetId = detectDropTarget(
                                            draggedScreenId: draggedId,
                                            draggedPosition: draggedPos,
                                            geometry: geometry
                                        )
                                    }
                                }
                            }
                            .onEnded { _ in
                                if let draggedId = draggedScreenId, let targetId = dropTargetId {
                                    viewModel.mergeNodes(draggedNodeId: draggedId, targetNodeId: targetId, graphViewModel: graphViewModel)
                                }
                                draggedScreenId = nil
                                dropTargetId = nil
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: graphViewModel.currentTool == .pan ? 5 : 100)
                    .onChanged { value in
                        let isDraggingNode = graphViewModel.currentTool == .select && draggedScreenId != nil

                        if !isDraggingNode && (graphViewModel.currentTool == .pan || value.translation.width.magnitude > 20 || value.translation.height.magnitude > 20) {
                            graphViewModel.offset.x = startOffset.x + value.translation.width
                            graphViewModel.offset.y = startOffset.y + value.translation.height
                        }
                    }
                    .onEnded { _ in
                        startOffset = graphViewModel.offset
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newZoom = startZoom * value
                        graphViewModel.zoom = max(0.25, min(4.0, newZoom))
                    }
                    .onEnded { value in
                        let newZoom = startZoom * value
                        graphViewModel.zoom = max(0.25, min(4.0, newZoom))
                        startZoom = graphViewModel.zoom
                    }
            )
            .onAppear {
                startOffset = graphViewModel.offset
                startZoom = graphViewModel.zoom
            }
            .onTapGesture { location in
                graphViewModel.deselectAll()
            }
            .onDeleteCommand {
                // Delete selected nodes
                for nodeId in graphViewModel.selectedNodeIds {
                    if let screen = viewModel.capturedScreens.first(where: { $0.id == nodeId }) {
                        deleteScreen(screen)
                    }
                }
            }
        }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 20
        let dotSize: CGFloat = 1.5

        var path = Path()

        let visibleWidth = size.width / graphViewModel.zoom
        let visibleHeight = size.height / graphViewModel.zoom
        let startX = -graphViewModel.offset.x / graphViewModel.zoom
        let startY = -graphViewModel.offset.y / graphViewModel.zoom

        let cols = Int(visibleWidth / gridSpacing) + 2
        let rows = Int(visibleHeight / gridSpacing) + 2

        for x in 0..<cols {
            for y in 0..<rows {
                let dotX = startX + CGFloat(x) * gridSpacing
                let dotY = startY + CGFloat(y) * gridSpacing

                path.addEllipse(in: CGRect(
                    x: dotX * graphViewModel.zoom + graphViewModel.offset.x - dotSize / 2,
                    y: dotY * graphViewModel.zoom + graphViewModel.offset.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                ))
            }
        }

        context.fill(path, with: .color(.gray.opacity(0.3)))
    }

    private func drawEdge(
        context: GraphicsContext,
        edge: NavigationEdge,
        source: CapturedScreen,
        target: CapturedScreen,
        isSelected: Bool,
        zoom: CGFloat,
        offset: CGPoint
    ) {
        let sourcePos = source.graphPosition ?? CGPoint(x: 400, y: 200)
        let targetPos = target.graphPosition ?? CGPoint(x: 700, y: 200)

        let transformedSource = CGPoint(
            x: sourcePos.x * zoom + offset.x,
            y: sourcePos.y * zoom + offset.y
        )
        let transformedTarget = CGPoint(
            x: targetPos.x * zoom + offset.x,
            y: targetPos.y * zoom + offset.y
        )

        var path = Path()
        path.move(to: transformedSource)

        let controlPoint1 = CGPoint(
            x: transformedSource.x + (transformedTarget.x - transformedSource.x) / 2,
            y: transformedSource.y
        )
        let controlPoint2 = CGPoint(
            x: transformedSource.x + (transformedTarget.x - transformedSource.x) / 2,
            y: transformedTarget.y
        )

        path.addCurve(
            to: transformedTarget,
            control1: controlPoint1,
            control2: controlPoint2
        )

        let edgeColor = colorForInteractionType(edge.interactionType)
        let lineWidth: CGFloat = (isSelected ? 4 : 2) * zoom

        context.stroke(
            path,
            with: .color(edgeColor),
            style: StrokeStyle(lineWidth: max(1, lineWidth), lineCap: .round)
        )

        drawArrow(
            context: context,
            at: transformedTarget,
            angle: angleToTarget(from: transformedSource, to: transformedTarget),
            color: edgeColor,
            size: 12 * zoom
        )

    }

    private func drawArrow(context: GraphicsContext, at point: CGPoint, angle: Double, color: Color, size: CGFloat) {
        let arrowSize = max(6, size)

        var path = Path()
        path.move(to: point)
        path.addLine(to: CGPoint(
            x: point.x - arrowSize * cos(angle - .pi / 6),
            y: point.y - arrowSize * sin(angle - .pi / 6)
        ))
        path.move(to: point)
        path.addLine(to: CGPoint(
            x: point.x - arrowSize * cos(angle + .pi / 6),
            y: point.y - arrowSize * sin(angle + .pi / 6)
        ))

        context.stroke(path, with: .color(color), lineWidth: 2)
    }

    private func angleToTarget(from source: CGPoint, to target: CGPoint) -> Double {
        return atan2(target.y - source.y, target.x - source.x)
    }

    private func colorForInteractionType(_ type: InteractionType) -> Color {
        switch type {
        case .button: return .green
        case .textInput: return .blue
        case .toggle: return .purple
        case .navigation: return .orange
        case .selection: return .indigo
        case .picker: return .teal
        case .adjustment: return .cyan

        case .swipeUp, .swipeDown, .swipeLeft, .swipeRight: return .pink
        case .longPress: return .red
        case .doubleTap: return .mint
        case .coordinateTap: return .yellow
        case .cellInteraction: return .brown

        case .none, .other: return .gray
        }
    }

    private func defaultPosition(for screen: CapturedScreen, in size: CGSize) -> CGPoint {
        if let index = viewModel.capturedScreens.firstIndex(where: { $0.id == screen.id }) {
            let col = index % 3
            let row = index / 3
            return CGPoint(
                x: CGFloat(col) * 300 + 400,
                y: CGFloat(row) * 280 + 200
            )
        }
        return CGPoint(x: 400, y: 200)
    }

    private func updateScreenPosition(screenId: UUID, startPosition: CGPoint, translation: CGSize) {
        if let index = viewModel.capturedScreens.firstIndex(where: { $0.id == screenId }) {
            let newPos = CGPoint(
                x: startPosition.x + translation.width / graphViewModel.zoom,
                y: startPosition.y + translation.height / graphViewModel.zoom
            )

            viewModel.capturedScreens[index].graphPosition = newPos
        }
    }

    private func detectDropTarget(draggedScreenId: UUID, draggedPosition: CGPoint, geometry: GeometryProxy) -> UUID? {
        let nodeWidth: CGFloat = 180
        let nodeHeight: CGFloat = 260

        // Calculate dragged node bounds (in canvas coordinates)
        let draggedBounds = CGRect(
            x: draggedPosition.x - nodeWidth / 2,
            y: draggedPosition.y - nodeHeight / 2,
            width: nodeWidth,
            height: nodeHeight
        )

        // Check for overlap with other nodes
        for screen in viewModel.capturedScreens {
            guard screen.id != draggedScreenId else { continue }

            let screenPos = screen.graphPosition ?? defaultPosition(for: screen, in: geometry.size)
            let screenBounds = CGRect(
                x: screenPos.x - nodeWidth / 2,
                y: screenPos.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )

            // Check if bounds intersect (with some threshold for better UX)
            if draggedBounds.intersects(screenBounds) {
                return screen.id
            }
        }

        return nil
    }

    @ViewBuilder
    private func edgeLabelView(for edge: NavigationEdge, source: CapturedScreen, target: CapturedScreen) -> some View {
        let sourcePos = source.graphPosition ?? CGPoint(x: 400, y: 200)
        let targetPos = target.graphPosition ?? CGPoint(x: 700, y: 200)

        let midX = (sourcePos.x + targetPos.x) / 2
        let midY = (sourcePos.y + targetPos.y) / 2

        let screenPos = CGPoint(
            x: midX * graphViewModel.zoom + graphViewModel.offset.x,
            y: midY * graphViewModel.zoom + graphViewModel.offset.y
        )

        Button {
            graphViewModel.selectAndEditEdge(edge)
        } label: {
            Text(edge.elementLabel)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForInteractionType(edge.interactionType).opacity(0.9))
                )
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(graphViewModel.zoom)
        .position(screenPos)
    }

    private func deleteScreen(_ screen: CapturedScreen) {
        // Capture state before deletion for undo functionality
        graphViewModel.captureState(screens: viewModel.capturedScreens, edges: viewModel.navigationEdges)

        viewModel.capturedScreens.removeAll { $0.id == screen.id }

        viewModel.navigationEdges.removeAll { edge in
            edge.sourceScreenId == screen.id || edge.targetScreenId == screen.id
        }

        graphViewModel.selectedNodeIds.remove(screen.id)
        if selectedScreen?.id == screen.id {
            selectedScreen = nil
        }

    }

    private func assignScreenToGroup(_ screen: CapturedScreen, group: FlowGroup) {
        viewModel.assignScreenToFlowGroup(screenId: screen.id, groupId: group.id)
    }

    private func removeScreenFromGroup(_ screen: CapturedScreen, group: FlowGroup) {
        viewModel.removeScreenFromFlowGroup(screenId: screen.id, groupId: group.id)
    }
}

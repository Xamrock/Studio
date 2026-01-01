import SwiftUI

struct FlowSection: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?

    @StateObject private var graphViewModel = FlowGraphViewModel()
    @State private var showFlowGroupsPanel = true

    var body: some View {
        VStack(spacing: 0) {
            FlowTopBar(
                graphViewModel: graphViewModel,
                viewModel: viewModel,
                showFlowGroupsPanel: $showFlowGroupsPanel,
                onAutoLayout: {
                    graphViewModel.applyHierarchicalLayout(
                        screens: &viewModel.capturedScreens,
                        edges: viewModel.navigationEdges
                    )
                }
            )

            HSplitView {
                FlowGraphCanvas(
                    viewModel: viewModel,
                    graphViewModel: graphViewModel,
                    selectedScreen: $selectedScreen
                )
                .onAppear {
                    graphViewModel.initializePositions(
                        screens: &viewModel.capturedScreens,
                        edges: viewModel.navigationEdges
                    )
                }
                .sheet(isPresented: $graphViewModel.showEdgeCreationSheet) {
                    EdgeCreationSheet(
                        viewModel: viewModel,
                        graphViewModel: graphViewModel,
                        isPresented: $graphViewModel.showEdgeCreationSheet
                    )
                }
                .sheet(isPresented: $graphViewModel.showEdgeEditSheet) {
                    if let edge = graphViewModel.editingEdge {
                        EdgeEditSheet(
                            viewModel: viewModel,
                            edge: edge,
                            isPresented: $graphViewModel.showEdgeEditSheet
                        )
                    }
                }
                .sheet(isPresented: $graphViewModel.showEditScreenNameSheet) {
                    if let screenId = graphViewModel.editingScreenId {
                        EditScreenNameSheet(
                            viewModel: viewModel,
                            screenId: screenId,
                            isPresented: $graphViewModel.showEditScreenNameSheet
                        )
                    }
                }

                if showFlowGroupsPanel {
                    FlowGroupsPanel(viewModel: viewModel)
                }
            }
        }
    }
}

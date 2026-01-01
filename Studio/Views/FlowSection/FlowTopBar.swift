import SwiftUI

struct FlowTopBar: View {
    @ObservedObject var graphViewModel: FlowGraphViewModel
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var showFlowGroupsPanel: Bool
    let onAutoLayout: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ToolbarButton(
                icon: "arrow.up.left.and.arrow.down.right",
                label: "Select",
                isSelected: graphViewModel.currentTool == .select,
                tooltip: "Select Tool (V)"
            ) {
                graphViewModel.currentTool = .select
            }

            ToolbarButton(
                icon: "arrow.triangle.branch",
                label: "Add Edge",
                isSelected: graphViewModel.currentTool == .addEdge,
                tooltip: "Add Edge Tool (E)"
            ) {
                graphViewModel.currentTool = .addEdge
            }

            Divider()
                .frame(height: 20)

            Button {
                showFlowGroupsPanel.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showFlowGroupsPanel ? "sidebar.right" : "sidebar.left")
                    Text("Flow Groups")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .help("Toggle flow groups panel")

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.callout)
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

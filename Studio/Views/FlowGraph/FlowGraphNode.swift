import SwiftUI

struct FlowGraphNode: View {
    let screen: CapturedScreen
    let isSelected: Bool
    var isEdgeCreationSource: Bool = false
    var isDropTarget: Bool = false
    var flowGroups: [FlowGroup] = []  // Multiple groups supported
    let onTap: () -> Void
    let onDelete: () -> Void
    let onAssignToGroup: (FlowGroup) -> Void
    let onRemoveFromGroup: (FlowGroup) -> Void  // Now specifies which group to remove
    let onEditName: () -> Void
    let availableGroups: [FlowGroup]

    @State private var isDragging = false

    // Computed properties for styling
    private var strokeColor: Color {
        if isDropTarget { return .green }
        if isEdgeCreationSource { return .orange }
        if isSelected { return .blue }
        return flowGroups.first?.color.color.opacity(0.6) ?? Color.gray.opacity(0.3)
    }

    private var strokeWidth: CGFloat {
        if isDropTarget { return 5 }
        if isEdgeCreationSource { return 4 }
        if isSelected { return 3 }
        return flowGroups.isEmpty ? 1 : 2
    }

    private var shadowColor: Color {
        if isDropTarget { return Color.green.opacity(0.8) }
        if isEdgeCreationSource { return Color.orange.opacity(0.4) }
        return flowGroups.first?.color.color.opacity(0.2) ?? Color.black.opacity(0.1)
    }

    private var shadowRadius: CGFloat {
        if isDropTarget { return 20 }
        if isEdgeCreationSource { return 12 }
        if isSelected { return 8 }
        return flowGroups.isEmpty ? 4 : 6
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "iphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                nodeMenu
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))

            Group {
                if let screenshot = screen.screenshot {
                    Image(nsImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }
            }
            .padding(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(screen.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(screen.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                if !screen.snapshot.elements.isEmpty {
                    let interactiveCount = screen.snapshot.elements.flatMap { $0.allInteractiveElements }.count
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.caption2)
                        Text("\(interactiveCount) interactions")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(width: 180, height: 260)
        .background(
            Group {
                if let primaryGroup = flowGroups.first {
                    primaryGroup.color.color.opacity(0.05)
                } else {
                    Color(NSColor.controlBackgroundColor)
                }
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            if flowGroups.count > 1 {
                HStack(spacing: 3) {
                    ForEach(flowGroups.dropFirst().prefix(3)) { group in
                        Circle()
                            .fill(group.color.color)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                    }
                    if flowGroups.count > 4 {
                        Text("+\(flowGroups.count - 4)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }
                }
                .padding(8)
            }
        }
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            if !availableGroups.isEmpty {
                Menu("Add to Flow Group") {
                    ForEach(availableGroups) { group in
                        Button {
                            onAssignToGroup(group)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(group.color.color)
                                    .frame(width: 12, height: 12)
                                Text(group.name)
                                Spacer()
                                if flowGroups.contains(where: { $0.id == group.id }) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            if !flowGroups.isEmpty {
                if flowGroups.count == 1, let group = flowGroups.first {
                    Button("Remove from \(group.name)") {
                        onRemoveFromGroup(group)
                    }
                } else {
                    Menu("Remove from Group") {
                        ForEach(flowGroups) { group in
                            Button("Remove from \(group.name)") {
                                onRemoveFromGroup(group)
                            }
                        }
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Screen", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var nodeMenu: some View {
        Menu {
            Button {
                onEditName()
            } label: {
                Label("Edit Name", systemImage: "pencil")
            }

            Divider()

            if !availableGroups.isEmpty {
                Menu("Add to Flow Group") {
                    ForEach(availableGroups) { group in
                        Button {
                            onAssignToGroup(group)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(group.color.color)
                                    .frame(width: 12, height: 12)
                                Text(group.name)
                                Spacer()
                                if flowGroups.contains(where: { $0.id == group.id }) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            if !flowGroups.isEmpty {
                if flowGroups.count == 1, let group = flowGroups.first {
                    Button("Remove from \(group.name)") {
                        onRemoveFromGroup(group)
                    }
                } else {
                    Menu("Remove from Group") {
                        ForEach(flowGroups) { group in
                            Button("Remove from \(group.name)") {
                                onRemoveFromGroup(group)
                            }
                        }
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Screen", systemImage: "trash")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

import SwiftUI

struct FlowGroupsPanel: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @State private var showingCreateGroup = false
    @State private var editingGroup: FlowGroup?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Flow Groups")
                    .font(.headline)
                Spacer()
                Button {
                    showingCreateGroup = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("Create new flow group")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if viewModel.flowGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Flow Groups")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Create flow groups to organize your screens into logical user flows for test generation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.flowGroups) { group in
                            FlowGroupCard(
                                group: group,
                                viewModel: viewModel,
                                onEdit: {
                                    editingGroup = group
                                },
                                onDelete: {
                                    deleteGroup(group)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 220, idealWidth: 250, maxWidth: 280)
        .sheet(isPresented: $showingCreateGroup) {
            FlowGroupEditSheet(
                viewModel: viewModel,
                isPresented: $showingCreateGroup
            )
        }
        .sheet(item: $editingGroup) { group in
            FlowGroupEditSheet(
                viewModel: viewModel,
                group: group,
                isPresented: Binding(
                    get: { editingGroup != nil },
                    set: { if !$0 { editingGroup = nil } }
                )
            )
        }
    }

    private func deleteGroup(_ group: FlowGroup) {
        viewModel.deleteFlowGroup(id: group.id)
    }
}

struct FlowGroupCard: View {
    let group: FlowGroup
    @ObservedObject var viewModel: RecordingSessionViewModel
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = true

    var screensInGroup: [CapturedScreen] {
        viewModel.capturedScreens.filter { screen in
            screen.flowGroupIds.contains(group.id)
        }
    }

    var sharedScreensCount: Int {
        screensInGroup.filter { screen in
            screen.flowGroupIds.count > 1
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.borderless)

                Circle()
                    .fill(group.color.color)
                    .frame(width: 12, height: 12)

                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(screensInGroup.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    if sharedScreensCount > 0 {
                        Text("\(sharedScreensCount) shared")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(3)
                    }
                }

                Menu {
                    Button("Edit") {
                        onEdit()
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isExpanded {
                VStack(spacing: 4) {
                    if screensInGroup.isEmpty {
                        Text("No screens in this flow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.vertical, 8)
                    } else {
                        ForEach(screensInGroup) { screen in
                            HStack(spacing: 8) {
                                Image(systemName: "iphone")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text(screen.name)
                                    .font(.caption)
                                    .lineLimit(1)

                                if screen.flowGroupIds.count > 1 {
                                    Text("\(screen.flowGroupIds.count)")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(
                                            Circle()
                                                .fill(Color.orange.opacity(0.2))
                                        )
                                        .help("In \(screen.flowGroupIds.count) flow groups")
                                }

                                Spacer()

                                Button {
                                    removeScreenFromGroup(screen)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Remove from group")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(group.color.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func removeScreenFromGroup(_ screen: CapturedScreen) {
        viewModel.removeScreenFromFlowGroup(screenId: screen.id, groupId: group.id)
    }
}

struct FlowGroupEditSheet: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    var group: FlowGroup? // nil = create new
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var selectedColor: FlowGroup.FlowColor = .blue
    @State private var selectedScreenIds: Set<UUID> = []

    var isCreating: Bool {
        group == nil
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Flow Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Color", selection: $selectedColor) {
                        ForEach(FlowGroup.FlowColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.rawValue.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Screens (\(selectedScreenIds.count) selected)") {
                    if viewModel.capturedScreens.isEmpty {
                        Text("No screens captured yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        List(viewModel.capturedScreens, selection: $selectedScreenIds) { screen in
                            HStack {
                                Image(systemName: "iphone")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(screen.name)
                                    .font(.body)
                            }
                            .tag(screen.id)
                        }
                        .frame(height: 200)
                    }
                }

                Section {
                    Button {
                        saveGroup()
                    } label: {
                        HStack {
                            Image(systemName: isCreating ? "folder.badge.plus" : "checkmark")
                            Text(isCreating ? "Create Flow Group" : "Save Changes")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isCreating ? "New Flow Group" : "Edit Flow Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            if let group = group {
                name = group.name
                selectedColor = group.color

                selectedScreenIds = Set(
                    viewModel.capturedScreens
                        .filter { $0.flowGroupIds.contains(group.id) }
                        .map { $0.id }
                )
            }
        }
    }

    private func saveGroup() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingGroup = group {
            viewModel.updateFlowGroup(
                id: existingGroup.id,
                name: trimmedName,
                color: selectedColor
            )
            viewModel.updateFlowGroupScreenAssignments(
                groupId: existingGroup.id,
                screenIds: selectedScreenIds
            )
        } else {
            viewModel.createFlowGroup(
                name: trimmedName,
                color: selectedColor,
                screenIds: selectedScreenIds
            )
        }

        isPresented = false
    }
}

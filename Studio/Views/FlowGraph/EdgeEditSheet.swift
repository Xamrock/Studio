import SwiftUI

struct EdgeEditSheet: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    let edge: NavigationEdge
    @Binding var isPresented: Bool

    @State private var edgeLabel: String = ""
    @State private var selectedInteractionType: InteractionType = .button
    @State private var duration: Double = 1.0  // For long press
    @State private var coordinateX: Double = 0.5  // For coordinate tap
    @State private var coordinateY: Double = 0.5  // For coordinate tap
    @State private var cellIndex: Int = 0  // For cell interaction

    var sourceScreen: CapturedScreen? {
        viewModel.capturedScreens.first { $0.id == edge.sourceScreenId }
    }

    var targetScreen: CapturedScreen? {
        viewModel.capturedScreens.first { $0.id == edge.targetScreenId }
    }

    var canSave: Bool {
        !edgeLabel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(sourceScreen?.name ?? "Unknown")
                                .font(.body)
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(targetScreen?.name ?? "Unknown")
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Edge Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interaction Description")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("e.g., \"Tap Login Button\"", text: $edgeLabel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Picker("Interaction Type", selection: $selectedInteractionType) {
                        Label("Button Tap", systemImage: "hand.tap").tag(InteractionType.button)
                        Label("Text Input", systemImage: "keyboard").tag(InteractionType.textInput)
                        Label("Toggle", systemImage: "switch.2").tag(InteractionType.toggle)
                        Label("Navigation", systemImage: "arrow.right.circle").tag(InteractionType.navigation)
                        Label("Selection", systemImage: "checkmark.circle").tag(InteractionType.selection)
                        Label("Picker", systemImage: "list.bullet").tag(InteractionType.picker)

                        Divider()

                        Label("Swipe Up", systemImage: "arrow.up").tag(InteractionType.swipeUp)
                        Label("Swipe Down", systemImage: "arrow.down").tag(InteractionType.swipeDown)
                        Label("Swipe Left", systemImage: "arrow.left").tag(InteractionType.swipeLeft)
                        Label("Swipe Right", systemImage: "arrow.right").tag(InteractionType.swipeRight)
                        Label("Long Press", systemImage: "hand.point.up.left.and.text").tag(InteractionType.longPress)
                        Label("Double Tap", systemImage: "hand.tap.fill").tag(InteractionType.doubleTap)
                        Label("Coordinate Tap", systemImage: "hand.point.up.left").tag(InteractionType.coordinateTap)
                        Label("Cell Interaction", systemImage: "list.dash").tag(InteractionType.cellInteraction)

                        Divider()

                        Label("Other", systemImage: "ellipsis.circle").tag(InteractionType.other)
                    }
                    .pickerStyle(.menu)

                    if selectedInteractionType == .longPress {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Press Duration (seconds)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Slider(value: $duration, in: 0.5...5.0, step: 0.5)
                                Text("\(duration, specifier: "%.1f")s")
                                    .frame(width: 50)
                                    .font(.caption)
                            }
                        }
                    }

                    if selectedInteractionType == .coordinateTap {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tap Coordinates (normalized 0-1)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("X:")
                                    .frame(width: 20)
                                Slider(value: $coordinateX, in: 0...1, step: 0.05)
                                Text("\(coordinateX, specifier: "%.2f")")
                                    .frame(width: 40)
                                    .font(.caption)
                            }

                            HStack {
                                Text("Y:")
                                    .frame(width: 20)
                                Slider(value: $coordinateY, in: 0...1, step: 0.05)
                                Text("\(coordinateY, specifier: "%.2f")")
                                    .frame(width: 40)
                                    .font(.caption)
                            }
                        }
                    }

                    if selectedInteractionType == .cellInteraction {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cell Index")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Cell index", value: $cellIndex, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Button(role: .destructive) {
                            deleteEdge()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Edge")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            saveChanges()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Save Changes")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Edge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            edgeLabel = edge.elementLabel
            selectedInteractionType = edge.interactionType
            duration = edge.duration ?? 1.0
            coordinateX = edge.coordinateX ?? 0.5
            coordinateY = edge.coordinateY ?? 0.5
            cellIndex = edge.cellIndex ?? 0
        }
    }

    private func saveChanges() {
        guard canSave else { return }

        if let index = viewModel.navigationEdges.firstIndex(where: { $0.id == edge.id }) {
            viewModel.navigationEdges[index].elementLabel = edgeLabel.trimmingCharacters(in: .whitespaces)
            viewModel.navigationEdges[index].interactionType = selectedInteractionType

            viewModel.navigationEdges[index].duration = selectedInteractionType == .longPress ? duration : nil
            viewModel.navigationEdges[index].coordinateX = selectedInteractionType == .coordinateTap ? coordinateX : nil
            viewModel.navigationEdges[index].coordinateY = selectedInteractionType == .coordinateTap ? coordinateY : nil
            viewModel.navigationEdges[index].cellIndex = selectedInteractionType == .cellInteraction ? cellIndex : nil

        }

        isPresented = false
    }

    private func deleteEdge() {
        viewModel.navigationEdges.removeAll { $0.id == edge.id }
        isPresented = false
    }
}

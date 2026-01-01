import SwiftUI

struct ElementsTab: View {
    let screen: CapturedScreen?
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?
    @Binding var searchText: String
    @Binding var hoveredElementId: UUID?
    @Binding var screenName: String
    let onInteractionCompleted: () -> Void

    var interactiveElements: [SnapshotElement] {
        guard let screen = screen else { return [] }
        return screen.snapshot.elements.flatMap { $0.allInteractiveElements }
    }

    var filteredElements: [SnapshotElement] {
        if searchText.isEmpty {
            return interactiveElements
        }
        return interactiveElements.filter { element in
            let label = element.label.lowercased()
            let title = element.title.lowercased()
            let identifier = element.identifier.lowercased()
            let type = element.interactionType.rawValue.lowercased()
            let search = searchText.lowercased()

            return label.contains(search) ||
                   title.contains(search) ||
                   identifier.contains(search) ||
                   type.contains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let screen = screen {
                if interactiveElements.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Interactive Elements")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("This screen has no interactive elements.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else if filteredElements.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No matching elements")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(filteredElements.count) of \(interactiveElements.count) Elements")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))

                        Divider()

                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredElements) { element in
                                    SearchElementRow(
                                        element: element,
                                        viewModel: viewModel,
                                        sourceScreenId: screen.id,
                                        selectedScreen: $selectedScreen,
                                        hoveredElementId: $hoveredElementId,
                                        screenName: screenName,
                                        onInteractionCompleted: onInteractionCompleted
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Screen Selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Select or capture a screen to see interactive elements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            }

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search elements...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
        }
    }
}

struct SearchElementRow: View {
    let element: SnapshotElement
    @ObservedObject var viewModel: RecordingSessionViewModel
    let sourceScreenId: UUID
    @Binding var selectedScreen: CapturedScreen?
    @Binding var hoveredElementId: UUID?
    let screenName: String
    let onInteractionCompleted: () -> Void

    var elementLabel: String {
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

    var body: some View {
        Button {
            Task {
                await viewModel.remoteTap(element: element, sourceScreenId: sourceScreenId, screenName: screenName)
                if let newScreen = viewModel.capturedScreens.last {
                    selectedScreen = newScreen
                }
                onInteractionCompleted()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconForInteractionType(element.interactionType))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(colorForInteractionType(element.interactionType))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(elementLabel)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(element.interactionType.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isInteracting {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isInteracting)
        .opacity(viewModel.isInteracting ? 0.5 : 1.0)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .onHover { hovering in
            hoveredElementId = hovering ? element.id : nil
        }
    }

    private func iconForInteractionType(_ type: InteractionType) -> String {
        switch type {
        case .button: return "hand.tap.fill"
        case .textInput: return "keyboard"
        case .toggle: return "switch.2"
        case .navigation: return "arrow.right.circle.fill"
        case .selection: return "checkmark.circle.fill"
        case .picker: return "list.bullet"
        case .adjustment: return "slider.horizontal.3"
        case .swipeUp: return "arrow.up"
        case .swipeDown: return "arrow.down"
        case .swipeLeft: return "arrow.left"
        case .swipeRight: return "arrow.right"
        case .longPress: return "hand.point.up.left.and.text"
        case .doubleTap: return "hand.tap.fill"
        case .coordinateTap: return "hand.point.up.left"
        case .cellInteraction: return "list.dash"
        case .none, .other: return "hand.point.up.fill"
        }
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
}

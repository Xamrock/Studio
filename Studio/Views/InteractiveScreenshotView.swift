import SwiftUI

struct InteractiveScreenshotView: View {
    let screen: CapturedScreen
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?
    @Binding var searchText: String
    @Binding var hoveredElementId: UUID?
    @Binding var screenName: String
    let onInteractionCompleted: () -> Void
    @State private var showOffScreenElements = false
    @State private var expandedElementId: UUID?

    var interactiveElements: [SnapshotElement] {
        screen.snapshot.elements.flatMap { $0.allInteractiveElements }
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

    var offScreenElements: [SnapshotElement] {
        guard let screenshot = screen.screenshot else { return [] }
        let screenshotSize = screenshot.size

        return interactiveElements.filter { element in
            let frame = element.cgRect
            return frame.maxX < 0 || frame.maxY < 0 ||
                   frame.minX > screenshotSize.width ||
                   frame.minY > screenshotSize.height ||
                   frame.width < 1 || frame.height < 1
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let screenshot = screen.screenshot {
                    let appFrameOffset = CGPoint(
                        x: screen.snapshot.appFrame?.x ?? 0,
                        y: screen.snapshot.appFrame?.y ?? 0
                    )

                    InteractiveScreenshotViewAppKit(
                        screenshot: screenshot,
                        elements: interactiveElements,
                        filteredElements: searchText.isEmpty ? interactiveElements : filteredElements,
                        appFrameOffset: appFrameOffset,
                        displayScale: CGFloat(screen.snapshot.displayScale ?? 1.0),
                        hoveredElementId: $hoveredElementId,
                        onElementTap: { element in
                            withAnimation {
                                expandedElementId = expandedElementId == element.id ? nil : element.id
                            }
                        },
                        onCoordinateTap: { coordinate in
                            Task {
                                await viewModel.remoteTapAtCoordinate(coordinate, sourceScreenId: screen.id, screenName: screenName)
                                if let newScreen = viewModel.capturedScreens.last {
                                    selectedScreen = newScreen
                                }
                                onInteractionCompleted()
                            }
                        },
                        onCoordinateSwipe: { coordinate, direction in
                            Task {
                                await viewModel.remoteSwipeAtCoordinate(coordinate, direction: direction, sourceScreenId: screen.id, screenName: screenName)
                                if let newScreen = viewModel.capturedScreens.last {
                                    selectedScreen = newScreen
                                }
                                onInteractionCompleted()
                            }
                        }
                    )
                    .allowsHitTesting(!viewModel.isInteracting)
                    .overlay {
                        if viewModel.isInteracting {
                            ZStack {
                                Color.black.opacity(0.4)

                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .progressViewStyle(.circular)

                                    Text("Processing interaction...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))
                                )
                                .shadow(radius: 20)
                            }
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isInteracting)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if let expandedId = expandedElementId,
                           let element = interactiveElements.first(where: { $0.id == expandedId }) {
                            ScreenshotGesturePanel(
                                element: element,
                                viewModel: viewModel,
                                sourceScreenId: screen.id,
                                selectedScreen: $selectedScreen,
                                screenName: screenName,
                                onInteractionCompleted: onInteractionCompleted,
                                onClose: {
                                    withAnimation {
                                        expandedElementId = nil
                                    }
                                }
                            )
                            .frame(maxWidth: 600)
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Screenshot Available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showOffScreenElements) {
                NavigationStack {
                    OffScreenElementsList(
                        elements: offScreenElements,
                        viewModel: viewModel,
                        sourceScreenId: screen.id,
                        selectedScreen: $selectedScreen,
                        screenName: screenName,
                        onInteractionCompleted: onInteractionCompleted
                    )
                    .navigationTitle("Off-Screen Elements")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showOffScreenElements = false
                            }
                        }
                    }
                }
                .frame(minWidth: 500, minHeight: 400)
            }
        }
    }
}

struct ScreenshotGesturePanel: View {
    let element: SnapshotElement
    @ObservedObject var viewModel: RecordingSessionViewModel
    let sourceScreenId: UUID
    @Binding var selectedScreen: CapturedScreen?
    let screenName: String
    let onInteractionCompleted: () -> Void
    let onClose: () -> Void
    @State private var textToType = ""
    @State private var longPressDuration: Double = 1.0

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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose an interaction:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(elementLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    GestureButton(
                        icon: "hand.tap.fill",
                        label: "Tap",
                        color: .blue,
                        isInteracting: viewModel.isInteracting
                    ) {
                        performTap()
                    }

                    GestureButton(
                        icon: "hand.tap.fill",
                        label: "Double Tap",
                        color: .mint,
                        isInteracting: viewModel.isInteracting
                    ) {
                        performDoubleTap()
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        GestureButton(
                            icon: "hand.point.up.left.and.text",
                            label: "Long Press",
                            color: .red,
                            isInteracting: viewModel.isInteracting
                        ) {
                            performLongPress()
                        }

                        HStack(spacing: 4) {
                            Text("\(longPressDuration, specifier: "%.1f")s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35)
                            Slider(value: $longPressDuration, in: 0.5...5.0, step: 0.5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 8) {
                    GestureButton(
                        icon: "arrow.up",
                        label: "Swipe Up",
                        color: .pink,
                        isInteracting: viewModel.isInteracting
                    ) {
                        performSwipe(direction: .up)
                    }

                    GestureButton(
                        icon: "arrow.down",
                        label: "Swipe Down",
                        color: .pink,
                        isInteracting: viewModel.isInteracting
                    ) {
                        performSwipe(direction: .down)
                    }
                }

                HStack(spacing: 8) {
                    GestureButton(
                        icon: "arrow.left",
                        label: "Swipe Left",
                        color: .pink,
                        isInteracting: viewModel.isInteracting
                    ) {
                        performSwipe(direction: .left)
                    }

                    GestureButton(
                        icon: "arrow.right",
                        label: "Swipe Right",
                        color: .pink,
                        isInteracting: viewModel.isInteracting
                    ) {
                        performSwipe(direction: .right)
                    }
                }

                if element.interactionType == .textInput {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type text:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Enter text...", text: $textToType)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !textToType.isEmpty {
                                        performTypeText()
                                    }
                                }

                            Button {
                                performTypeText()
                            } label: {
                                if viewModel.isInteracting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(textToType.isEmpty || viewModel.isInteracting)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            Color(NSColor.controlBackgroundColor).opacity(0.95)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 15)
    }

    private func performTap() {
        onClose()
        Task {
            await viewModel.remoteTap(element: element, sourceScreenId: sourceScreenId, screenName: screenName)
            if let newScreen = viewModel.capturedScreens.last {
                selectedScreen = newScreen
            }
            onInteractionCompleted()
        }
    }

    private func performDoubleTap() {
        onClose()
        Task {
            await viewModel.remoteDoubleTap(element: element, sourceScreenId: sourceScreenId, screenName: screenName)
            if let newScreen = viewModel.capturedScreens.last {
                selectedScreen = newScreen
            }
            onInteractionCompleted()
        }
    }

    private func performLongPress() {
        onClose()
        Task {
            await viewModel.remoteLongPress(element: element, duration: longPressDuration, sourceScreenId: sourceScreenId, screenName: screenName)
            if let newScreen = viewModel.capturedScreens.last {
                selectedScreen = newScreen
            }
            onInteractionCompleted()
        }
    }

    private func performSwipe(direction: SwipeDirection) {
        onClose()
        Task {
            await viewModel.remoteSwipe(element: element, direction: direction, sourceScreenId: sourceScreenId, screenName: screenName)
            if let newScreen = viewModel.capturedScreens.last {
                selectedScreen = newScreen
            }
            onInteractionCompleted()
        }
    }

    private func performTypeText() {
        onClose()
        Task {
            await viewModel.remoteTypeText(textToType, in: element, sourceScreenId: sourceScreenId, screenName: screenName)
            if let newScreen = viewModel.capturedScreens.last {
                selectedScreen = newScreen
            }
            onInteractionCompleted()
        }
    }
}

struct OffScreenElementsList: View {
    let elements: [SnapshotElement]
    @ObservedObject var viewModel: RecordingSessionViewModel
    let sourceScreenId: UUID
    @Binding var selectedScreen: CapturedScreen?
    let screenName: String
    let onInteractionCompleted: () -> Void

    var body: some View {
        List {
            ForEach(elements) { element in
                Button {
                    Task {
                        await viewModel.remoteTap(element: element, sourceScreenId: sourceScreenId, screenName: screenName)
                        if let newScreen = viewModel.capturedScreens.last {
                            selectedScreen = newScreen
                        }
                        onInteractionCompleted()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iconForInteractionType(element.interactionType))
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(colorForInteractionType(element.interactionType))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(elementLabel(for: element))
                                .font(.body)
                            Text(element.interactionType.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if viewModel.isInteracting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isInteracting)
            }
        }
    }

    private func elementLabel(for element: SnapshotElement) -> String {
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

struct GestureButton: View {
    let icon: String
    let label: String
    let color: Color
    let isInteracting: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isInteracting)
        .opacity(isInteracting ? 0.5 : 1.0)
    }
}

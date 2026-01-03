import SwiftUI

struct RecordSection: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?
    @Binding var screenName: String
    @State private var searchText: String = ""
    @State private var hoveredElementId: UUID?
    @State private var captureNotes: String = ""
    @State private var captureTags: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            RecordTopBar(
                viewModel: viewModel
            )

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
            }

            HSplitView {
                if let screen = selectedScreen {
                    InteractiveScreenshotView(
                        screen: screen,
                        viewModel: viewModel,
                        selectedScreen: $selectedScreen,
                        searchText: $searchText,
                        hoveredElementId: $hoveredElementId,
                        screenName: $screenName,
                        onInteractionCompleted: {
                            screenName = ""
                            captureNotes = ""
                            captureTags = []
                        }
                    )
                } else if viewModel.isRecording && viewModel.capturedScreens.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 60, height: 60)
                        Text(viewModel.connectionStatus ?? "Connecting...")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        if viewModel.connectionStatus != nil {
                            Text(viewModel.connectionStatus == "Connected!"
                                ? "Capturing initial screen..."
                                : "Please wait, this may take up to 60 seconds on first run")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Text("Waiting for first screen capture")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Select a screen to begin")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Capture a screen or select one from the Screens tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                }

                RecordRightPane(
                    viewModel: viewModel,
                    selectedScreen: $selectedScreen,
                    screenName: $screenName,
                    searchText: $searchText,
                    hoveredElementId: $hoveredElementId,
                    captureNotes: $captureNotes,
                    captureTags: $captureTags
                )
            }
        }
    }
}

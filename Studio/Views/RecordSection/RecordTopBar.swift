import SwiftUI

struct RecordTopBar: View {
    @ObservedObject var viewModel: RecordingSessionViewModel

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await viewModel.startSession()
                        }
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRecording || viewModel.bundleID.isEmpty || viewModel.selectedDevice == nil)
                    .help("Start Recording Session")

                    Button {
                        Task {
                            await viewModel.stopSession()
                        }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isRecording)
                    .help("Stop Recording")

                    Toggle("Skip launch", isOn: $viewModel.skipAppLaunch)
                        .font(.caption)
                        .disabled(viewModel.isRecording)

                    Divider()
                        .frame(height: 20)

                    TextField("Bundle ID", text: $viewModel.bundleID)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120, idealWidth: 150, maxWidth: 180)
                        .disabled(viewModel.isRecording)

                    Divider()
                        .frame(height: 20)

                    if viewModel.isLoadingDevices {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Picker("", selection: $viewModel.selectedDevice) {
                            Text("Select device").tag(nil as Device?)
                            ForEach(viewModel.availableDevices) { device in
                                Text(device.displayName).tag(device as Device?)
                            }
                        }
                        .frame(minWidth: 120, idealWidth: 150, maxWidth: 180)
                        .disabled(viewModel.isRecording)
                        .labelsHidden()
                    }

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 12)
                .frame(minWidth: geometry.size.width)
            }
        }
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

import SwiftUI

struct TestTopBar: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    let onGenerate: () -> Void
    let onCopy: () -> Void
    let onExport: () -> Void
    let onRunTest: () -> Void
    let canGenerate: Bool
    let hasCode: Bool
    let canRunTest: Bool
    let isRunningTest: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        onGenerate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Generate Code")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canGenerate)
                    .help("Generate test code from selected flow groups")

                    Divider()
                        .frame(height: 20)

                    Button {
                        onCopy()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasCode)
                    .help("Copy code to clipboard")

                    Button {
                        onExport()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasCode)
                    .help("Export code to file")

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
                        .frame(minWidth: 120, idealWidth: 150, maxWidth: 200)
                        .labelsHidden()
                        .disabled(isRunningTest)
                    }

                    Button {
                        onRunTest()
                    } label: {
                        HStack(spacing: 4) {
                            if isRunningTest {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text("Run Test")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!canRunTest || isRunningTest)
                    .help("Run test on selected device (XCUITest only)")

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

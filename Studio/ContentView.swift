import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RecordingSessionViewModel()
    @State private var selectedSection: AppSection = .record
    @State private var screenName = ""
    @State private var showExportAlert = false
    @State private var exportURL: URL?
    @State private var selectedScreen: CapturedScreen?

    var body: some View {
        HStack(spacing: 0) {
            AppSectionPicker(selectedSection: $selectedSection)

            Group {
                switch selectedSection {
                case .record:
                    RecordSectionPlaceholder(
                        viewModel: viewModel,
                        selectedScreen: $selectedScreen,
                        screenName: $screenName,
                        exportURL: $exportURL,
                        showExportAlert: $showExportAlert
                    )

                case .flow:
                    FlowSectionPlaceholder(
                        viewModel: viewModel,
                        selectedScreen: $selectedScreen
                    )

                case .export:
                    ExportSectionPlaceholder(
                        viewModel: viewModel
                    )
                }
            }
        }
        .alert("Export Successful", isPresented: $showExportAlert) {
            Button("OK") { }
            if let url = exportURL {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
            }
        } message: {
            if let url = exportURL {
                Text("Exported to:\n\(url.path)")
            }
        }
        .onAppear {
            Task {
                await viewModel.loadDevices()
            }
        }
        .onChange(of: viewModel.capturedScreens.count) { oldValue, newValue in
            if newValue > oldValue, let lastScreen = viewModel.capturedScreens.last {
                selectedScreen = lastScreen
            }
        }
    }
}

struct RecordSectionPlaceholder: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?
    @Binding var screenName: String
    @Binding var exportURL: URL?
    @Binding var showExportAlert: Bool

    var body: some View {
        RecordSection(
            viewModel: viewModel,
            selectedScreen: $selectedScreen,
            screenName: $screenName
        )
    }
}

struct FlowSectionPlaceholder: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?

    var body: some View {
        FlowSection(
            viewModel: viewModel,
            selectedScreen: $selectedScreen
        )
    }
}

struct ExportSectionPlaceholder: View {
    @ObservedObject var viewModel: RecordingSessionViewModel

    var body: some View {
        ExportSection(viewModel: viewModel)
    }
}

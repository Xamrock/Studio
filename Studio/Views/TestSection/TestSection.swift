import SwiftUI
import UniformTypeIdentifiers

struct TestSection: View {
    @ObservedObject var viewModel: RecordingSessionViewModel

    @State private var selectedFramework: CodeGenerationService.TestFramework = .xcuiTest
    @State private var selectedGroups: Set<UUID> = []
    @State private var bundleID: String = ""
    @State private var generatedCode: String = ""
    @State private var showingExportSuccess = false
    @State private var isRunningTest = false
    @State private var testOutput: String = ""
    @State private var showingTestOutput = false

    private let codeGenerator = CodeGenerationService()
    private let testRunner = GeneratedTestRunnerService()

    var canGenerate: Bool {
        !selectedGroups.isEmpty && !bundleID.isEmpty
    }

    var canRunTest: Bool {
        !generatedCode.isEmpty && viewModel.selectedDevice != nil && selectedFramework == .xcuiTest
    }

    var body: some View {
        VStack(spacing: 0) {
            TestTopBar(
                viewModel: viewModel,
                onGenerate: generateCode,
                onCopy: copyToClipboard,
                onExport: exportCode,
                onRunTest: runTest,
                canGenerate: canGenerate,
                hasCode: !generatedCode.isEmpty,
                canRunTest: canRunTest,
                isRunningTest: isRunningTest
            )

            HSplitView {
                VStack(spacing: 0) {
                    if generatedCode.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            Text("No Code Generated")
                                .font(.title2)
                                .fontWeight(.medium)
                            Text("Configure settings and select flow groups, then click Generate Code")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView([.horizontal, .vertical]) {
                            Text(generatedCode)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        }
                        .background(Color(NSColor.textBackgroundColor))
                    }
                }

                TestRightPane(
                    viewModel: viewModel,
                    selectedFramework: $selectedFramework,
                    selectedGroups: $selectedGroups,
                    bundleID: $bundleID
                )
            }
        }
        .onAppear {
            bundleID = viewModel.bundleID

            selectedGroups = Set(viewModel.flowGroups.map { $0.id })

            if canGenerate {
                generateCode()
            }
        }
        .onChange(of: selectedFramework) {
            if canGenerate {
                generateCode()
            }
        }
        .onChange(of: selectedGroups) {
            if canGenerate {
                generateCode()
            }
        }
        .onChange(of: bundleID) {
            if canGenerate {
                generateCode()
            }
        }
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Test code has been exported successfully.")
        }
        .sheet(isPresented: $showingTestOutput) {
            TestOutputSheet(
                output: testOutput,
                isRunning: isRunningTest,
                onStop: stopTest,
                onDismiss: { showingTestOutput = false }
            )
        }
    }

    private func generateCode() {
        guard canGenerate else {
            generatedCode = ""
            return
        }

        var allCode = ""

        for groupId in selectedGroups {
            guard let group = viewModel.flowGroups.first(where: { $0.id == groupId }) else {
                continue
            }

            let code = codeGenerator.generate(
                framework: selectedFramework,
                flowGroup: group,
                screens: viewModel.capturedScreens,
                edges: viewModel.navigationEdges,
                bundleID: bundleID
            )

            allCode += code + "\n\n"
        }

        generatedCode = allCode
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedCode, forType: .string)
    }

    private func exportCode() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Test Code"
        savePanel.message = "Choose a location to save your test code"

        switch selectedFramework {
        case .xcuiTest:
            savePanel.nameFieldStringValue = "GeneratedUITests.swift"
        case .maestro:
            savePanel.nameFieldStringValue = "flow.yaml"
        case .appium:
            savePanel.nameFieldStringValue = "appium-test.js"
        }

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try generatedCode.write(to: url, atomically: true, encoding: .utf8)
                showingExportSuccess = true
            } catch {
            }
        }
    }

    private func runTest() {
        guard let device = viewModel.selectedDevice else { return }

        isRunningTest = true
        testOutput = "Starting test on \(device.displayName)...\n\n"
        showingTestOutput = true

        Task {
            await executeTest(on: device)
        }
    }

    private func stopTest() {
        testRunner.stop()
        isRunningTest = false
        testOutput += "\n\nTest stopped by user.\n"
    }

    private func executeTest(on device: Device) async {
        // Generate JSON commands for all selected flow groups
        var allCommands: [[String: Any]] = []

        for groupId in selectedGroups {
            guard let group = viewModel.flowGroups.first(where: { $0.id == groupId }) else {
                continue
            }

            let commandsJSON = codeGenerator.generateScriptCommands(
                flowGroup: group,
                screens: viewModel.capturedScreens,
                edges: viewModel.navigationEdges
            )

            // Parse and append commands
            if let data = commandsJSON.data(using: .utf8),
               let commands = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                allCommands.append(contentsOf: commands)
            }
        }

        // Convert back to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: allCommands, options: []),
              let commandsString = String(data: jsonData, encoding: .utf8) else {
            await MainActor.run {
                testOutput += "\nError: Failed to generate test commands\n"
                isRunningTest = false
            }
            return
        }

        do {
            try await testRunner.runTest(
                commands: commandsString,
                device: device,
                bundleID: bundleID
            ) { output in
                Task { @MainActor in
                    self.testOutput += output
                }
            }
        } catch {
            await MainActor.run {
                testOutput += "\nError: \(error.localizedDescription)\n"
            }
        }

        await MainActor.run {
            isRunningTest = false
        }
    }
}

struct TestOutputSheet: View {
    let output: String
    let isRunning: Bool
    let onStop: () -> Void
    let onDismiss: () -> Void

    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Test Output")
                    .font(.headline)
                Spacer()
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Running...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Stop") {
                        onStop()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("output")
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: output) {
                    if autoScroll {
                        withAnimation {
                            proxy.scrollTo("output", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

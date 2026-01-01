import SwiftUI
import UniformTypeIdentifiers

struct ExportSection: View {
    @ObservedObject var viewModel: RecordingSessionViewModel

    @State private var selectedFramework: CodeGenerationService.TestFramework = .xcuiTest
    @State private var selectedGroups: Set<UUID> = []
    @State private var bundleID: String = ""
    @State private var generatedCode: String = ""
    @State private var showingExportSuccess = false

    private let codeGenerator = CodeGenerationService()

    var canGenerate: Bool {
        !selectedGroups.isEmpty && !bundleID.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ExportTopBar(
                onGenerate: generateCode,
                onCopy: copyToClipboard,
                onExport: exportCode,
                canGenerate: canGenerate,
                hasCode: !generatedCode.isEmpty
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

                ExportRightPane(
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
}

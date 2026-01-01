import SwiftUI

struct ExportRightPane: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedFramework: CodeGenerationService.TestFramework
    @Binding var selectedGroups: Set<UUID>
    @Binding var bundleID: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configuration")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Framework")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(spacing: 4) {
                            FrameworkOptionButton(
                                framework: .xcuiTest,
                                isSelected: selectedFramework == .xcuiTest,
                                icon: "swift",
                                name: "XCUITest",
                                description: "Apple's native UI testing framework",
                                onSelect: { selectedFramework = .xcuiTest }
                            )

                            FrameworkOptionButton(
                                framework: .maestro,
                                isSelected: selectedFramework == .maestro,
                                icon: "music.note",
                                name: "Maestro",
                                description: "Cross-platform mobile UI testing",
                                onSelect: { selectedFramework = .maestro }
                            )

                            FrameworkOptionButton(
                                framework: .appium,
                                isSelected: selectedFramework == .appium,
                                icon: "app.badge",
                                name: "Appium",
                                description: "Cross-platform mobile testing with WebdriverIO",
                                onSelect: { selectedFramework = .appium }
                            )
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Configuration")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Bundle ID", text: $bundleID)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Flow Groups")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            if !viewModel.flowGroups.isEmpty {
                                Button(selectedGroups.count == viewModel.flowGroups.count ? "Deselect All" : "Select All") {
                                    if selectedGroups.count == viewModel.flowGroups.count {
                                        selectedGroups.removeAll()
                                    } else {
                                        selectedGroups = Set(viewModel.flowGroups.map { $0.id })
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }

                        if viewModel.flowGroups.isEmpty {
                            Text("No flow groups created yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(viewModel.flowGroups) { group in
                                    FlowGroupCheckbox(
                                        group: group,
                                        isSelected: selectedGroups.contains(group.id),
                                        viewModel: viewModel,
                                        onToggle: {
                                            if selectedGroups.contains(group.id) {
                                                selectedGroups.remove(group.id)
                                            } else {
                                                selectedGroups.insert(group.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 220, idealWidth: 250, maxWidth: 280)
    }
}

struct FrameworkOptionButton: View {
    let framework: CodeGenerationService.TestFramework
    let isSelected: Bool
    let icon: String
    let name: String
    let description: String
    let onSelect: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isDisabled ? .secondary : .primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

struct FlowGroupCheckbox: View {
    let group: FlowGroup
    let isSelected: Bool
    @ObservedObject var viewModel: RecordingSessionViewModel
    let onToggle: () -> Void

    var screenCount: Int {
        viewModel.capturedScreens.filter { screen in
            screen.flowGroupIds.contains(group.id)
        }.count
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Circle()
                    .fill(group.color.color)
                    .frame(width: 10, height: 10)

                Text(group.name)
                    .font(.body)

                Spacer()

                Text("\(screenCount) screens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

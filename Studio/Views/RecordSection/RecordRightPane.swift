import SwiftUI

struct RecordRightPane: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?
    @Binding var screenName: String
    @Binding var searchText: String
    @Binding var hoveredElementId: UUID?
    @Binding var captureNotes: String
    @Binding var captureTags: [String]
    @State private var selectedTab: RightPaneTab = .capture

    enum RightPaneTab: String, CaseIterable {
        case capture = "Capture"
        case elements = "Elements"
        case screens = "Screens"

        var icon: String {
            switch self {
            case .capture:
                return "camera.fill"
            case .elements:
                return "hand.tap"
            case .screens:
                return "photo.stack"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(RightPaneTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            Group {
                switch selectedTab {
                case .capture:
                    CaptureTab(
                        viewModel: viewModel,
                        screenName: $screenName,
                        screenNotes: $captureNotes,
                        tags: $captureTags
                    )

                case .elements:
                    ElementsTab(
                        screen: selectedScreen,
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

                case .screens:
                    ScreensTab(
                        viewModel: viewModel,
                        selectedScreen: $selectedScreen
                    )
                }
            }
        }
        .frame(minWidth: 220, idealWidth: 250, maxWidth: 280)
    }
}

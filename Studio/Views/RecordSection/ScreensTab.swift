import SwiftUI

struct ScreensTab: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var selectedScreen: CapturedScreen?
    @State private var searchText: String = ""

    var filteredScreens: [CapturedScreen] {
        if searchText.isEmpty {
            return viewModel.capturedScreens
        }
        return viewModel.capturedScreens.filter { screen in
            screen.name.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(searchText.isEmpty ? "Captured Screens" : "Filtered Screens")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(filteredScreens.count)\(searchText.isEmpty ? "" : " of \(viewModel.capturedScreens.count)")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))

            Divider()

            if viewModel.capturedScreens.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No screens captured yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start recording and capture screens to begin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else if filteredScreens.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No matching screens")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredScreens) { screen in
                            ScreenListItemCompact(
                                screen: screen,
                                isSelected: selectedScreen?.id == screen.id,
                                onSelect: { selectedScreen = screen }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search screens...", text: $searchText)
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

struct ScreenListItemCompact: View {
    let screen: CapturedScreen
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Group {
                    if let screenshot = screen.screenshot {
                        Image(nsImage: screenshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 32, height: 48)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(screen.name)
                        .font(.caption)
                        .lineLimit(2)
                    Text(screen.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

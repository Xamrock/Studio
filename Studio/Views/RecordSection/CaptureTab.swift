import SwiftUI

struct CaptureTab: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    @Binding var screenName: String
    @Binding var screenNotes: String
    @Binding var tags: [String]
    @State private var currentTagInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isRecording && viewModel.isTestRunning {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Screen Name")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField("e.g., Login Screen", text: $screenName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            if !tags.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        TagPill(tag: tag) {
                                            tags.removeAll { $0 == tag }
                                        }
                                    }
                                }
                                .padding(.bottom, 4)
                            }

                            TextField("Add tag...", text: $currentTagInput)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addTag()
                                }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextEditor(text: $screenNotes)
                                .font(.caption)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }

                        Button {
                            Task {
                                let name = screenName.isEmpty ? "Untitled Screen" : screenName
                                await viewModel.captureScreen(name: name)
                                screenName = ""
                                screenNotes = ""
                                tags = []
                                currentTagInput = ""
                            }
                        } label: {
                            HStack {
                                if viewModel.isCapturing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "camera.fill")
                                }
                                Text("Capture Screen")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isCapturing)
                        .controlSize(.large)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: viewModel.isRecording ? "play.slash" : "camera.metering.unknown")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text(viewModel.isRecording ? "Test Not Running" : "Not Recording")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(viewModel.isRecording ? "Interact with the app to start the test" : "Start a recording session to capture screens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
            }
        }
    }

    private func addTag() {
        let trimmed = currentTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            currentTagInput = ""
            return
        }
        tags.append(trimmed)
        currentTagInput = ""
    }
}

struct TagPill: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

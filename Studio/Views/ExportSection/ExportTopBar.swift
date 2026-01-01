import SwiftUI

struct ExportTopBar: View {
    let onGenerate: () -> Void
    let onCopy: () -> Void
    let onExport: () -> Void
    let canGenerate: Bool
    let hasCode: Bool

    var body: some View {
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

            Spacer()
        }
        .padding(.horizontal, 12)
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

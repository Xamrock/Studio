import SwiftUI

struct AppSectionPicker: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
                .frame(height: 20)

            ForEach(AppSection.allCases) { section in
                SectionButton(
                    section: section,
                    isSelected: selectedSection == section,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    }
                )
            }

            Spacer()
        }
        .frame(width: 70)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .trailing
        )
    }
}

struct SectionButton: View {
    let section: AppSection
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))

                Text(section.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(section.description)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

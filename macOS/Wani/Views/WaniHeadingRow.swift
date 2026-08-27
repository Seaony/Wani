import SwiftUI

struct WaniHeadingRow: View {
    @Bindable var heading: WaniHeading
    let palette: WaniPalette
    let canArchive: Bool
    let save: () -> Void
    let archive: () -> Void
    let reorder: (UUID, UUID) -> Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            TextField("Heading", text: headingTitleBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Spacer(minLength: 8)
            Menu {
                Button("Archive", systemImage: "archivebox", action: archive)
                    .disabled(!canArchive)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .waniPointerFeedback(palette: palette)
            .opacity(isHovered ? 1 : 0)
            .accessibilityLabel("Heading Actions")
        }
        .padding(.horizontal, 11)
        .frame(height: 40)
        .contentShape(Rectangle())
        .draggable("heading:\(heading.id.uuidString)")
        .dropDestination(for: String.self) { values, _ in
            guard
                let value = values.first(where: { $0.hasPrefix("heading:") }),
                let movingID = UUID(
                    uuidString: String(value.dropFirst("heading:".count))
                )
            else { return false }
            return reorder(movingID, heading.id)
        }
        .onHover { isHovered = $0 }
    }

    private var headingTitleBinding: Binding<String> {
        Binding(
            get: { heading.title },
            set: { title in
                heading.title = title
                heading.updatedAt = .now
                save()
            }
        )
    }
}

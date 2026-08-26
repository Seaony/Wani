import SwiftUI

struct WaniHeadingRow: View {
    @Bindable var heading: WaniHeading
    let palette: WaniPalette
    let count: Int
    let save: () -> Void
    let reorder: (UUID, UUID) -> Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Heading", text: $heading.title)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(palette.tertiaryText)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 80, alignment: .leading)
                .onSubmit(save)
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
            if count > 0 {
                Text(count.formatted())
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tertiaryText)
            }
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.tertiaryText.opacity(0.6))
                .frame(width: 22, height: 22)
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
        }
        .padding(.horizontal, 11)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

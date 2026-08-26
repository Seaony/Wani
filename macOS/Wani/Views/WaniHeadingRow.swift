import SwiftUI

struct WaniHeadingRow: View {
    @Bindable var heading: WaniHeading
    let palette: WaniPalette
    let save: () -> Void
    let reorder: (UUID, UUID) -> Bool

    var body: some View {
        HStack(spacing: 0) {
            TextField("Heading", text: $heading.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .onSubmit(save)
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
    }
}

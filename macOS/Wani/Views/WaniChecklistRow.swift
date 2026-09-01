import SwiftUI

struct WaniChecklistRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var item: WaniChecklistItem
    let palette: WaniPalette
    let toggle: () -> Void
    let save: () -> Void
    let delete: () -> Void
    let reorder: (UUID, UUID) -> Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                ZStack {
                    Circle().fill(item.isCompleted ? checklistAccent : Color.clear)
                    Circle()
                        .stroke(
                            checklistAccent,
                            lineWidth: 1.4
                        )
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 10.5, height: 10.5)
                .frame(width: 15, height: 15)
            }
            .buttonStyle(.waniInteractive(palette, showsHoverBackground: false))
            .accessibilityLabel(item.isCompleted ? "Reopen checklist item" : "Complete checklist item")

            TextField("Checklist item", text: itemTitleBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(item.isCompleted ? palette.tertiaryText : palette.secondaryText)
                .strikethrough(item.isCompleted)

            Button(action: delete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.waniInteractive(palette))
            .foregroundStyle(palette.tertiaryText)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .accessibilityLabel("Delete checklist item")
        }
        .frame(height: 28)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.faintLine).frame(height: 1)
        }
        .padding(.trailing, 11)
        .onHover { isHovered = $0 }
        .draggable("checklist:\(item.id.uuidString)")
        .dropDestination(for: String.self) { values, _ in
            guard
                let value = values.first(where: { $0.hasPrefix("checklist:") }),
                let movingID = UUID(
                    uuidString: String(value.dropFirst("checklist:".count))
                )
            else { return false }
            return reorder(movingID, item.id)
        }
        .animation(WaniMotion.quick, value: item.isCompleted)
    }

    private var checklistAccent: Color {
        colorScheme == .dark ? Color(hex: 0x66ABFF) : palette.accent
    }

    private var itemTitleBinding: Binding<String> {
        Binding(
            get: { item.title },
            set: { title in
                item.title = title
                item.updatedAt = .now
                save()
            }
        )
    }
}

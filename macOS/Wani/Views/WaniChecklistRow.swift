import SwiftUI

struct WaniChecklistRow: View {
    @Bindable var item: WaniChecklistItem
    let palette: WaniPalette
    let toggle: () -> Void
    let save: () -> Void
    let delete: () -> Void
    let reorder: (UUID, UUID) -> Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? palette.accent : Color.clear)
                    Circle()
                        .stroke(
                            item.isCompleted ? palette.accent : palette.tertiaryText,
                            lineWidth: 1.4
                        )
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 14, height: 14)
            }
            .buttonStyle(.waniInteractive(palette))
            .accessibilityLabel(item.isCompleted ? "Reopen checklist item" : "Complete checklist item")

            TextField("Checklist item", text: itemTitleBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(item.isCompleted ? palette.tertiaryText : palette.secondaryText)
                .strikethrough(item.isCompleted)

            Button(action: delete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.waniInteractive(palette))
            .foregroundStyle(palette.tertiaryText)
            .accessibilityLabel("Delete checklist item")
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.faintLine).frame(height: 1)
        }
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

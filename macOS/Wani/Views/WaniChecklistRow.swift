import SwiftUI

struct WaniChecklistRow: View {
    @Bindable var item: WaniChecklistItem
    let palette: WaniPalette
    let toggle: () -> Void
    let save: () -> Void
    let delete: () -> Void

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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
            .foregroundStyle(palette.tertiaryText)
            .accessibilityLabel("Delete checklist item")
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.faintLine).frame(height: 1)
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

import SwiftData
import SwiftUI

struct WaniTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var todo: WaniTodo
    @AppStorage("wani.compactRows") private var compactRows = false
    let isExpanded: Bool
    let showsDate: Bool
    let showsProject: Bool
    let palette: WaniPalette
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(todo.status == .completed ? palette.accent : Color.clear)
                        .overlay(
                            Circle().stroke(
                                palette.tertiary,
                                lineWidth: todo.status == .completed ? 0 : 1.5
                            )
                        )
                    if todo.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 21, height: 21)
            }
            .accessibilityLabel(todo.status == .completed ? "Mark incomplete" : "Complete")

            if showsDate {
                Text((todo.completedAt ?? todo.canceledAt ?? todo.createdAt).formatted(.dateTime.month().day()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 0) {
                Button(action: onOpen) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(todo.title)
                            .font(.system(size: 16))
                            .foregroundStyle(todo.status == .completed ? palette.tertiary : palette.text)
                            .strikethrough(todo.status == .completed)
                            .multilineTextAlignment(.leading)
                        if !todo.notes.isEmpty && !isExpanded {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 10))
                                .foregroundStyle(palette.tertiary)
                        }
                        if !(todo.checklistItems ?? []).isEmpty && !isExpanded {
                            Image(systemName: "checklist")
                                .font(.system(size: 10))
                                .foregroundStyle(palette.tertiary)
                        }
                        Spacer(minLength: 4)
                        if let deadline = todo.deadline, !isExpanded {
                            Label(deadline.formatted(.dateTime.day()), systemImage: "flag.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.accent)
                        } else if showsProject {
                            Text(todo.project?.title ?? "Inbox")
                                .font(.system(size: 13))
                                .foregroundStyle(palette.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    expandedEditor
                } else if showsProject && showsDate {
                    Text(todo.project?.title ?? "Inbox")
                        .font(.system(size: 13.5))
                        .foregroundStyle(palette.tertiary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, compactRows ? 7 : 9)
        .background(isExpanded ? palette.hover : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("todo-\(todo.id.uuidString)")
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Notes", text: $todo.notes, axis: .vertical)
                .font(.system(size: 14.5))
                .foregroundStyle(palette.secondary)
                .lineLimit(2...4)
                .onChange(of: todo.notes) { save() }
            ForEach((todo.checklistItems ?? []).sorted { $0.sortOrder < $1.sortOrder }) { item in
                Button {
                    item.isCompleted.toggle()
                    item.updatedAt = .now
                    save()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isCompleted ? palette.accent : palette.tertiary)
                        Text(item.title)
                            .font(.system(size: 14.5))
                            .foregroundStyle(item.isCompleted ? palette.tertiary : palette.secondary)
                            .strikethrough(item.isCompleted)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 7) {
                Text(scheduleLabel)
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 8))
                ForEach(todo.tagNames, id: \.self) { tag in
                    Text(tag)
                        .foregroundStyle(palette.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
                Button("Delete", action: onDelete)
                    .foregroundStyle(palette.tertiary)
            }
            .font(.system(size: 13))
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var scheduleLabel: String {
        switch todo.schedule {
        case .inbox: "Inbox"
        case .anytime: "Anytime"
        case .someday: "Someday"
        case .date: "Scheduled"
        }
    }

    private func save() {
        todo.updatedAt = .now
        try? modelContext.save()
    }
}

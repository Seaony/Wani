import SwiftUI

struct WaniTaskRow: View {
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let projects: [WaniProject]
    let headings: [WaniHeading]
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let toggleCompleted: () -> Void
    let moveToTrash: () -> Void
    let restore: () -> Void
    let deletePermanently: () -> Void
    let moveToInbox: () -> Void
    let moveToProject: (WaniProject, WaniHeading?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 11) {
                Button(action: toggleCompleted) {
                    ZStack {
                        Circle()
                            .fill(todo.status == .open ? Color.clear : palette.accent)
                        Circle()
                            .stroke(
                                todo.status == .open
                                    ? palette.tertiaryText
                                    : palette.accent,
                                lineWidth: 1.5
                            )
                        if todo.status != .open {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 17, height: 17)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todo.status == .open ? "Complete" : "Reopen")

                Button(action: toggleExpanded) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(todo.title)
                            .font(.system(size: 13.5))
                            .foregroundStyle(
                                todo.status == .open
                                    ? palette.text
                                    : palette.tertiaryText
                            )
                            .strikethrough(todo.status != .open)
                            .multilineTextAlignment(.leading)
                        if let dateLabel {
                            Text(dateLabel)
                                .font(.system(size: 11.5))
                                .foregroundStyle(palette.accent)
                        }
                        Spacer()
                        if !isExpanded {
                            badges
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                expandedEditor
                    .padding(.leading, 28)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 11)
        .padding(.vertical, isExpanded ? 14 : 9)
        .background(
            isExpanded ? palette.card : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            if isExpanded {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(palette.line, lineWidth: 0.5)
            }
        }
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("To-do", text: $todo.title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))

            TextEditor(text: $todo.notes)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 52, maxHeight: 130)

            HStack {
                Label(scheduleLabel, systemImage: scheduleSymbol)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                if todo.deletedAt != nil {
                    Button("Restore", action: restore)
                    Button("Delete", action: deletePermanently)
                } else {
                    moveMenu
                    Button(action: moveToTrash) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Move to Trash")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.tertiaryText)
        }
    }

    private var moveMenu: some View {
        Menu {
            Button("Inbox", systemImage: "tray") {
                moveToInbox()
            }

            if !projects.isEmpty {
                Divider()
                ForEach(projects) { project in
                    Menu(project.title) {
                        Button("No Heading") {
                            moveToProject(project, nil)
                        }
                        ForEach(headings.filter { $0.project?.id == project.id }) { heading in
                            Button(heading.title) {
                                moveToProject(project, heading)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.right")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Move")
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: 8) {
            if !todo.notes.isEmpty {
                Image(systemName: "text.alignleft")
            }
            if let checklist = todo.checklistItems, !checklist.isEmpty {
                Text("\(checklist.filter(\.isCompleted).count)/\(checklist.count)")
            }
            if let project = todo.project {
                Text(project.title)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(palette.hover, in: Capsule())
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(palette.tertiaryText)
    }

    private var dateLabel: String? {
        guard todo.schedule == .date, let startDate = todo.startDate else {
            return nil
        }
        return startDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private var scheduleLabel: String {
        switch todo.schedule {
        case .inbox: "Inbox"
        case .anytime: "Anytime"
        case .someday: "Someday"
        case .date:
            todo.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "Scheduled"
        }
    }

    private var scheduleSymbol: String {
        todo.schedule == .date ? "calendar" : "tray"
    }
}

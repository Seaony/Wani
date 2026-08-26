import SwiftUI
import SwiftData

struct WaniTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let projects: [WaniProject]
    let headings: [WaniHeading]
    let density: WaniListDensity
    let deadlineNotificationsEnabled: Bool
    let isSelected: Bool
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let toggleCompleted: () -> Void
    let cancelTodo: () -> Void
    let moveToTrash: () -> Void
    let restore: () -> Void
    let deletePermanently: () -> Void
    let moveToInbox: () -> Void
    let moveToProject: (WaniProject, WaniHeading?) -> Void

    @State private var checklistTitle = ""
    @State private var tagDraft = ""
    @State private var dateEditorOpen = false

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
        .padding(.vertical, isExpanded ? 14 : density.rowPadding)
        .background(
            isExpanded ? palette.card : (isSelected ? palette.softAccent : Color.clear),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            if isExpanded || isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? palette.accent.opacity(0.45) : palette.line, lineWidth: 0.5)
            }
        }
        .accessibilityValue(isSelected ? "Selected" : "")
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

            checklistEditor
            tagEditor

            if dateEditorOpen {
                WaniTaskDateEditor(
                    todo: todo,
                    palette: palette,
                    save: saveChanges,
                    reminderChanged: syncReminder
                )
            }

            HStack {
                Button {
                    dateEditorOpen.toggle()
                } label: {
                    Label(scheduleLabel, systemImage: scheduleSymbol)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                if todo.deletedAt != nil {
                    Button("Restore", action: restore)
                    Button("Delete", action: deletePermanently)
                } else {
                    moveMenu
                    if todo.status == .open {
                        Button(action: cancelTodo) {
                            Image(systemName: "xmark.circle")
                        }
                        .accessibilityLabel("Cancel To-Do")
                    }
                    Button(action: moveToTrash) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Move to Trash")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.tertiaryText)
        }
        .onAppear {
            tagDraft = todo.tagNames.joined(separator: ", ")
        }
    }

    private var checklistEditor: some View {
        VStack(spacing: 0) {
            ForEach(sortedChecklistItems) { item in
                WaniChecklistRow(
                    item: item,
                    palette: palette,
                    toggle: { toggleChecklistItem(item) },
                    save: saveChanges,
                    delete: { deleteChecklistItem(item) }
                )
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.tertiaryText)
                TextField("Add checklist item", text: $checklistTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(addChecklistItem)
            }
            .padding(.vertical, 7)
            .overlay(alignment: .top) {
                Rectangle().fill(palette.faintLine).frame(height: 1)
            }
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !todo.tagNames.isEmpty {
                HStack(spacing: 6) {
                    ForEach(todo.tagNames, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundStyle(palette.tertiaryText)
                TextField("Tags, separated by commas", text: $tagDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .onSubmit(saveTags)
                Button("Save", action: saveTags)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.accent)
            }
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

    private var sortedChecklistItems: [WaniChecklistItem] {
        (todo.checklistItems ?? []).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private func addChecklistItem() {
        let title = checklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let item = WaniChecklistItem(
            title: title,
            sortOrder: (sortedChecklistItems.map(\.sortOrder).max() ?? 0) + 1
        )
        if todo.checklistItems == nil {
            todo.checklistItems = []
        }
        todo.checklistItems?.append(item)
        modelContext.insert(item)
        checklistTitle = ""
        saveChanges()
    }

    private func toggleChecklistItem(_ item: WaniChecklistItem) {
        item.isCompleted.toggle()
        item.updatedAt = .now
        saveChanges()
    }

    private func deleteChecklistItem(_ item: WaniChecklistItem) {
        modelContext.delete(item)
        saveChanges()
    }

    private func saveTags() {
        todo.tagNames = WaniTaskRules.tags(from: tagDraft)
        todo.updatedAt = .now
        tagDraft = todo.tagNames.joined(separator: ", ")
        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }

    private func syncReminder() {
        Task {
            await WaniReminderScheduler.sync(
                todo,
                requestAuthorization: true,
                deadlineNotificationsEnabled: deadlineNotificationsEnabled
            )
        }
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
            if todo.deadline != nil {
                Image(systemName: "flag")
            }
            if todo.reminderDate != nil {
                Image(systemName: "bell")
            }
            if todo.repeatFrequency != .none {
                Image(systemName: "repeat")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(palette.tertiaryText)
    }

    private var dateLabel: String? {
        if todo.status != .open,
           let archivedAt = todo.completedAt ?? todo.canceledAt {
            return archivedAt.formatted(.dateTime.month(.abbreviated).day())
        }
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
        if todo.isEvening { return "moon.fill" }
        return todo.schedule == .date ? "calendar" : "tray"
    }
}

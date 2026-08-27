import SwiftUI
import SwiftData

struct WaniTaskRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let density: WaniListDensity
    let deadlineNotificationsEnabled: Bool
    let isSelected: Bool
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let finishTitleEditing: () -> Void
    let toggleCompleted: () -> Void
    let canLogNow: Bool
    let logNow: () -> Void
    let restore: () -> Void
    let deletePermanently: () -> Void
    let reorder: (UUID, UUID) -> Bool
    let recurrenceChanged: () -> Void

    @State private var checklistTitle = ""
    @State private var tagDraft = ""
    @State private var dateEditorOpen = false
    @State private var isHovered = false
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var checklistFieldFocused: Bool

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
                .buttonStyle(.waniInteractive(palette, showsHoverBackground: false))
                .accessibilityLabel(todo.status == .open ? "Complete" : "Reopen")

                if isExpanded {
                    TextField("New To-Do", text: todoTitleBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            todo.status == .open
                                ? palette.text
                                : palette.tertiaryText
                        )
                        .strikethrough(todo.status != .open)
                        .focused($titleFieldFocused)
                        .onSubmit(finishTitleEditing)
                        .onAppear {
                            Task { @MainActor in
                                titleFieldFocused = true
                            }
                        }
                } else {
                    Button(action: toggleExpanded) {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(displayTitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(
                                    todo.status == .open && hasTitle
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
                            badges
                        }
                        .contentShape(Rectangle())
                        .draggable("todo:\(todo.id.uuidString)")
                        .dropDestination(for: String.self) { values, _ in
                            guard
                                let value = values.first(where: { $0.hasPrefix("todo:") }),
                                let movingID = UUID(
                                    uuidString: String(value.dropFirst("todo:".count))
                                )
                            else { return false }
                            return reorder(movingID, todo.id)
                        }
                    }
                    .buttonStyle(.waniInteractive(palette, showsHoverBackground: false))
                }
            }

            if isExpanded {
                expandedEditor
                    .padding(.leading, 28)
                    .padding(.top, 10)
                    .transition(WaniMotion.revealTransition)
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 11)
        .padding(.vertical, isExpanded ? 14 : density.rowPadding)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isExpanded
                        ? palette.card
                        : (isSelected
                            ? palette.softAccent
                            : (isHovered ? palette.hover : Color.clear))
                )
                .shadow(
                    color: isExpanded
                        ? .black.opacity(colorScheme == .dark ? 0.18 : 0.08)
                        : .clear,
                    radius: isExpanded ? 10 : 0,
                    y: isExpanded ? 3 : 0
                )
        }
        .overlay {
            if isExpanded || isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? palette.accent.opacity(0.45) : palette.line, lineWidth: 0.5)
            }
        }
        .zIndex(isExpanded ? 1 : 0)
        .animation(WaniMotion.standard, value: isExpanded)
        .animation(WaniMotion.quick, value: isSelected)
        .animation(WaniMotion.quick, value: isHovered)
        .animation(WaniMotion.quick, value: todo.status)
        .onHover { isHovered = $0 }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                dateEditorOpen = false
            }
        }
        .onTapGesture { }
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: todoNotesBinding)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 52, maxHeight: 130)

            checklistEditor
            tagEditor

            Button("New Checklist") {
                checklistFieldFocused = true
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            if dateEditorOpen {
                WaniTaskDateEditor(
                    todo: todo,
                    palette: palette,
                    save: saveChanges,
                    reminderChanged: { syncReminder() },
                    recurrenceChanged: recurrenceChanged
                )
                .transition(WaniMotion.revealTransition)
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
                    if canLogNow {
                        Button(action: logNow) {
                            Image(systemName: "archivebox")
                        }
                        .keyboardShortcut("y", modifiers: [.command, .shift])
                        .accessibilityLabel("Move to Logbook Now")
                    }
                }
            }
            .buttonStyle(.waniInteractive(
                palette,
                horizontalPadding: 7,
                verticalPadding: 5
            ))
            .foregroundStyle(palette.tertiaryText)
        }
        .onAppear {
            tagDraft = todo.tagNames.joined(separator: ", ")
        }
        .animation(WaniMotion.standard, value: dateEditorOpen)
    }

    private var checklistEditor: some View {
        VStack(spacing: 0) {
            ForEach(sortedChecklistItems) { item in
                WaniChecklistRow(
                    item: item,
                    palette: palette,
                    toggle: { toggleChecklistItem(item) },
                    save: saveChanges,
                    delete: { deleteChecklistItem(item) },
                    reorder: reorderChecklistItem
                )
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.tertiaryText)
                TextField("Add checklist item", text: $checklistTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($checklistFieldFocused)
                    .onSubmit(addChecklistItem)
            }
            .padding(.vertical, 7)
            .overlay(alignment: .top) {
                Rectangle().fill(palette.faintLine).frame(height: 1)
            }
        }
        .animation(WaniMotion.standard, value: sortedChecklistItems.map(\.id))
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
                .transition(WaniMotion.revealTransition)
            }

            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundStyle(palette.tertiaryText)
                TextField("Tags, separated by commas", text: $tagDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .onSubmit(saveTags)
                Button("Save", action: saveTags)
                    .buttonStyle(.waniInteractive(
                        palette,
                        horizontalPadding: 7,
                        verticalPadding: 5
                    ))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.accent)
            }
        }
        .animation(WaniMotion.standard, value: todo.tagNames)
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

    private func reorderChecklistItem(_ movingID: UUID, before targetID: UUID) -> Bool {
        guard WaniTaskRules.reorderChecklistItems(
            sortedChecklistItems,
            moving: movingID,
            to: targetID
        ) else { return false }
        saveChanges()
        return true
    }

    private func saveTags() {
        WaniTaskRules.setTags(
            WaniTaskRules.tags(from: tagDraft),
            for: todo
        )
        tagDraft = todo.tagNames.joined(separator: ", ")
        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }

    private var todoTitleBinding: Binding<String> {
        Binding(
            get: { todo.title },
            set: { title in
                todo.title = title
                touchTodoAndSave()
            }
        )
    }

    private var todoNotesBinding: Binding<String> {
        Binding(
            get: { todo.notes },
            set: { notes in
                todo.notes = notes
                touchTodoAndSave()
            }
        )
    }

    private func touchTodoAndSave() {
        todo.updatedAt = .now
        saveChanges()
        // Typing only changes what a pending notification says, so it must never be
        // the moment the system permission prompt appears.
        syncReminder(requestAuthorization: false)
    }

    private func syncReminder(requestAuthorization: Bool = true) {
        Task {
            await WaniReminderScheduler.sync(
                todo,
                requestAuthorization: requestAuthorization,
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
            } else if let area = todo.area {
                Text(area.title)
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

    private var hasTitle: Bool {
        !todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayTitle: String {
        hasTitle ? todo.title : "New To-Do"
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

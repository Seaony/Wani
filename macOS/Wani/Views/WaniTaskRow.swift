import AppKit
import SwiftUI
import SwiftData

struct WaniTaskRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let knownTags: [String]
    let density: WaniListDensity
    let deadlineNotificationsEnabled: Bool
    let isSelected: Bool
    let isExpanded: Bool
    let isPendingCompletion: Bool
    let select: () -> Void
    let toggleExpanded: () -> Void
    let finishTitleEditing: () -> Void
    let toggleCompleted: () -> Void
    let canLogNow: Bool
    let logNow: () -> Void
    let reorder: (UUID, UUID) -> Bool
    let openRepeat: () -> Void
    let recurrenceChanged: () -> Void

    @State private var checklistTitle = ""
    @State private var tagDraft = ""
    @State private var dateEditorOpen = false
    @State private var deadlineEditorOpen = false
    @State private var tagEditorOpen = false
    @State private var isHovered = false
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var checklistFieldFocused: Bool
    @FocusState private var tagFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 11) {
                Button(action: toggleCompleted) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isVisuallyCompleted ? palette.accent : Color.clear)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                isVisuallyCompleted ? palette.accent : palette.tertiaryText,
                                lineWidth: 1.5
                            )
                        if isVisuallyCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 17, height: 17)
                }
                .buttonStyle(.waniInteractive(palette, showsHoverBackground: false))
                .accessibilityLabel(isVisuallyCompleted ? "Reopen" : "Complete")

                if isExpanded {
                    TextField("New To-Do", text: todoTitleBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            isVisuallyCompleted ? palette.tertiaryText : palette.text
                        )
                        .strikethrough(isVisuallyCompleted)
                        .focused($titleFieldFocused)
                        .onSubmit(finishTitleEditing)
                        .task {
                            try? await Task.sleep(for: .milliseconds(120))
                            guard !Task.isCancelled else { return }
                            titleFieldFocused = true
                        }
                } else {
                    Button(action: handleCollapsedRowClick) {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(displayTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    !isVisuallyCompleted && hasTitle
                                        ? palette.text : palette.tertiaryText
                                )
                                .strikethrough(isVisuallyCompleted)
                                .multilineTextAlignment(.leading)
                            if let dateLabel {
                                Text(dateLabel)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(palette.accent)
                            }
                            Spacer()
                            badges
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isExpanded {
                expandedEditor
                    .padding(.leading, 28)
                    .padding(.top, 10)
                    .transition(WaniMotion.taskEditorTransition)
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 11)
        .padding(.vertical, isExpanded ? 14 : density.rowPadding)
        .draggable("todo:\(todo.id.uuidString)")
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
        .animation(WaniMotion.quick, value: isSelected)
        .animation(WaniMotion.quick, value: isHovered)
        .animation(WaniMotion.quick, value: todo.status)
        .animation(WaniMotion.quick, value: isPendingCompletion)
        .onHover { isHovered = $0 }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                dateEditorOpen = false
                deadlineEditorOpen = false
                tagEditorOpen = false
            }
        }
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private func handleCollapsedRowClick() {
        if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
            toggleExpanded()
        } else {
            select()
        }
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: todoNotesBinding)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 52, maxHeight: 130)

            checklistEditor

            Button("New Checklist") {
                checklistFieldFocused = true
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            HStack {
                Button {
                    deadlineEditorOpen = false
                    tagEditorOpen = false
                    dateEditorOpen.toggle()
                } label: {
                    Label(scheduleLabel, systemImage: scheduleSymbol)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.secondaryText)
                }
                .popover(isPresented: $dateEditorOpen, arrowEdge: .bottom) {
                    WaniTaskDateEditor(
                        todo: todo,
                        palette: palette,
                        save: saveChanges,
                        reminderChanged: { syncReminder() },
                        recurrenceChanged: recurrenceChanged,
                        dismiss: { dateEditorOpen = false }
                    )
                }
                Spacer()
                tagControl
                Button {
                    dateEditorOpen = false
                    tagEditorOpen = false
                    deadlineEditorOpen.toggle()
                } label: {
                    if let deadline = todo.deadline {
                        Label(
                            deadline.formatted(.dateTime.month(.abbreviated).day()),
                            systemImage: "flag"
                        )
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.accent)
                    } else {
                        Image(systemName: "flag")
                            .foregroundStyle(palette.tertiaryText)
                    }
                }
                .popover(isPresented: $deadlineEditorOpen, arrowEdge: .bottom) {
                    WaniTaskDeadlineEditor(
                        todo: todo,
                        palette: palette,
                        save: saveChanges,
                        reminderChanged: { syncReminder() },
                        dismiss: { deadlineEditorOpen = false }
                    )
                }
                .accessibilityLabel(
                    todo.deadline == nil ? "Set Deadline" : "Edit Deadline"
                )
                if todo.deletedAt == nil {
                    Button {
                        dateEditorOpen = false
                        deadlineEditorOpen = false
                        tagEditorOpen = false
                        openRepeat()
                    } label: {
                        Image(systemName: "repeat")
                            .foregroundStyle(
                                todo.repeatFrequency == .none
                                    ? palette.tertiaryText : palette.accent
                            )
                    }
                    .accessibilityLabel(
                        todo.repeatFrequency == .none ? "Set Repeat" : "Edit Repeat"
                    )
                    if canLogNow {
                        Button(action: logNow) {
                            Image(systemName: "archivebox")
                        }
                        .keyboardShortcut("y", modifiers: [.command, .shift])
                        .accessibilityLabel("Move to Logbook Now")
                    }
                }
            }
            .animation(WaniMotion.quick, value: tagEditorOpen)
            .buttonStyle(.waniInteractive(
                palette,
                horizontalPadding: 7,
                verticalPadding: 5
            ))
            .foregroundStyle(palette.tertiaryText)
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

    @ViewBuilder
    private var tagControl: some View {
        if tagEditorOpen {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .foregroundStyle(palette.tertiaryText)
                TextField("Tag", text: $tagDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($tagFieldFocused)
                    .onSubmit(addDraftTag)
            }
            .padding(.horizontal, 8)
            .frame(width: 174, height: 28)
            .background(palette.selectionBackground, in: RoundedRectangle(cornerRadius: 7))
            .popover(isPresented: $tagEditorOpen, arrowEdge: .bottom) {
                tagSuggestions
            }
            .task {
                await Task.yield()
                guard tagEditorOpen else { return }
                tagFieldFocused = true
            }
            .transition(WaniMotion.overlayTransition)
        } else {
            Button {
                dateEditorOpen = false
                deadlineEditorOpen = false
                tagDraft = ""
                withAnimation(WaniMotion.quick) {
                    tagEditorOpen = true
                }
            } label: {
                Image(systemName: "tag")
                    .foregroundStyle(
                        todo.tagNames.isEmpty ? palette.tertiaryText : palette.accent
                    )
            }
            .accessibilityLabel(todo.tagNames.isEmpty ? "Add Tag" : "Edit Tags")
            .transition(WaniMotion.overlayTransition)
        }
    }

    private var tagSuggestions: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredKnownTags, id: \.self) { tag in
                    tagSuggestionButton(tag)
                }

                if canCreateDraftTag {
                    Button(action: addDraftTag) {
                        Label("Add “\(normalizedTagDraft)”", systemImage: "plus")
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.waniInteractive(palette))
                } else if filteredKnownTags.isEmpty {
                    Text("No tags yet")
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.tertiaryText)
                        .padding(.vertical, 18)
                }
            }
            .padding(6)
        }
        .frame(width: 230)
        .frame(maxHeight: 220)
        .background(palette.panel)
    }

    private func tagSuggestionButton(_ tag: String) -> some View {
        let isSelected = todo.tagNames.contains {
            $0.caseInsensitiveCompare(tag) == .orderedSame
        }

        return Button {
            setTag(tag, enabled: !isSelected)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? palette.accent : palette.tertiaryText)
                Text(tag)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.waniInteractive(palette))
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

    private var normalizedTagDraft: String {
        WaniTaskRules.tags(from: tagDraft).first ?? ""
    }

    private var filteredKnownTags: [String] {
        guard !normalizedTagDraft.isEmpty else { return knownTags }
        return knownTags.filter {
            $0.localizedCaseInsensitiveContains(normalizedTagDraft)
        }
    }

    private var canCreateDraftTag: Bool {
        !normalizedTagDraft.isEmpty && !knownTags.contains {
            $0.caseInsensitiveCompare(normalizedTagDraft) == .orderedSame
        }
    }

    private func addDraftTag() {
        guard !normalizedTagDraft.isEmpty else { return }
        let tag = knownTags.first {
            $0.caseInsensitiveCompare(normalizedTagDraft) == .orderedSame
        } ?? normalizedTagDraft
        setTag(tag, enabled: true)
        tagDraft = ""
    }

    private func setTag(_ tag: String, enabled: Bool) {
        var tags = todo.tagNames.filter {
            $0.caseInsensitiveCompare(tag) != .orderedSame
        }
        if enabled {
            tags.append(tag)
        }
        WaniTaskRules.setTags(tags, for: todo)
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

    private var isVisuallyCompleted: Bool {
        todo.status != .open || isPendingCompletion
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

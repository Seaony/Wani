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
    let showsCollapsedSchedule: Bool
    let showsCollapsedLocation: Bool
    let usesArchiveListStyle: Bool
    let deadlineNotificationsEnabled: Bool
    let isSelected: Bool
    let isExpanded: Bool
    let isPendingCompletion: Bool
    let monitorsSelectionDismissal: Bool
    let select: () -> Void
    let toggleExpanded: () -> Void
    let dismissExpanded: () -> Void
    let dismissSelection: () -> Void
    let openLocation: () -> Void
    let finishTitleEditing: () -> Void
    let toggleCompleted: () -> Void
    let canLogNow: Bool
    let logNow: () -> Void
    let reorder: (UUID, UUID) -> Bool
    let recurrenceChanged: () -> Void

    @State private var checklistTitle = ""
    @State private var tagDraft = ""
    @State private var deadlineDraft = ""
    @State private var dateEditorOpen = false
    @State private var deadlineEditorOpen = false
    @State private var tagEditorOpen = false
    @State private var tagSuggestionsOpen = false
    @State private var checklistEditorOpen = false
    @State private var dragPreviewWidth: CGFloat = 0
    @State private var titleSelection: TextSelection?
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var checklistFieldFocused: Bool
    @FocusState private var tagFieldFocused: Bool
    @FocusState private var deadlineFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 7) {
                Button(action: toggleCompleted) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(isVisuallyCompleted ? completionAccent : Color.clear)
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .stroke(
                                isVisuallyCompleted
                                    ? completionAccent
                                    : incompleteCheckboxColor,
                                lineWidth: isVisuallyCompleted ? 1.5 : 0.75
                            )
                        if isVisuallyCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: archiveCheckboxCheckmarkSize, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: archiveCheckboxSize, height: archiveCheckboxSize)
                    .frame(width: 15, height: 15)
                    .offset(y: isExpanded ? 0 : -0.5)
                }
                .buttonStyle(.waniInteractive(palette, showsHoverBackground: false))
                .accessibilityLabel(isVisuallyCompleted ? "Reopen" : "Complete")

                HStack(alignment: .center, spacing: 5) {
                    if !isExpanded, showsCollapsedSchedule {
                        if todo.status == .open, isScheduledByToday {
                            scheduleBadge("")
                                .transition(.opacity)
                        } else if let dateLabel {
                            scheduleBadge(dateLabel)
                                .transition(.opacity)
                        }
                    }

                    ZStack(alignment: .leading) {
                        TextField(
                            "New To-Do",
                            text: todoTitleBinding,
                            selection: $titleSelection
                        )
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(titleColor)
                            .strikethrough(titleUsesStrikethrough)
                            .multilineTextAlignment(.leading)
                            .focused($titleFieldFocused)
                            .opacity(isExpanded ? 1 : 0)
                            .allowsHitTesting(isExpanded)
                            .accessibilityHidden(!isExpanded)
                            .onSubmit(finishTitleEditing)
                            .onExitCommand(perform: dismissExpanded)
                            .task(id: isExpanded) {
                                guard isExpanded else { return }
                                await Task.yield()
                                guard !Task.isCancelled, isExpanded else { return }
                                titleFieldFocused = true
                                await Task.yield()
                                guard !Task.isCancelled, isExpanded else { return }
                                titleSelection = TextSelection(
                                    insertionPoint: todo.title.endIndex
                                )
                            }

                        VStack(alignment: .leading, spacing: 0) {
                            Text(displayTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(titleColor)
                                .strikethrough(titleUsesStrikethrough)
                                .lineLimit(1)
                            if (usesArchiveListStyle || showsCollapsedLocation),
                               !isExpanded,
                               let locationTitle {
                                Text(locationTitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.tertiaryText)
                                    .lineLimit(1)
                            }
                        }
                            .opacity(isExpanded ? 0 : 1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !isExpanded {
                        Spacer()
                        badges
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .overlay {
                    if !isExpanded {
                        Button(action: handleCollapsedRowClick) {
                            Color.clear
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.waniInteractive(
                            palette,
                            showsHoverBackground: false
                        ))
                        .accessibilityLabel(displayTitle)
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
                }
            }

            if isExpanded {
                expandedEditor
                    .transition(WaniMotion.taskEditorTransition)
                    .padding(.leading, 23)
                    .padding(.top, 10)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 10)
        .padding(.top, isExpanded ? 18 : collapsedVerticalPadding)
        .padding(.bottom, isExpanded ? 16 : collapsedVerticalPadding)
        .frame(minHeight: collapsedMinimumHeight)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            dragPreviewWidth = width
        }
        .draggable("todo:\(todo.id.uuidString)") {
            dragPreview
        }
        .background {
            RoundedRectangle(cornerRadius: isExpanded ? 13 : 7)
                .fill(
                    isExpanded
                        ? (colorScheme == .dark ? Color(hex: 0x363636) : palette.card)
                        : (isSelected ? taskSelectionBackground : Color.clear)
                )
                .padding(.horizontal, isExpanded ? -5 : 0)
                .shadow(
                    color: isExpanded
                        ? .black.opacity(colorScheme == .dark ? 0.26 : 0.08)
                        : .clear,
                    radius: isExpanded ? 5 : 0,
                    y: isExpanded ? 2 : 0
                )
                .animation(nil, value: isSelected)
            if isExpanded {
                WaniOutsideClickMonitor(dismiss: dismissExpanded)
                    .allowsHitTesting(false)
            } else if monitorsSelectionDismissal {
                WaniOutsideClickMonitor(dismiss: dismissSelection)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if isExpanded {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        colorScheme == .dark ? Color(hex: 0x333333) : palette.line,
                        lineWidth: 0.5
                    )
                    .padding(.horizontal, -5)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isExpanded, let locationTitle {
                Button(action: openLocation) {
                    HStack(spacing: 5) {
                        Image(systemName: todo.project == nil
                            ? (todo.area?.symbolName ?? "circle")
                            : "circle")
                            .font(.system(size: 14, weight: .medium))
                        Text(locationTitle)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(palette.tertiaryText)
                    .frame(height: 14)
                }
                .buttonStyle(.waniInteractive(
                    palette,
                    showsHoverBackground: false
                ))
                .padding(.trailing, 13)
                .offset(y: 24)
                .accessibilityLabel("Open \(locationTitle)")
            }
        }
        .padding(.bottom, isExpanded && locationTitle != nil ? 24 : 0)
        .zIndex(isExpanded ? 1 : 0)
        .animation(WaniMotion.quick, value: todo.status)
        .animation(WaniMotion.quick, value: isPendingCompletion)
        .onChange(of: isExpanded) { _, expanded in
            guard !expanded else { return }
            titleSelection = nil
            titleFieldFocused = false
            dateEditorOpen = false
            deadlineEditorOpen = false
            deadlineDraft = ""
            tagEditorOpen = false
            tagSuggestionsOpen = false
            checklistEditorOpen = false
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

    private var dragPreview: some View {
        HStack(alignment: .center, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(isVisuallyCompleted ? completionAccent : Color.clear)
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(
                        isVisuallyCompleted
                            ? completionAccent
                            : incompleteCheckboxColor,
                        lineWidth: isVisuallyCompleted ? 1.5 : 0.75
                    )
                if isVisuallyCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 10.5, height: 10.5)
            .frame(width: 15, height: 15)

            if let dateLabel {
                scheduleBadge(dateLabel)
            }

            Text(displayTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(titleColor)
                .strikethrough(titleUsesStrikethrough)
                .lineLimit(1)

            Spacer(minLength: 12)
            badges
        }
        .padding(.horizontal, 10)
        .padding(.vertical, density.rowPadding + 1)
        .frame(width: max(dragPreviewWidth, 280), alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.card)
                .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(palette.line, lineWidth: 0.5)
        }
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: todoNotesBinding)
                .font(.system(size: 13))
                .foregroundStyle(
                    colorScheme == .dark ? Color(hex: 0x8E8E8E) : palette.secondaryText
                )
                .scrollContentBackground(.hidden)
                .onExitCommand(perform: dismissExpanded)
                .overlay(alignment: .topLeading) {
                    if todo.notes.isEmpty {
                        Text("Notes")
                            .font(.system(size: 13))
                            .foregroundStyle(
                                colorScheme == .dark
                                    ? Color(hex: 0x8E8E8E)
                                    : palette.tertiaryText
                            )
                            .allowsHitTesting(false)
                    }
                }
                .padding(.leading, -5)
                .frame(minHeight: 31, maxHeight: 130)

            if !sortedChecklistItems.isEmpty {
                checklistEditor
                    .transition(WaniMotion.taskEditorTransition)
            }

            Button("New Checklist") {
                openChecklistEditor()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            HStack(spacing: 3) {
                Button {
                    deadlineEditorOpen = false
                    tagEditorOpen = false
                    checklistEditorOpen = false
                    dateEditorOpen.toggle()
                } label: {
                    HStack(spacing: 4) {
                        if isScheduledByToday, !todo.isEvening {
                            Image(systemName: scheduleSymbol)
                                .resizable()
                                .frame(width: 16, height: 14)
                                .foregroundStyle(scheduleSymbolColor)
                                .scaleEffect(y: 1.04, anchor: .top)
                                .offset(x: -1)
                        } else {
                            Image(systemName: scheduleSymbol)
                                .font(.system(size: 12.5))
                                .foregroundStyle(scheduleSymbolColor)
                        }
                        Text(scheduleLabel)
                            .font(.system(size: isScheduledByToday ? 13 : 12.5))
                            .foregroundStyle(scheduleTextColor)
                    }
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
                .padding(.leading, -6)
                Spacer()
                tagControl
                    .padding(.trailing, checklistEditorOpen ? 3 : 0)
                checklistControl
                deadlineControl
                if todo.deletedAt == nil, canLogNow {
                    Button(action: logNow) {
                        Image(systemName: "archivebox")
                    }
                    .keyboardShortcut("y", modifiers: [.command, .shift])
                    .accessibilityLabel("Move to Logbook Now")
                }
            }
            .padding(.trailing, 6)
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
        }
        .animation(WaniMotion.standard, value: sortedChecklistItems.map(\.id))
    }

    private func openChecklistEditor() {
        withAnimation(WaniMotion.taskExpansion) {
            checklistEditorOpen = true
        }
        focusChecklistFieldAfterOpening()
    }

    private func focusChecklistFieldAfterOpening() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard checklistEditorOpen else { return }
            checklistFieldFocused = true
        }
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
            .frame(width: 128, height: 24)
            .background(
                colorScheme == .dark ? Color(hex: 0x4A4A4A) : palette.selectionBackground,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .offset(y: 1)
            .popover(isPresented: $tagSuggestionsOpen, arrowEdge: .bottom) {
                tagSuggestions
            }
            .onExitCommand {
                if tagSuggestionsOpen {
                    tagSuggestionsOpen = false
                } else {
                    dismissExpanded()
                }
            }
            .task {
                await Task.yield()
                guard tagEditorOpen else { return }
                tagFieldFocused = true
                tagSuggestionsOpen = true
            }
            .transition(WaniMotion.overlayTransition)
        } else {
            Button {
                dateEditorOpen = false
                deadlineEditorOpen = false
                checklistEditorOpen = false
                tagDraft = ""
                withAnimation(WaniMotion.quick) {
                    tagEditorOpen = true
                }
            } label: {
                Image(systemName: "tag")
                    .foregroundStyle(
                        todo.tagNames.isEmpty ? palette.secondaryText : palette.accent
                    )
                    .opacity(todo.tagNames.isEmpty ? 0.92 : 1)
                    .scaleEffect(x: 0.98, y: 1.07, anchor: .topLeading)
                    .offset(x: 2, y: 2)
            }
            .accessibilityLabel(todo.tagNames.isEmpty ? "Add Tag" : "Edit Tags")
            .transition(WaniMotion.overlayTransition)
        }
    }

    private var tagSuggestions: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(filteredKnownTags.enumerated()), id: \.element) { index, tag in
                    tagSuggestionButton(tag, isHighlighted: index == 0)
                }

                if canCreateDraftTag {
                    Button(action: addDraftTag) {
                        HStack(spacing: 7) {
                            Image(systemName: "tag")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.65))
                            Text("Add “\(normalizedTagDraft)”")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 24)
                        .background(
                            Color(hex: 0x356ABB),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.waniInteractive(
                        palette,
                        cornerRadius: 7,
                        showsHoverBackground: false
                    ))
                } else if filteredKnownTags.isEmpty {
                    Text("No tags yet")
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.tertiaryText)
                        .padding(.vertical, 18)
                }
            }
            .padding(.leading, canCreateDraftTag ? 11.5 : 3.5)
            .padding(.trailing, canCreateDraftTag ? 1.5 : 9.5)
            .padding(.top, 1)
            .padding(.bottom, 6)
        }
        .frame(width: canCreateDraftTag ? 136 : 120)
        .frame(maxHeight: 220)
        .background(palette.panel)
    }

    @ViewBuilder
    private var deadlineControl: some View {
        if deadlineEditorOpen {
            HStack(spacing: 5) {
                Image(systemName: "flag")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.tertiaryText)
                TextField("Deadline", text: $deadlineDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .focused($deadlineFieldFocused)
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.tertiaryText)
                    .popover(isPresented: $deadlineEditorOpen, arrowEdge: .bottom) {
                        WaniTaskDeadlineEditor(
                            todo: todo,
                            palette: palette,
                            query: $deadlineDraft,
                            save: saveChanges,
                            reminderChanged: { syncReminder() },
                            dismiss: { deadlineEditorOpen = false }
                        )
                    }
            }
            .padding(.horizontal, 7)
            .frame(width: 128, height: 24)
            .background(
                colorScheme == .dark ? Color(hex: 0x4A4A4A) : palette.selectionBackground,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .offset(y: 1)
            .task {
                await Task.yield()
                guard deadlineEditorOpen else { return }
                deadlineFieldFocused = true
            }
            .transition(WaniMotion.overlayTransition)
        } else {
            Button {
                dateEditorOpen = false
                tagEditorOpen = false
                checklistEditorOpen = false
                deadlineDraft = ""
                withAnimation(WaniMotion.quick) {
                    deadlineEditorOpen = true
                }
            } label: {
                if let deadline = todo.deadline {
                    Label(
                        deadline.formatted(.dateTime.month(.abbreviated).day()),
                        systemImage: "flag"
                    )
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.accent)
                    .offset(y: 2)
                } else {
                    Image(systemName: "flag")
                        .fontWeight(.light)
                        .foregroundStyle(palette.secondaryText)
                        .brightness(0.11)
                        .scaleEffect(x: 1.20, y: 1.08, anchor: .trailing)
                        .offset(x: 1, y: 2)
                }
            }
            .accessibilityLabel(
                todo.deadline == nil ? "Set Deadline" : "Edit Deadline"
            )
            .transition(WaniMotion.overlayTransition)
        }
    }

    private func tagSuggestionButton(
        _ tag: String,
        isHighlighted: Bool
    ) -> some View {
        let isSelected = todo.tagNames.contains {
            $0.caseInsensitiveCompare(tag) == .orderedSame
        }

        return Button {
            setTag(tag, enabled: !isSelected)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "tag")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isHighlighted
                            ? Color.white.opacity(0.65)
                            : (isSelected ? palette.accent : palette.tertiaryText)
                    )
                Text(tag)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHighlighted ? Color.white : palette.text)
                Spacer()
            }
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(
                isHighlighted ? Color(hex: 0x356ABB) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 7,
            showsHoverBackground: !isHighlighted
        ))
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

    @ViewBuilder
    private var checklistControl: some View {
        if checklistEditorOpen {
            HStack(spacing: 5) {
                Image(systemName: "checklist")
                    .foregroundStyle(palette.tertiaryText)
                    .scaleEffect(x: 0.87, y: 1)
                TextField("Checklist", text: $checklistTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($checklistFieldFocused)
                    .onSubmit(addChecklistItem)
            }
            .padding(.horizontal, 3)
            .frame(width: 130, height: 24)
            .background(
                colorScheme == .dark ? Color(hex: 0x4A4A4A) : palette.selectionBackground,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .offset(y: 1)
            .transition(WaniMotion.overlayTransition)
        } else {
            Button {
                dateEditorOpen = false
                deadlineEditorOpen = false
                tagEditorOpen = false
                withAnimation(WaniMotion.quick) {
                    checklistEditorOpen = true
                }
                focusChecklistFieldAfterOpening()
            } label: {
                Image(systemName: "checklist")
                    .foregroundStyle(
                        sortedChecklistItems.isEmpty
                            ? palette.secondaryText
                            : palette.accent
                    )
                    .brightness(sortedChecklistItems.isEmpty ? 0.02 : 0)
                    .scaleEffect(x: 0.78, y: 1.11)
                    .offset(x: -0.5, y: 2)
            }
            .accessibilityLabel("Show Checklist")
            .transition(WaniMotion.overlayTransition)
        }
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
            if let checklist = todo.checklistItems, !checklist.isEmpty {
                Text("\(checklist.filter(\.isCompleted).count)/\(checklist.count)")
            }
            if !usesArchiveListStyle && !showsCollapsedLocation {
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

    @ViewBuilder
    private func scheduleBadge(_ label: String) -> some View {
        if todo.status == .open, isScheduledByToday {
            Image(systemName: todo.isEvening ? "moon.fill" : "star.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    todo.isEvening
                        ? palette.accent
                        : WaniSmartList.today.symbolColor
                )
                .accessibilityLabel(todo.isEvening ? "This Evening" : "Today")
        } else if usesArchiveListStyle, todo.status != .open {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(completionAccent)
                .frame(width: 50, alignment: .leading)
        } else {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    palette.selectionBackground,
                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                )
        }
    }

    private var hasTitle: Bool {
        !todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var locationTitle: String? {
        todo.project?.title ?? todo.area?.title
    }

    private var titleColor: Color {
        if usesArchiveListStyle, hasTitle {
            return palette.text
        }
        return !isVisuallyCompleted && hasTitle ? palette.text : palette.tertiaryText
    }

    private var titleUsesStrikethrough: Bool {
        isVisuallyCompleted && !usesArchiveListStyle
    }

    private var taskSelectionBackground: Color {
        colorScheme == .dark ? Color(hex: 0x254075) : palette.selectionBackground
    }

    private var completionAccent: Color {
        colorScheme == .dark ? Color(hex: 0x66ABFF) : palette.accent
    }

    private var incompleteCheckboxColor: Color {
        colorScheme == .dark ? Color(hex: 0x898C8F) : palette.tertiaryText
    }

    private var collapsedVerticalPadding: CGFloat {
        if usesArchiveListStyle || showsCollapsedLocation && locationTitle != nil {
            return 0
        }
        return density.rowPadding - 3.5
    }

    private var collapsedMinimumHeight: CGFloat? {
        guard !isExpanded else { return nil }
        if usesArchiveListStyle { return 33 }
        if showsCollapsedLocation, locationTitle != nil { return 39 }
        return nil
    }

    private var archiveCheckboxSize: CGFloat {
        usesArchiveListStyle && isVisuallyCompleted ? 13.5 : 11.5
    }

    private var archiveCheckboxCheckmarkSize: CGFloat {
        usesArchiveListStyle && isVisuallyCompleted ? 8 : 7
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
            if isScheduledByToday {
                todo.isEvening ? "Evening" : "Today"
            } else {
                todo.startDate?.formatted(date: .abbreviated, time: .omitted)
                    ?? "Scheduled"
            }
        }
    }

    private var scheduleSymbol: String {
        if todo.isEvening { return "moon.fill" }
        if isScheduledByToday {
            return "star.fill"
        }
        return todo.schedule == .date ? "calendar" : "tray"
    }

    private var scheduleSymbolColor: Color {
        if todo.isEvening { return palette.accent }
        if isScheduledByToday {
            return WaniSmartList.today.symbolColor
        }
        return palette.secondaryText
    }

    private var scheduleTextColor: Color {
        if isScheduledByToday {
            return palette.text
        }
        return palette.secondaryText
    }

    private var isScheduledByToday: Bool {
        guard todo.schedule == .date, let startDate = todo.startDate else {
            return false
        }
        let calendar = Calendar.current
        return calendar.startOfDay(for: startDate) <= calendar.startOfDay(for: .now)
    }
}

private struct WaniOutsideClickMonitor: NSViewRepresentable {
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.dismiss = dismiss
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var dismiss: () -> Void
        private var monitor: Any?
        private weak var view: NSView?

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func start(for view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) {
                [weak self] event in
                guard
                    let self,
                    let view = self.view,
                    let window = view.window,
                    event.window === window
                else { return event }

                let location = view.convert(event.locationInWindow, from: nil)
                guard !view.bounds.contains(location) else { return event }

                let dismiss = self.dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    dismiss()
                }
                return event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            stop()
        }
    }
}

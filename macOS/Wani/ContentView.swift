//
//  ContentView.swift
//  Wani
//
//  Created by seaony on 2026/8/26.
//

import AppKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaniArea.sortOrder) private var areas: [WaniArea]
    @Query(sort: \WaniProject.sortOrder) private var projects: [WaniProject]
    @Query(sort: \WaniHeading.sortOrder) private var headings: [WaniHeading]
    @Query(sort: \WaniTodo.sortOrder) private var todos: [WaniTodo]

    @AppStorage("appearance") private var appearanceRaw = WaniAppearance.light.rawValue
    @AppStorage("accent") private var accentRaw = WaniAccent.terracotta.rawValue
    @AppStorage("listDensity") private var densityRaw = WaniListDensity.medium.rawValue
    @AppStorage("showSidebarCounts") private var showSidebarCounts = true
    @AppStorage("showAreaLines") private var showAreaLines = true
    @AppStorage("quickEntryUsesCurrentList") private var quickEntryUsesCurrentList = true
    @AppStorage("launchDestination") private var launchDestinationRaw = WaniLaunchDestination.today.rawValue
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockBadge") private var showDockBadge = false
    @AppStorage("deadlineNotificationsEnabled") private var deadlineNotificationsEnabled = true
    @AppStorage("moveToLogbookAtMidnight") private var moveToLogbookAtMidnight = false

    @State private var selection: WaniNavigationTarget = .smart(.today)
    @State private var expandedTodoID: UUID?
    @State private var quickEntryOpen = false
    @State private var quickEntryTitle = ""
    @State private var searchOpen = false
    @State private var searchQuery = ""
    @State private var newListOpen = false
    @State private var settingsOpen = false
    @State private var addingHeading = false
    @State private var newHeadingTitle = ""
    @State private var appliedLaunchDestination = false
    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var selectionAnchorID: UUID?
    @State private var batchMoveOpen = false
    @State private var batchMoveQuery = ""

    private var appearance: WaniAppearance {
        get { WaniAppearance(rawValue: appearanceRaw) ?? .light }
        nonmutating set { appearanceRaw = newValue.rawValue }
    }

    private var accent: WaniAccent {
        get { WaniAccent(rawValue: accentRaw) ?? .terracotta }
        nonmutating set { accentRaw = newValue.rawValue }
    }

    private var density: WaniListDensity {
        get { WaniListDensity(rawValue: densityRaw) ?? .medium }
        nonmutating set { densityRaw = newValue.rawValue }
    }

    private var launchDestination: WaniLaunchDestination {
        get { WaniLaunchDestination(rawValue: launchDestinationRaw) ?? .today }
        nonmutating set { launchDestinationRaw = newValue.rawValue }
    }

    private var palette: WaniPalette {
        WaniPalette(colorScheme: colorScheme, accent: accent)
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                WaniSidebar(
                    palette: palette,
                    areas: areas,
                    projects: projects,
                    todos: todos,
                    counts: smartListCounts,
                    showCounts: showSidebarCounts,
                    showAreaLines: showAreaLines,
                    selection: $selection,
                    openSearch: { searchOpen = true },
                    openNewList: { newListOpen = true },
                    openSettings: { settingsOpen = true }
                )
                .frame(width: 258)

                mainContent
            }

            if quickEntryOpen {
                WaniQuickEntry(
                    palette: palette,
                    destination: destinationTitle,
                    title: $quickEntryTitle,
                    save: saveQuickEntry,
                    dismiss: closeQuickEntry
                )
            }

            if searchOpen {
                WaniSearchOverlay(
                    palette: palette,
                    todos: todos,
                    query: $searchQuery,
                    open: openSearchResult,
                    dismiss: closeSearch
                )
            }

            if newListOpen {
                WaniNewListOverlay(
                    palette: palette,
                    areas: areas,
                    saveArea: saveArea,
                    saveProject: saveProject,
                    dismiss: { newListOpen = false }
                )
            }

            if settingsOpen {
                WaniSettingsOverlay(
                    palette: palette,
                    appearance: Binding(get: { appearance }, set: { appearance = $0 }),
                    accent: Binding(get: { accent }, set: { accent = $0 }),
                    density: Binding(get: { density }, set: { density = $0 }),
                    showCounts: $showSidebarCounts,
                    showAreaLines: $showAreaLines,
                    quickEntryUsesCurrentList: $quickEntryUsesCurrentList,
                    launchDestination: Binding(
                        get: { launchDestination },
                        set: { launchDestination = $0 }
                    ),
                    showMenuBarIcon: $showMenuBarIcon,
                    showDockBadge: $showDockBadge,
                    deadlineNotificationsEnabled: $deadlineNotificationsEnabled,
                    moveToLogbookAtMidnight: $moveToLogbookAtMidnight,
                    dismiss: { settingsOpen = false }
                )
            }

            if batchMoveOpen {
                WaniBatchMoveOverlay(
                    palette: palette,
                    projects: projects,
                    headings: headings,
                    query: $batchMoveQuery,
                    moveToInbox: moveSelectedToInbox,
                    moveToProject: moveSelectedTodos,
                    dismiss: closeBatchMove
                )
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(palette.background)
        .tint(palette.accent)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            if !appliedLaunchDestination {
                selection = .smart(launchDestination.smartList)
                appliedLaunchDestination = true
            }
            updateDockBadge()
        }
        .onChange(of: showDockBadge) {
            updateDockBadge()
        }
        .onChange(of: todayCount) {
            updateDockBadge()
        }
        .onChange(of: deadlineNotificationsEnabled) {
            syncAllNotifications()
        }
        .onChange(of: selection) {
            clearTodoSelection()
        }
        .task {
            await syncNotifications()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Spacer()
                Button { } label: {
                    Image(systemName: "sidebar.left")
                }
                Button { } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 16)
            .frame(height: 46)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: pageSymbol)
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(pageSymbolColor)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(pageTitle)
                            .font(.system(size: 29, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundStyle(palette.text)
                        Text(pageMetadata)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.tertiaryText)
                    }
                }

                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 52)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 1) {
                    if case .project = selection {
                        projectTaskContent
                    } else if visibleTodos.isEmpty {
                        emptyState
                    } else {
                        taskRows(visibleTodos)
                    }
                }
                .padding(.horizontal, 52)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }

            Rectangle().fill(palette.faintLine).frame(height: 1)

            Group {
                if selectedTodoIDs.isEmpty {
                    standardToolbar
                } else {
                    batchToolbar
                }
            }
            .frame(height: 52)
        }
        .background(palette.panel)
    }

    private var visibleTodos: [WaniTodo] {
        switch selection {
        case .smart(let list):
            WaniTaskRules.tasks(
                todos,
                in: list,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            )
        case .project(let projectID):
            WaniTaskRules.projectTasks(todos, projectID: projectID)
                .filter {
                    $0.status == .open || WaniTaskRules.isAwaitingMidnightArchive(
                        $0,
                        enabled: moveToLogbookAtMidnight
                    )
                }
        }
    }

    private var projectHeadings: [WaniHeading] {
        guard case .project(let projectID) = selection else { return [] }
        return headings.filter { $0.project?.id == projectID }
    }

    @ViewBuilder
    private var projectTaskContent: some View {
        if visibleTodos.isEmpty && projectHeadings.isEmpty {
            emptyState
        }

        let ungrouped = visibleTodos.filter { $0.heading == nil }
        taskRows(ungrouped)

        ForEach(projectHeadings) { heading in
            let headingTodos = visibleTodos.filter { $0.heading?.id == heading.id }
            WaniHeadingRow(
                heading: heading,
                palette: palette,
                count: headingTodos.count,
                save: saveChanges
            )
            taskRows(headingTodos)
        }

        if addingHeading {
            HStack(spacing: 8) {
                TextField("New heading", text: $newHeadingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .onSubmit(saveHeading)
                Button("Cancel", action: closeHeadingComposer)
                    .buttonStyle(.plain)
                Button("Add", action: saveHeading)
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.accent)
                    .disabled(newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
        } else {
            Button {
                addingHeading = true
            } label: {
                Label("New Heading", systemImage: "plus")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.tertiaryText)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func taskRows(_ rows: [WaniTodo]) -> some View {
        ForEach(rows) { todo in
            WaniTaskRow(
                todo: todo,
                palette: palette,
                projects: projects,
                headings: headings,
                density: density,
                deadlineNotificationsEnabled: deadlineNotificationsEnabled,
                isSelected: selectedTodoIDs.contains(todo.id),
                isExpanded: expandedTodoID == todo.id,
                toggleExpanded: {
                    activate(todo)
                },
                toggleCompleted: { toggleStatus(todo) },
                cancelTodo: { cancel(todo) },
                moveToTrash: { moveToTrash(todo) },
                restore: { restore(todo) },
                deletePermanently: { deletePermanently(todo) },
                moveToInbox: { moveToInbox(todo) },
                moveToProject: { project, heading in
                    move(todo, to: project, heading: heading)
                }
            )
        }
    }

    private var smartListCounts: [WaniSmartList: Int] {
        Dictionary(uniqueKeysWithValues: WaniSmartList.allCases.map { list in
            (list, WaniTaskRules.tasks(
                todos,
                in: list,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            ).count)
        })
    }

    private var todayCount: Int {
        smartListCounts[.today] ?? 0
    }

    private var selectedTodos: [WaniTodo] {
        displayedTodoIDs.compactMap { id in
            todos.first { $0.id == id && selectedTodoIDs.contains(id) }
        }
    }

    private var displayedTodoIDs: [UUID] {
        guard case .project = selection else {
            return visibleTodos.map(\.id)
        }

        var ids = visibleTodos.filter { $0.heading == nil }.map(\.id)
        for heading in projectHeadings {
            ids.append(contentsOf: visibleTodos.filter { $0.heading?.id == heading.id }.map(\.id))
        }
        return ids
    }

    private var pageTitle: String {
        switch selection {
        case .smart(let list): list.title
        case .project(let id): projects.first { $0.id == id }?.title ?? "Project"
        }
    }

    private var pageMetadata: String {
        switch selection {
        case .smart(.today):
            return "\(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())) · \(visibleTodos.count) to do"
        case .smart(.upcoming):
            return "The days ahead · \(visibleTodos.count) scheduled"
        case .smart(.inbox):
            return visibleTodos.isEmpty ? "Everything is filed" : "\(visibleTodos.count) unsorted"
        case .smart(.anytime): return "Everything you could pick up now"
        case .smart(.someday): return "Kept warm for later"
        case .smart(.logbook): return "\(visibleTodos.count) completed"
        case .smart(.trash): return visibleTodos.isEmpty ? "Empty" : "\(visibleTodos.count) deleted"
        case .project(let id):
            let project = projects.first { $0.id == id }
            let progress = WaniTaskRules.projectProgress(todos, projectID: id)
            let openCount = WaniTaskRules.projectTasks(todos, projectID: id)
                .filter { $0.status == .open }.count
            let percentage = Int((progress * 100).rounded())
            let prefix: String
            if let areaTitle = project?.area?.title {
                prefix = "\(areaTitle) · "
            } else {
                prefix = ""
            }
            return "\(prefix)\(openCount) open · \(percentage)% complete"
        }
    }

    private var quickEntryDestination: WaniNavigationTarget {
        guard quickEntryUsesCurrentList, canAddToCurrentList else {
            return .smart(.inbox)
        }
        return selection
    }

    private var pageSymbol: String {
        switch selection {
        case .smart(let list): list.symbolName
        case .project: "circle"
        }
    }

    private var pageSymbolColor: Color {
        switch selection {
        case .smart(let list): list.symbolColor
        case .project: palette.accent
        }
    }

    private var destinationTitle: String {
        switch quickEntryDestination {
        case .smart(let list): list.title
        case .project(let id): projects.first { $0.id == id }?.title ?? "Inbox"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: pageSymbol)
                .font(.system(size: 29, weight: .light))
                .foregroundStyle(palette.tertiaryText)
                .frame(width: 74, height: 74)
                .overlay(Circle().stroke(palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                .padding(.bottom, 12)
            Text(emptyTitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(palette.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
            if canAddToCurrentList {
                Button("Capture something") {
                    quickEntryOpen = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 9))
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 82)
    }

    private var emptyTitle: String {
        switch selection {
        case .smart(.inbox): "Your Inbox is clear"
        case .smart(.today): "Nothing scheduled"
        case .smart(.upcoming): "The calendar is clear"
        case .smart(.logbook): "Nothing logged yet"
        case .smart(.trash): "The Trash is empty"
        case .project: "A blank project"
        default: "Empty for now"
        }
    }

    private var emptyMessage: String {
        switch selection {
        case .smart(.inbox): "Catch a thought the moment it arrives — press N anywhere in the app."
        case .smart(.today): "Pull something in from Anytime, or capture a new thought."
        case .smart(.upcoming): "Nothing is scheduled for the weeks ahead."
        case .smart(.logbook): "Completed to-dos collect here."
        case .smart(.trash): "Deleted to-dos wait here until you remove them permanently."
        case .project: "Add the first to-do and the shape of the work appears."
        default: "Nothing parked in this list."
        }
    }

    private var canAddToCurrentList: Bool {
        switch selection {
        case .smart(.logbook), .smart(.trash): false
        default: true
        }
    }

    private func toolbarButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 36, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var standardToolbar: some View {
        HStack(spacing: 4) {
            toolbarButton("plus", label: "New To-Do") {
                quickEntryOpen = true
            }
            .keyboardShortcut("n", modifiers: [])
            toolbarButton("plus.app", label: "Quick Entry") {
                quickEntryOpen = true
            }
            toolbarButton("calendar", label: "When") {
                selection = .smart(.upcoming)
            }
            toolbarButton("arrow.right", label: "Move") { }
            toolbarButton("magnifyingglass", label: "Search") {
                searchOpen = true
            }

            Button("Select All", action: selectAllTodos)
                .buttonStyle(.plain)
                .keyboardShortcut("a", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private var batchToolbar: some View {
        HStack(spacing: 8) {
            Text("\(selectedTodoIDs.count) selected")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .padding(.trailing, 8)

            Button("Copy", systemImage: "doc.on.doc", action: copySelectedTodos)
                .keyboardShortcut("c", modifiers: .command)

            Button("Complete", systemImage: "checkmark", action: completeSelectedTodos)
                .keyboardShortcut("k", modifiers: .command)
                .disabled(!selectedTodos.contains { $0.status == .open })

            Button("Cancel", systemImage: "xmark", action: cancelSelectedTodos)
                .keyboardShortcut("k", modifiers: [.command, .option])
                .disabled(!selectedTodos.contains { $0.status == .open })

            Button {
                batchMoveOpen = true
            } label: {
                Label("Move", systemImage: "arrow.right")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Button("Trash", systemImage: "trash", action: trashSelectedTodos)

            Spacer()

            Button("Deselect", action: clearTodoSelection)
                .keyboardShortcut("a", modifiers: [.command, .option])
        }
        .buttonStyle(.plain)
        .font(.system(size: 12.5))
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 18)
    }

    private func activate(_ todo: WaniTodo) {
        let modifiers = NSEvent.modifierFlags.intersection([.command, .shift])

        if modifiers.contains(.shift) {
            selectedTodoIDs.formUnion(WaniSelectionRules.range(
                from: selectionAnchorID,
                through: todo.id,
                in: displayedTodoIDs
            ))
            expandedTodoID = nil
            return
        }

        if modifiers.contains(.command) {
            if selectedTodoIDs.contains(todo.id) {
                selectedTodoIDs.remove(todo.id)
            } else {
                selectedTodoIDs.insert(todo.id)
            }
            selectionAnchorID = todo.id
            expandedTodoID = nil
            return
        }

        clearTodoSelection()
        expandedTodoID = expandedTodoID == todo.id ? nil : todo.id
    }

    private func selectAllTodos() {
        let ids = displayedTodoIDs
        guard !ids.isEmpty else { return }
        selectedTodoIDs = Set(ids)
        selectionAnchorID = ids.first
        expandedTodoID = nil
    }

    private func clearTodoSelection() {
        selectedTodoIDs.removeAll()
        selectionAnchorID = nil
        closeBatchMove()
    }

    private func copySelectedTodos() {
        let text = selectedTodos.map(\.title).joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func completeSelectedTodos() {
        for todo in selectedTodos where todo.status == .open {
            toggleCompleted(todo)
        }
        clearTodoSelection()
    }

    private func cancelSelectedTodos() {
        for todo in selectedTodos where todo.status == .open {
            WaniTaskRules.cancel(todo)
            WaniReminderScheduler.cancel(todo)
        }
        saveChanges()
        expandedTodoID = nil
        clearTodoSelection()
    }

    private func trashSelectedTodos() {
        for todo in selectedTodos {
            WaniTaskRules.moveToTrash(todo)
            WaniReminderScheduler.cancel(todo)
        }
        saveChanges()
        expandedTodoID = nil
        clearTodoSelection()
    }

    private func moveSelectedToInbox() {
        for todo in selectedTodos {
            WaniTaskRules.moveToInbox(todo)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func moveSelectedTodos(to project: WaniProject, heading: WaniHeading?) {
        for todo in selectedTodos {
            WaniTaskRules.move(todo, to: project, heading: heading)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func closeBatchMove() {
        batchMoveOpen = false
        batchMoveQuery = ""
    }

    private func saveQuickEntry() {
        let title = quickEntryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let todo: WaniTodo
        switch quickEntryDestination {
        case .smart(.today):
            todo = WaniTodo(
                title: title,
                schedule: .date,
                startDate: Calendar.current.startOfDay(for: .now)
            )
        case .smart(.upcoming):
            todo = WaniTodo(
                title: title,
                schedule: .date,
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)
            )
        case .smart(.anytime):
            todo = WaniTodo(title: title, schedule: .anytime)
        case .smart(.someday):
            todo = WaniTodo(title: title, schedule: .someday)
        case .project(let projectID):
            todo = WaniTodo(
                title: title,
                schedule: .anytime,
                project: projects.first { $0.id == projectID }
            )
        default:
            todo = WaniTodo(title: title, schedule: .inbox)
        }

        todo.sortOrder = (todos.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(todo)
        try? modelContext.save()
        closeQuickEntry()
    }

    private func toggleCompleted(_ todo: WaniTodo) {
        if todo.status == .open {
            if let next = WaniTaskRules.complete(todo) {
                modelContext.insert(next)
                Task {
                    await WaniReminderScheduler.sync(
                        next,
                        requestAuthorization: false,
                        deadlineNotificationsEnabled: deadlineNotificationsEnabled
                    )
                }
            }
            WaniReminderScheduler.cancel(todo)
        } else {
            WaniTaskRules.reopen(todo)
            Task {
                await WaniReminderScheduler.sync(
                    todo,
                    requestAuthorization: false,
                    deadlineNotificationsEnabled: deadlineNotificationsEnabled
                )
            }
        }
        try? modelContext.save()
    }

    private func toggleStatus(_ todo: WaniTodo) {
        if todo.status == .open, NSEvent.modifierFlags.contains(.option) {
            cancel(todo)
        } else {
            toggleCompleted(todo)
        }
    }

    private func cancel(_ todo: WaniTodo) {
        WaniTaskRules.cancel(todo)
        WaniReminderScheduler.cancel(todo)
        expandedTodoID = nil
        saveChanges()
    }

    private func moveToTrash(_ todo: WaniTodo) {
        WaniTaskRules.moveToTrash(todo)
        WaniReminderScheduler.cancel(todo)
        expandedTodoID = nil
        try? modelContext.save()
    }

    private func restore(_ todo: WaniTodo) {
        WaniTaskRules.restore(todo)
        expandedTodoID = nil
        try? modelContext.save()
        Task {
            await WaniReminderScheduler.sync(
                todo,
                requestAuthorization: false,
                deadlineNotificationsEnabled: deadlineNotificationsEnabled
            )
        }
    }

    private func deletePermanently(_ todo: WaniTodo) {
        expandedTodoID = nil
        WaniReminderScheduler.cancel(todo)
        modelContext.delete(todo)
        try? modelContext.save()
    }

    private func openSearchResult(_ todo: WaniTodo) {
        let primaryList = WaniTaskRules.primaryList(for: todo)
        if todo.status == .open, todo.deletedAt == nil, let project = todo.project {
            selection = .project(project.id)
        } else {
            selection = .smart(primaryList)
        }
        expandedTodoID = todo.id
        closeSearch()
    }

    private func saveArea(_ title: String) {
        let area = WaniArea(
            title: title,
            sortOrder: (areas.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(area)
        try? modelContext.save()
        newListOpen = false
    }

    private func saveProject(_ title: String, areaID: UUID?) {
        let area = areaID.flatMap { id in areas.first { $0.id == id } }
        let project = WaniProject(
            title: title,
            area: area,
            sortOrder: (projects.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(project)
        try? modelContext.save()
        selection = .project(project.id)
        expandedTodoID = nil
        newListOpen = false
    }

    private func saveHeading() {
        let title = newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !title.isEmpty,
            case .project(let projectID) = selection,
            let project = projects.first(where: { $0.id == projectID })
        else { return }

        let heading = WaniHeading(
            title: title,
            project: project,
            sortOrder: (projectHeadings.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(heading)
        saveChanges()
        closeHeadingComposer()
    }

    private func closeHeadingComposer() {
        addingHeading = false
        newHeadingTitle = ""
    }

    private func moveToInbox(_ todo: WaniTodo) {
        WaniTaskRules.moveToInbox(todo)
        saveChanges()
    }

    private func move(
        _ todo: WaniTodo,
        to project: WaniProject,
        heading: WaniHeading?
    ) {
        WaniTaskRules.move(todo, to: project, heading: heading)
        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }

    private func closeQuickEntry() {
        quickEntryOpen = false
        quickEntryTitle = ""
    }

    private func closeSearch() {
        searchOpen = false
        searchQuery = ""
    }

    private func updateDockBadge() {
        WaniDockBadge.update(enabled: showDockBadge, todayCount: todayCount)
    }

    private func syncAllNotifications() {
        Task {
            await syncNotifications()
        }
    }

    private func syncNotifications() async {
        for todo in todos {
            await WaniReminderScheduler.sync(
                todo,
                requestAuthorization: false,
                deadlineNotificationsEnabled: deadlineNotificationsEnabled
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(try! WaniPersistence.makeContainer(inMemory: true, cloudSync: false))
}

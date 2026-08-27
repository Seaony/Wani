//
//  ContentView.swift
//  Wani
//
//  Created by seaony on 2026/8/26.
//

import AppKit
import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @Query(sort: \WaniArea.sortOrder) private var areas: [WaniArea]
    @Query(sort: \WaniProject.sortOrder) private var projects: [WaniProject]
    @Query(sort: \WaniHeading.sortOrder) private var headings: [WaniHeading]
    @Query(sort: \WaniTodo.sortOrder) private var todos: [WaniTodo]
    @AppStorage("appearance") private var appearanceRaw = WaniAppearance.system.rawValue
    @AppStorage("accent") private var accentRaw = WaniAccent.terracotta.rawValue
    @AppStorage("listDensity") private var densityRaw = WaniListDensity.medium.rawValue
    @AppStorage("sidebarWidth") private var savedSidebarWidth = 220.0
    @AppStorage("showSidebarCounts") private var showSidebarCounts = true
    @AppStorage("showAreaLines") private var showAreaLines = true
    @AppStorage("quickEntryUsesCurrentList") private var quickEntryUsesCurrentList = true
    @AppStorage("launchDestination") private var launchDestinationRaw = WaniLaunchDestination.today.rawValue
    @AppStorage("showDockBadge") private var showDockBadge = false
    @AppStorage("dockCountMode") private var dockCountModeRaw = WaniDockCountMode.todayOnly.rawValue
    @AppStorage("textSize") private var textSizeRaw = WaniTextSize.standard.rawValue
    @AppStorage("groupTodayByProjectOrArea") private var groupTodayByProjectOrArea = true
    @AppStorage("keepWindowWidthWhenResizingSidebar") private var keepWindowWidth = true
    @AppStorage("deadlineNotificationsEnabled") private var deadlineNotificationsEnabled = true
    @AppStorage("moveToLogbookAtMidnight") private var moveToLogbookAtMidnight = false
    @AppStorage("globalQuickEntryShortcut") private var quickEntryShortcutRaw =
        WaniQuickEntryShortcut.controlSpace.rawValue

    @State private var selection: WaniNavigationTarget = .smart(.today)
    @State private var sidebarVisible = true
    @State private var sidebarWidth: Double
    @State private var expandedTodoID: UUID?
    @State private var quickEntryOpen = false
    @State private var quickEntryTitle = ""
    @State private var quickEntryInsertionAfterTodoID: UUID?
    @State private var widgetQuickEntryDestination: WaniNavigationTarget?
    @State private var widgetSnapshotRefreshTask: Task<Void, Never>?
    @State private var searchOpen = false
    @State private var searchQuery = ""
    @State private var addingHeading = false
    @State private var newHeadingTitle = ""
    @State private var groupingSelectionInNewHeading = false
    @State private var projectLogbookExpanded = false
    @State private var appliedLaunchDestination = false
    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var selectionAnchorID: UUID?
    @State private var batchMoveOpen = false
    @State private var batchMoveQuery = ""
    @State private var batchDateEditorOpen = false
    @State private var batchDeadlineEditorOpen = false
    @State private var batchTagEditorOpen = false
    @State private var toolbarDateEditorOpen = false
    @State private var repeatEditorTodoID: UUID?
    @State private var projectTagFilter: String?
    @State private var emptyTrashConfirmationOpen = false
    @State private var dateReference = Date.now
    @FocusState private var headerTitleFocused: Bool
    @FocusState private var headingTitleFocused: Bool

    init() {
        let initialSidebarWidth = (
            UserDefaults.standard.object(forKey: "sidebarWidth") as? NSNumber
        )?.doubleValue ?? 220
        _sidebarWidth = State(initialValue: initialSidebarWidth)
    }

    private var appearance: WaniAppearance {
        get { WaniAppearance(rawValue: appearanceRaw) ?? .system }
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

    private var dockCountMode: WaniDockCountMode {
        WaniDockCountMode(rawValue: dockCountModeRaw) ?? .todayOnly
    }

    private var textSize: WaniTextSize {
        WaniTextSize(rawValue: textSizeRaw) ?? .standard
    }

    private var launchDestination: WaniLaunchDestination {
        get { WaniLaunchDestination(rawValue: launchDestinationRaw) ?? .today }
        nonmutating set { launchDestinationRaw = newValue.rawValue }
    }

    private var quickEntryShortcut: WaniQuickEntryShortcut {
        get { WaniQuickEntryShortcut(rawValue: quickEntryShortcutRaw) ?? .controlSpace }
        nonmutating set { quickEntryShortcutRaw = newValue.rawValue }
    }

    private var palette: WaniPalette {
        WaniPalette(colorScheme: colorScheme, accent: accent)
    }

    var body: some View {
        lifecycleContent
    }

    private var rootContent: some View {
        ZStack {
            HStack(spacing: 0) {
                if sidebarVisible {
                    WaniSidebar(
                        palette: palette,
                        areas: areas,
                        projects: activeProjects,
                        counts: smartListCounts,
                        projectTallies: WaniTaskRules.projectTallies(todos),
                        areaOpenCounts: WaniTaskRules.openTodoCountsByArea(
                            todos,
                            projects: projects
                        ),
                        showCounts: showSidebarCounts,
                        showAreaLines: showAreaLines,
                        selection: $selection,
                        openSearch: { searchOpen = true },
                        createArea: createArea,
                        createProject: createProject,
                        reorderArea: reorderArea,
                        reorderProject: reorderProject,
                        openSettings: { openSettings() }
                    )
                    .frame(width: sidebarWidth)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(palette.sidebarDivider)
                            .frame(width: 1)
                            .ignoresSafeArea(edges: .vertical)
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .trailing) {
                        WaniSidebarDivider(
                            sidebarWidth: $sidebarWidth,
                            keepWindowWidth: keepWindowWidth,
                            resizeEnded: { savedSidebarWidth = $0 }
                        )
                    }
                    .transition(WaniMotion.sidebarTransition)
                }

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
                .transition(WaniMotion.overlayTransition)
            }

            if searchOpen {
                WaniSearchOverlay(
                    palette: palette,
                    areas: areas,
                    projects: projects,
                    todos: todos,
                    deferCompletedUntilMidnight: moveToLogbookAtMidnight,
                    query: $searchQuery,
                    openArea: openSearchResult,
                    openProject: openSearchResult,
                    openTodo: openSearchResult,
                    dismiss: closeSearch
                )
                .transition(WaniMotion.overlayTransition)
            }

            if let todo = repeatEditorTodo {
                WaniRepeatEditor(
                    todo: todo,
                    palette: palette,
                    apply: applyRepeatConfiguration,
                    dismiss: closeRepeatEditor
                )
                // The editor seeds its @State from the to-do in init, so switching
                // to-dos has to be a new identity or the old draft would stick.
                .id(todo.id)
                .transition(WaniMotion.overlayTransition)
            }

            if batchMoveOpen {
                WaniBatchMoveOverlay(
                    palette: palette,
                    areas: areas,
                    projects: activeProjects,
                    headings: activeHeadings,
                    query: $batchMoveQuery,
                    moveToInbox: moveSelectedToInbox,
                    moveToArea: moveSelectedTodos,
                    moveToProject: moveSelectedTodos,
                    dismiss: closeBatchMove
                )
                .transition(WaniMotion.overlayTransition)
            }

            navigationShortcuts

            WaniKeyEventMonitor(handle: handleTaskListKeyEvent)
                .frame(width: 0, height: 0)

        }
        .animation(WaniMotion.standard, value: sidebarVisible)
        .animation(WaniMotion.overlay, value: quickEntryOpen)
        .animation(WaniMotion.overlay, value: searchOpen)
        .animation(WaniMotion.overlay, value: repeatEditorTodoID)
        .animation(WaniMotion.overlay, value: batchMoveOpen)
        .frame(minWidth: 760, minHeight: 520)
    }

    private var styledContent: some View {
        rootContent
        .focusedSceneValue(
            \.waniItemCommandActions,
            WaniItemCommandActions(
                canEdit: !selectedTodos.isEmpty || focusedToolbarTodo != nil,
                canClose: selectedTodos.contains { $0.status == .open }
                    || focusedToolbarTodo != nil
                    || canCloseSelectedProject,
                canDuplicate: !duplicateCommandTodos.isEmpty,
                canRepeat: repeatCommandTodo != nil,
                canSaveAndClose: focusedToolbarTodo != nil,
                canTrash: selectedTodos.contains { $0.deletedAt == nil }
                    || focusedToolbarTodo != nil,
                openWhen: openWhenCommand,
                openMove: openMoveCommand,
                openTags: openTagsCommand,
                openDeadline: openDeadlineCommand,
                openRepeat: openRepeatCommand,
                copy: copyItemCommand,
                paste: pasteTodosFromClipboard,
                duplicate: duplicateItemCommand,
                saveAndClose: saveAndCloseItemCommand,
                complete: completeItemCommand,
                cancel: cancelItemCommand,
                moveToTrash: trashItemCommand
            )
        )
        .background(palette.background)
        .tint(palette.accent)
        .buttonStyle(.waniInteractive(palette))
        .preferredColorScheme(appearance.colorScheme)
        .dynamicTypeSize(textSize.dynamicTypeSize)
    }

    private var lifecycleContent: some View {
        styledContent
        .onAppear {
            if !appliedLaunchDestination {
                selection = .smart(launchDestination.smartList)
                appliedLaunchDestination = true
            }
            updateDockBadge()
            registerGlobalQuickEntry()
            generateDueRepeatingTodos()
            refreshWidgetSnapshot()
        }
        .onOpenURL(perform: handleWidgetDeepLink)
        .onChange(of: widgetSnapshotRevision) {
            scheduleWidgetSnapshotRefresh()
            updateDockBadge()
        }
        .onChange(of: showDockBadge) {
            updateDockBadge()
        }
        .onChange(of: todayCount) {
            updateDockBadge()
        }
        .onChange(of: dockCountModeRaw) {
            updateDockBadge()
        }
        .onChange(of: deadlineNotificationsEnabled) {
            syncAllNotifications()
        }
        .onChange(of: selection) {
            clearTodoSelection()
            expandedTodoID = nil
            projectTagFilter = nil
            projectLogbookExpanded = false
            toolbarDateEditorOpen = false
            closeHeadingComposer()
        }
        .onChange(of: expandedTodoID) {
            toolbarDateEditorOpen = false
        }
        .onChange(of: quickEntryShortcutRaw) {
            registerGlobalQuickEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waniOpenQuickEntry)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            searchOpen = false
            quickEntryOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dateReference = .now
            generateDueRepeatingTodos()
        }
        .task {
            await syncNotifications()
        }
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $emptyTrashConfirmationOpen,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive, action: emptyTrash)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All projects and to-dos in the Trash will be permanently deleted.")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Spacer()
                Button {
                    sidebarVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .keyboardShortcut("/", modifiers: .command)
                .accessibilityLabel(sidebarVisible ? "Hide Sidebar" : "Show Sidebar")
            }
            .buttonStyle(.waniInteractive(palette))
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 16)
            .frame(height: 46)

            pageHeader

            VStack(alignment: .leading, spacing: 0) {
                if selectedProject != nil, !projectTagNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            projectTagButton("All", tag: nil)
                            ForEach(projectTagNames, id: \.self) { tag in
                                projectTagButton(tag, tag: tag)
                            }
                        }
                    }
                    .padding(.top, 18)
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
                    } else if case .area = selection {
                        areaTaskContent
                    } else if selection == .smart(.today) {
                        todayTaskContent
                    } else if selection == .smart(.upcoming) {
                        upcomingTaskContent
                    } else if selection == .smart(.logbook) {
                        logbookTaskContent
                    } else if selection == .smart(.trash) {
                        trashTaskContent
                    } else if selection == .smart(.anytime) || selection == .smart(.someday) {
                        smartProjectTaskContent
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

            Rectangle().fill(palette.sidebarDivider).frame(height: 1)

            Group {
                if selectedTodos.isEmpty {
                    standardToolbar
                        .transition(WaniMotion.overlayTransition)
                } else {
                    batchToolbar
                        .transition(WaniMotion.overlayTransition)
                }
            }
            .animation(WaniMotion.quick, value: selectedTodos.isEmpty)
            .frame(height: 52)
        }
        .background(palette.panel)
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: pageSymbol)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(pageSymbolColor)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    if selectedProject != nil || selectedArea != nil {
                        TextField(pageTitle, text: pageTitleBinding)
                            .textFieldStyle(.plain)
                            .font(.system(size: 29, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundStyle(palette.text)
                            .frame(width: pageTitleFieldWidth, height: 36, alignment: .leading)
                            .focused($headerTitleFocused)
                            .onSubmit(normalizePageTitle)
                            .onChange(of: headerTitleFocused) { _, isFocused in
                                if !isFocused {
                                    normalizePageTitle()
                                }
                            }
                            .accessibilityLabel(selectedProject == nil ? "Area Name" : "Project Name")
                    } else {
                        Text(pageTitle)
                            .font(.system(size: 29, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundStyle(palette.text)
                    }

                    pageActions
                    Spacer(minLength: 0)
                }

                if selectedProject != nil {
                    TextField("Notes", text: projectNotesBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1...4)
                        .accessibilityLabel("Project Notes")
                }

                Text(pageMetadata)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .padding(.horizontal, 52)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var pageActions: some View {
        if let project = selectedProject {
            Menu {
                if project.completedAt != nil || project.canceledAt != nil {
                    Button("Reopen Project", systemImage: "arrow.uturn.backward.circle") {
                        reopen(project)
                    }
                } else {
                    Button("Complete Project", systemImage: "checkmark.circle") {
                        completeSelectedProject()
                    }
                    .disabled(!canCloseSelectedProject)

                    Button("Cancel Project", systemImage: "xmark.circle") {
                        cancelSelectedProject()
                    }
                    .disabled(!canCloseSelectedProject)

                    Menu("Move to Area", systemImage: "folder") {
                        Button("No Area") {
                            moveSelectedProject(to: nil)
                        }
                        ForEach(areas) { area in
                            Button(area.title) {
                                moveSelectedProject(to: area)
                            }
                        }
                    }
                }

                Divider()

                Button("Move to Trash", systemImage: "trash", role: .destructive) {
                    moveSelectedProjectToTrash()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .waniPointerFeedback(palette: palette)
            .accessibilityLabel("Project Actions")
        } else if selectedArea != nil {
            Menu {
                Button("New Project", systemImage: "circle", action: createProject)

                Divider()

                Button("Delete Area", systemImage: "trash", role: .destructive) {
                    deleteSelectedArea()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .waniPointerFeedback(palette: palette)
            .accessibilityLabel("Area Actions")
        } else if selection == .smart(.trash), trashItemCount > 0 {
            Menu {
                Button("Empty Trash…", systemImage: "trash.slash", role: .destructive) {
                    emptyTrashConfirmationOpen = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .waniPointerFeedback(palette: palette)
            .accessibilityLabel("Trash Actions")
        }
    }

    private var visibleTodos: [WaniTodo] {
        switch selection {
        case .smart(let list):
            WaniTaskRules.tasks(
                todos,
                in: list,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            )
        case .area(let areaID):
            todos.filter { todo in
                (todo.area?.id == areaID || todo.project?.area?.id == areaID)
                    && todo.deletedAt == nil
                    && (todo.status == .open || WaniTaskRules.isAwaitingMidnightArchive(
                        todo,
                        enabled: moveToLogbookAtMidnight
                    ))
            }
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
        return headings.filter {
            $0.project?.id == projectID && $0.archivedAt == nil
        }
    }

    private var projectLoggedTodos: [WaniTodo] {
        guard case .project(let projectID) = selection else { return [] }
        let logged = WaniTaskRules.projectTasks(todos, projectID: projectID)
            .filter {
                WaniTaskRules.isProjectLogged(
                    $0,
                    deferCompletedUntilMidnight: moveToLogbookAtMidnight
                )
            }
        return WaniTaskRules.tasks(logged, matchingTag: activeProjectTagFilter)
    }

    private var projectLoggedHeadings: [WaniHeading] {
        guard case .project(let projectID) = selection else { return [] }
        let loggedHeadingIDs = Set(projectLoggedTodos.compactMap { $0.heading?.id })
        return headings.filter {
            $0.project?.id == projectID
                && ($0.archivedAt != nil || loggedHeadingIDs.contains($0.id))
        }
    }

    private var projectLoggedItemCount: Int {
        let emptyArchivedHeadings = projectLoggedHeadings.filter { heading in
            !projectLoggedTodos.contains { $0.heading?.id == heading.id }
        }.count
        return projectLoggedTodos.count + emptyArchivedHeadings
    }

    private var selectedProject: WaniProject? {
        guard case .project(let projectID) = selection else { return nil }
        return projects.first { $0.id == projectID }
    }

    private var canCloseSelectedProject: Bool {
        guard
            let selectedProject,
            selectedProject.completedAt == nil,
            selectedProject.canceledAt == nil
        else { return false }
        return WaniTaskRules.canCompleteProject(
            selectedProject,
            todos: todos,
            headings: headings
        )
    }

    private var selectedArea: WaniArea? {
        guard case .area(let areaID) = selection else { return nil }
        return areas.first { $0.id == areaID }
    }

    private var projectTagNames: [String] {
        guard selectedProject != nil else { return [] }
        return WaniTaskRules.tags(in: visibleTodos)
    }

    private var activeProjectTagFilter: String? {
        guard let projectTagFilter,
              projectTagNames.contains(where: {
                  $0.caseInsensitiveCompare(projectTagFilter) == .orderedSame
              }) else {
            return nil
        }
        return projectTagFilter
    }

    private var filteredProjectTodos: [WaniTodo] {
        WaniTaskRules.tasks(visibleTodos, matchingTag: activeProjectTagFilter)
    }

    private func projectTagButton(_ title: String, tag: String?) -> some View {
        let isSelected = activeProjectTagFilter == tag
        return Button {
            projectTagFilter = tag
            expandedTodoID = nil
            clearTodoSelection()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(isSelected ? palette.softAccent : Color.clear, in: Capsule())
        }
        .buttonStyle(.waniInteractive(palette, cornerRadius: 12))
        .accessibilityLabel("Filter by \(title)")
    }

    @ViewBuilder
    private var todayTaskContent: some View {
        if visibleTodos.isEmpty {
            emptyState
        } else {
            let daytimeTodos = WaniTaskRules.todayTasks(
                todos,
                evening: false,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            )
            let eveningTodos = WaniTaskRules.todayTasks(
                todos,
                evening: true,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            )

            ForEach(todayGroups(daytimeTodos)) { group in
                if let title = group.title {
                    listSectionHeader(title, count: group.todos.count)
                }
                taskRows(group.todos)
            }

            if !eveningTodos.isEmpty {
                listSectionHeader(
                    "This Evening",
                    subtitle: "after 18:00",
                    count: eveningTodos.count
                )
                ForEach(todayGroups(eveningTodos)) { group in
                    if let title = group.title {
                        listSectionHeader(title, count: group.todos.count)
                    }
                    taskRows(group.todos)
                }
            }
        }
    }

    private func listSectionHeader(
        _ title: String,
        subtitle: String? = nil,
        count: Int
    ) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
            }
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
            Text(count.formatted())
                .font(.system(size: 11))
        }
        .foregroundStyle(palette.tertiaryText)
        .padding(.horizontal, 11)
        .padding(.top, 17)
        .padding(.bottom, 5)
    }

    private func todayGroups(_ source: [WaniTodo]) -> [WaniTodayGroup] {
        guard groupTodayByProjectOrArea else {
            return source.isEmpty
                ? []
                : [WaniTodayGroup(id: "all", title: nil, todos: source)]
        }

        var groups: [WaniTodayGroup] = []
        var indices: [String: Int] = [:]
        for todo in source {
            let id: String
            let title: String?
            if let project = todo.project {
                id = "project-\(project.id.uuidString)"
                title = project.title
            } else if let area = todo.area {
                id = "area-\(area.id.uuidString)"
                title = area.title
            } else {
                id = "standalone"
                title = nil
            }

            if let index = indices[id] {
                groups[index].todos.append(todo)
            } else {
                indices[id] = groups.count
                groups.append(WaniTodayGroup(id: id, title: title, todos: [todo]))
            }
        }
        return groups
    }

    @ViewBuilder
    private var upcomingTaskContent: some View {
        if visibleTodos.isEmpty {
            emptyState
        } else {
            let days = WaniTaskRules.upcomingDays(
                todos,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            )
            ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                if index > 0, !Calendar.current.isDate(
                    days[index - 1].date,
                    equalTo: day.date,
                    toGranularity: .month
                ) {
                    Text(day.date.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 13))
                        .foregroundStyle(palette.tertiaryText)
                        .padding(.horizontal, 11)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                }

                upcomingDayHeader(day)
                if day.todos.isEmpty {
                    Color.clear.frame(height: 14)
                } else {
                    taskRows(day.todos)
                }
            }
        }
    }

    private func upcomingDayHeader(_ day: WaniUpcomingDay) -> some View {
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: .now)
        )!
        let label = Calendar.current.isDate(day.date, inSameDayAs: tomorrow)
            ? "Tomorrow"
            : day.date.formatted(.dateTime.weekday(.wide))

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 25, weight: .semibold))
                .tracking(-0.3)
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.secondaryText)
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
            if !day.todos.isEmpty {
                Text("\(day.todos.count) \(day.todos.count == 1 ? "item" : "items")")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, 11)
        .padding(.bottom, 9)
    }

    @ViewBuilder
    private var smartProjectTaskContent: some View {
        let listTodos = visibleTodos
        if listTodos.isEmpty {
            emptyState
        } else {
            // Grouping once keeps this off the (areas + projects) × to-dos path that
            // re-filtering `visibleTodos` inside each ForEach would take.
            let byArea = Dictionary(grouping: listTodos.filter { $0.project == nil }) {
                $0.area?.id
            }
            let byProject = Dictionary(
                grouping: listTodos.filter { $0.project != nil }
            ) { $0.project?.id }

            taskRows(byArea[nil] ?? [])

            ForEach(areas) { area in
                if let areaTodos = byArea[area.id], !areaTodos.isEmpty {
                    smartAreaHeader(area)
                    taskRows(areaTodos)
                }
            }

            ForEach(activeProjects) { project in
                if let projectTodos = byProject[project.id], !projectTodos.isEmpty {
                    smartProjectHeader(project)
                    taskRows(projectTodos)
                }
            }
        }
    }

    @ViewBuilder
    private var areaTaskContent: some View {
        let areaProjects = activeProjects.filter { $0.area?.id == selectedArea?.id }
        let listTodos = visibleTodos
        let areaTodos = listTodos.filter { $0.area?.id == selectedArea?.id }
        let byProject = Dictionary(grouping: listTodos.filter { $0.project != nil }) {
            $0.project?.id
        }
        if areaProjects.isEmpty && areaTodos.isEmpty {
            emptyState
        } else {
            taskRows(areaTodos)

            ForEach(areaProjects) { project in
                Button {
                    selection = .project(project.id)
                } label: {
                    smartProjectHeader(project)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel(project.title)

                taskRows(byProject[project.id] ?? [])
            }
        }
    }

    private func smartProjectHeader(_ project: WaniProject) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(project.title)
                .font(.system(size: 13.5, weight: .semibold))
                .tracking(-0.1)
            if let areaTitle = project.area?.title {
                Text(areaTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tertiaryText)
            }
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, 11)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func smartAreaHeader(_ area: WaniArea) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(area.title)
                .font(.system(size: 13.5, weight: .semibold))
                .tracking(-0.1)
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, 11)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var logbookTaskContent: some View {
        if visibleTodos.isEmpty && archivedProjects.isEmpty {
            emptyState
        } else {
            ForEach(logbookMonthDates, id: \.self) { month in
                HStack(spacing: 10) {
                    Text(month.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 13.5, weight: .semibold))
                    Rectangle()
                        .fill(palette.line)
                        .frame(height: 1)
                }
                .foregroundStyle(palette.text)
                .padding(.horizontal, 11)
                .padding(.top, 8)
                .padding(.bottom, 8)
                ForEach(
                    archivedProjectMonths.first { $0.month == month }?.projects ?? []
                ) { project in
                    loggedProjectRow(project)
                }
                if let todoGroup = logbookMonths.first(where: { $0.month == month }) {
                    taskRows(todoGroup.todos)
                }
            }
        }
    }

    private var logbookMonths: [WaniLogbookMonth] {
        WaniTaskRules.logbookMonths(
            todos,
            deferCompletedUntilMidnight: moveToLogbookAtMidnight
        )
    }

    private var archivedProjects: [WaniProject] {
        projects.filter {
            ($0.completedAt != nil || $0.canceledAt != nil) && $0.deletedAt == nil
        }
    }

    private var activeProjects: [WaniProject] {
        projects.filter {
            $0.completedAt == nil && $0.canceledAt == nil && $0.deletedAt == nil
        }
    }

    private var activeHeadings: [WaniHeading] {
        let projectIDs = Set(activeProjects.map(\.id))
        return headings.filter { heading in
            guard let projectID = heading.project?.id else { return false }
            return projectIDs.contains(projectID) && heading.archivedAt == nil
        }
    }

    private var archivedProjectMonths: [WaniArchivedProjectMonth] {
        WaniTaskRules.archivedProjectMonths(projects)
    }

    private var logbookMonthDates: [Date] {
        Set(logbookMonths.map(\.month) + archivedProjectMonths.map(\.month)).sorted(by: >)
    }

    private var trashedProjects: [WaniProject] {
        projects
            .filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    /// To-dos deleted along with their project are represented by the project's own
    /// row. One deleted on its own beforehand is not, and `restoreProject` will not
    /// bring it back either, so it has to keep its own row here.
    private var standaloneTrashedTodos: [WaniTodo] {
        WaniTaskRules.tasks(todos, in: .trash).filter { todo in
            guard let projectDeletedAt = todo.project?.deletedAt else { return true }
            return todo.deletedAt != projectDeletedAt
        }
    }

    private var trashItemCount: Int {
        trashedProjects.count + standaloneTrashedTodos.count
    }

    private func loggedProjectRow(_ project: WaniProject) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 11) {
            Button {
                reopen(project)
            } label: {
                Image(systemName: project.canceledAt == nil
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(palette.accent)
            }
            .buttonStyle(.waniInteractive(palette))
            .accessibilityLabel("Reopen Project")

            Text(project.title)
                .font(.system(size: 13.5))
                .foregroundStyle(palette.tertiaryText)
                .strikethrough()
            if let archivedAt = project.completedAt ?? project.canceledAt {
                Text(archivedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.accent)
            }
            Spacer()
            Text(project.area?.title ?? "Project")
                .font(.system(size: 11))
                .foregroundStyle(palette.tertiaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(palette.hover, in: Capsule())
        }
        .padding(.horizontal, 11)
        .padding(.vertical, density.rowPadding)
    }

    @ViewBuilder
    private var trashTaskContent: some View {
        if trashedProjects.isEmpty && standaloneTrashedTodos.isEmpty {
            emptyState
        } else {
            ForEach(trashedProjects) { project in
                trashedProjectRow(project)
            }
            taskRows(standaloneTrashedTodos)
        }
    }

    private func trashedProjectRow(_ project: WaniProject) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "circle")
                .font(.system(size: 17))
                .foregroundStyle(palette.tertiaryText)
            Text(project.title)
                .font(.system(size: 13.5))
                .foregroundStyle(palette.text)
            let childCount = todos.filter { $0.project?.id == project.id }.count
            Text("\(childCount) \(childCount == 1 ? "to-do" : "to-dos")")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.tertiaryText)
            Spacer()
            Button("Restore") {
                restore(project)
            }
            Button("Delete", role: .destructive) {
                deletePermanently(project)
            }
        }
        .buttonStyle(.waniInteractive(palette))
        .padding(.horizontal, 11)
        .padding(.vertical, density.rowPadding)
    }

    @ViewBuilder
    private var projectTaskContent: some View {
        if visibleTodos.isEmpty && projectHeadings.isEmpty && projectLoggedItemCount == 0 {
            emptyState
        }

        let byHeading = Dictionary(grouping: filteredProjectTodos) { $0.heading?.id }
        taskRows(byHeading[nil] ?? [])

        ForEach(projectHeadings) { heading in
            let headingTodos = byHeading[heading.id] ?? []
            WaniHeadingRow(
                heading: heading,
                palette: palette,
                canArchive: WaniTaskRules.canArchiveHeading(heading, todos: todos),
                save: saveChanges,
                archive: { archive(heading) },
                reorder: reorderHeading
            )
            taskRows(headingTodos)
        }

        if addingHeading {
            HStack(spacing: 10) {
                TextField("New heading", text: $newHeadingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .focused($headingTitleFocused)
                    .onSubmit(saveHeading)
            }
            .padding(.horizontal, 11)
            .frame(height: 40)
            .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 9))
            .onExitCommand(perform: closeHeadingComposer)
            .transition(WaniMotion.revealTransition)
        }

        if projectLoggedItemCount > 0 {
            Button {
                withAnimation(WaniMotion.standard) {
                    projectLogbookExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(projectLogbookExpanded ? "Hide Logged Items" : "Show Logged Items")
                    Text(projectLoggedItemCount.formatted())
                        .foregroundStyle(palette.tertiaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(projectLogbookExpanded ? 90 : 0))
                }
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
                .padding(.horizontal, 11)
                .frame(height: 40)
            }
            .buttonStyle(.waniInteractive(palette))
            .frame(maxWidth: .infinity, alignment: .leading)

            if projectLogbookExpanded {
                Group {
                    let loggedByHeading = Dictionary(grouping: projectLoggedTodos) {
                        $0.heading?.id
                    }
                    taskRows(loggedByHeading[nil] ?? [])

                    ForEach(projectLoggedHeadings) { heading in
                        loggedHeadingRow(heading)
                        taskRows(loggedByHeading[heading.id] ?? [])
                    }
                }
                .transition(WaniMotion.revealTransition)
            }
        }
    }

    private func loggedHeadingRow(_ heading: WaniHeading) -> some View {
        HStack(spacing: 8) {
            Text(heading.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)
            if let archivedAt = heading.archivedAt {
                Text(archivedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.accent)
            }
            Spacer()
            if heading.archivedAt != nil {
                Button("Reopen") {
                    reopen(heading)
                }
                .buttonStyle(.waniInteractive(palette))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(palette.accent)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 40)
    }

    @ViewBuilder
    private func taskRows(_ rows: [WaniTodo]) -> some View {
        ForEach(rows) { todo in
            WaniTaskRow(
                todo: todo,
                palette: palette,
                areas: areas,
                projects: activeProjects,
                headings: activeHeadings,
                density: density,
                deadlineNotificationsEnabled: deadlineNotificationsEnabled,
                isSelected: selectedTodoIDs.contains(todo.id),
                isExpanded: expandedTodoID == todo.id,
                toggleExpanded: {
                    activate(todo)
                },
                toggleCompleted: { toggleStatus(todo) },
                cancelTodo: { cancel(todo) },
                canLogNow: WaniTaskRules.isAwaitingMidnightArchive(
                    todo,
                    enabled: moveToLogbookAtMidnight
                ),
                logNow: { logNow(todo) },
                moveToTrash: { moveToTrash(todo) },
                restore: { restore(todo) },
                deletePermanently: { deletePermanently(todo) },
                moveToInbox: { moveToInbox(todo) },
                moveToArea: { area in
                    move(todo, to: area)
                },
                moveToProject: { project, heading in
                    move(todo, to: project, heading: heading)
                },
                reorder: { movingID, targetID in
                    reorderTodo(movingID, to: targetID, in: rows)
                },
                recurrenceChanged: generateDueRepeatingTodos
            )
            .id(todo.id)
        }
    }

    private var smartListCounts: [WaniSmartList: Int] {
        var counts = WaniTaskRules.smartListCounts(
            todos,
            now: dateReference,
            deferCompletedUntilMidnight: moveToLogbookAtMidnight
        )
        counts[.logbook, default: 0] += archivedProjects.count
        counts[.trash] = trashItemCount
        return counts
    }

    private var todayCount: Int {
        smartListCounts[.today] ?? 0
    }

    private var dockBadgeCount: Int {
        guard dockCountMode == .dueAndToday else { return todayCount }

        let calendar = Calendar.current
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: dateReference)
        ) ?? dateReference
        let dueIDs = todos.lazy.filter { todo in
            todo.status == .open
                && todo.deletedAt == nil
                && todo.deadline.map { $0 < tomorrow } == true
        }.map(\.id)
        let todayIDs = WaniTaskRules.tasks(
            todos,
            in: .today,
            now: dateReference,
            deferCompletedUntilMidnight: moveToLogbookAtMidnight
        ).lazy.filter { $0.status == .open }.map(\.id)
        return Set(dueIDs).union(todayIDs).count
    }

    private var selectedTodos: [WaniTodo] {
        guard !selectedTodoIDs.isEmpty else { return [] }
        return displayedTodoIDs.compactMap { id in
            todos.first { $0.id == id && selectedTodoIDs.contains(id) }
        }
    }

    private var focusedToolbarTodo: WaniTodo? {
        guard
            let expandedTodoID,
            displayedTodoIDs.contains(expandedTodoID),
            let todo = todos.first(where: { $0.id == expandedTodoID }),
            todo.status == .open,
            todo.deletedAt == nil
        else { return nil }
        return todo
    }

    private var repeatEditorTodo: WaniTodo? {
        guard let repeatEditorTodoID else { return nil }
        return todos.first { $0.id == repeatEditorTodoID }
    }

    private var repeatCommandTodo: WaniTodo? {
        let todo = selectedTodos.count == 1 ? selectedTodos[0] : focusedToolbarTodo
        guard todo?.status == .open, todo?.deletedAt == nil else { return nil }
        return todo
    }

    private var duplicateCommandTodos: [WaniTodo] {
        if !selectedTodos.isEmpty { return selectedTodos }
        guard
            let expandedTodoID,
            let todo = todos.first(where: { $0.id == expandedTodoID })
        else { return [] }
        return [todo]
    }

    private var displayedTodoSections: [[WaniTodo]] {
        let sections: [[WaniTodo]]
        switch selection {
        case .smart(.today):
            sections = todayGroups(
                WaniTaskRules.todayTasks(
                    todos,
                    evening: false,
                    deferCompletedUntilMidnight: moveToLogbookAtMidnight
                )
            ).map(\.todos) + todayGroups(
                WaniTaskRules.todayTasks(
                    todos,
                    evening: true,
                    deferCompletedUntilMidnight: moveToLogbookAtMidnight
                )
            ).map(\.todos)
        case .smart(.upcoming):
            sections = WaniTaskRules.upcomingDays(
                todos,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            ).map(\.todos)
        case .smart(.anytime), .smart(.someday):
            let listTodos = visibleTodos
            let byArea = Dictionary(grouping: listTodos.filter { $0.project == nil }) {
                $0.area?.id
            }
            let byProject = Dictionary(
                grouping: listTodos.filter { $0.project != nil }
            ) { $0.project?.id }
            let areaSections = areas.map { byArea[$0.id] ?? [] }
            let projectSections = activeProjects.map { byProject[$0.id] ?? [] }
            sections = [byArea[nil] ?? []] + areaSections + projectSections
        case .smart(.logbook):
            sections = logbookMonths.map(\.todos)
        case .smart(.trash):
            sections = [standaloneTrashedTodos]
        case .smart(.inbox):
            sections = [visibleTodos]
        case .area(let areaID):
            let listTodos = visibleTodos
            let areaTodos = listTodos.filter { $0.area?.id == areaID }
            let byProject = Dictionary(
                grouping: listTodos.filter { $0.project != nil }
            ) { $0.project?.id }
            let projectSections = activeProjects
                .filter { $0.area?.id == areaID }
                .map { byProject[$0.id] ?? [] }
            sections = [areaTodos] + projectSections
        case .project:
            let byHeading = Dictionary(grouping: filteredProjectTodos) { $0.heading?.id }
            var projectSections = [byHeading[nil] ?? []]
                + projectHeadings.map { byHeading[$0.id] ?? [] }
            if projectLogbookExpanded {
                let loggedByHeading = Dictionary(grouping: projectLoggedTodos) {
                    $0.heading?.id
                }
                projectSections.append(loggedByHeading[nil] ?? [])
                projectSections.append(contentsOf: projectLoggedHeadings.map {
                    loggedByHeading[$0.id] ?? []
                })
            }
            sections = projectSections
        }
        return sections
    }

    private var displayedTodoIDs: [UUID] {
        WaniSelectionRules.orderedIDs(in: displayedTodoSections.map { $0.map(\.id) })
    }

    private var pageTitle: String {
        switch selection {
        case .smart(let list): list.title
        case .area(let id): areas.first { $0.id == id }?.title ?? "Area"
        case .project(let id): projects.first { $0.id == id }?.title ?? "Project"
        }
    }

    private var pageTitleBinding: Binding<String> {
        Binding(
            get: { pageTitle },
            set: { title in
                if let project = selectedProject {
                    project.title = title
                    project.updatedAt = .now
                } else if let area = selectedArea {
                    area.title = title
                    area.updatedAt = .now
                }
                saveChanges()
            }
        )
    }

    private var projectNotesBinding: Binding<String> {
        Binding(
            get: { selectedProject?.notes ?? "" },
            set: { notes in
                guard let project = selectedProject else { return }
                project.notes = notes
                project.updatedAt = .now
                saveChanges()
            }
        )
    }

    private var pageTitleFieldWidth: CGFloat {
        let value = pageTitle.isEmpty ? "Untitled" : pageTitle
        let font = NSFont.systemFont(ofSize: 29, weight: .semibold)
        let width = (value as NSString).size(withAttributes: [.font: font]).width + 12
        return min(max(width, 90), 520)
    }

    private var pageMetadata: String {
        switch selection {
        case .smart(.today):
            return "\(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())) · \(visibleOpenTodoCount) to do"
        case .smart(.upcoming):
            return "The days ahead · \(visibleOpenTodoCount) scheduled"
        case .smart(.inbox):
            return visibleOpenTodoCount == 0 ? "Everything is filed" : "\(visibleOpenTodoCount) unsorted"
        case .smart(.anytime): return "Everything you could pick up now"
        case .smart(.someday): return "Kept warm for later"
        case .smart(.logbook): return "\(visibleTodos.count + archivedProjects.count) logged"
        case .smart(.trash): return trashItemCount == 0 ? "Empty" : "\(trashItemCount) deleted"
        case .area(let id):
            let projectCount = activeProjects.filter { $0.area?.id == id }.count
            return "\(projectCount) \(projectCount == 1 ? "project" : "projects") · \(visibleOpenTodoCount) open"
        case .project(let id):
            let project = projects.first { $0.id == id }
            let projectTodos = WaniTaskRules.projectTasks(todos, projectID: id)
            let openCount = projectTodos.filter { $0.status == .open }.count
            let doneCount = projectTodos.filter { $0.status == .completed }.count
            let prefix: String
            if let areaTitle = project?.area?.title {
                prefix = "\(areaTitle) · "
            } else {
                prefix = ""
            }
            return "\(prefix)\(openCount) open, \(doneCount) done"
        }
    }

    private var visibleOpenTodoCount: Int {
        visibleTodos.filter { $0.status == .open }.count
    }

    private var quickEntryDestination: WaniNavigationTarget {
        if let widgetQuickEntryDestination {
            return widgetQuickEntryDestination
        }
        guard quickEntryUsesCurrentList, canAddToCurrentList else {
            return .smart(.inbox)
        }
        return selection
    }

    private var pageSymbol: String {
        switch selection {
        case .smart(let list): list.symbolName
        case .area: "cube.transparent"
        case .project: "circle"
        }
    }

    private var pageSymbolColor: Color {
        switch selection {
        case .smart(.trash): palette.tertiaryText
        case .smart(let list): list.symbolColor
        case .area: palette.accent
        case .project: palette.accent
        }
    }

    private var destinationTitle: String {
        if let todo = quickEntryInsertionTodo {
            if let project = todo.project {
                return project.title
            }
            if let area = todo.area {
                return area.title
            }
            return WaniTaskRules.primaryList(
                for: todo,
                deferCompletedUntilMidnight: moveToLogbookAtMidnight
            ).title
        }

        return switch quickEntryDestination {
        case .smart(let list): list.title
        case .area(let id): areas.first { $0.id == id }?.title ?? "Inbox"
        case .project(let id): projects.first { $0.id == id }?.title ?? "Inbox"
        }
    }

    private var quickEntryInsertionTodo: WaniTodo? {
        guard let quickEntryInsertionAfterTodoID else { return nil }
        return todos.first { $0.id == quickEntryInsertionAfterTodoID }
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
                .buttonStyle(.waniInteractive(palette))
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
        case .area: "An empty area"
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
        case .smart(.trash): "Deleted projects and to-dos wait here until you remove them permanently."
        case .area: "Add a to-do directly, or create a project from the area menu."
        case .project: "Add the first to-do and the shape of the work appears."
        default: "Nothing parked in this list."
        }
    }

    private var canAddToCurrentList: Bool {
        selection.acceptsNewTodos(areas: areas, projects: projects)
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
        .buttonStyle(.waniInteractive(palette))
        .accessibilityLabel(label)
    }

    private var navigationShortcuts: some View {
        VStack {
            Button("New To-Do") {
                quickEntryOpen = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!canAddToCurrentList)

            Button("New Project", action: createProject)
                .keyboardShortcut("n", modifiers: [.command, .option])

            Button("Search") {
                searchOpen = true
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Select All", action: selectAllTodos)
                .keyboardShortcut("a", modifiers: .command)
                .disabled(displayedTodoIDs.isEmpty)

            navigationShortcut("Go to Inbox", key: "1", list: .inbox)
            navigationShortcut("Go to Today", key: "2", list: .today)
            navigationShortcut("Go to Upcoming", key: "3", list: .upcoming)
            navigationShortcut("Go to Anytime", key: "4", list: .anytime)
            navigationShortcut("Go to Someday", key: "5", list: .someday)
            navigationShortcut("Go to Logbook", key: "6", list: .logbook)

            Button("Start Today") {
                scheduleItemCommand(
                    .date,
                    startDate: Calendar.current.startOfDay(for: .now),
                    isEvening: false
                )
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start This Evening") {
                scheduleItemCommand(
                    .date,
                    startDate: Calendar.current.startOfDay(for: .now),
                    isEvening: true
                )
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start Anytime") {
                scheduleItemCommand(.anytime, startDate: nil, isEvening: false)
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start Someday") {
                scheduleItemCommand(.someday, startDate: nil, isEvening: false)
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start Date +1 Day") {
                adjustStartDates(byDays: 1)
            }
            .keyboardShortcut("]", modifiers: .control)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start Date -1 Day") {
                adjustStartDates(byDays: -1)
            }
            .keyboardShortcut("[", modifiers: .control)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start Date +1 Week") {
                adjustStartDates(byDays: 7)
            }
            .keyboardShortcut("]", modifiers: [.control, .shift])
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Start Date -1 Week") {
                adjustStartDates(byDays: -7)
            }
            .keyboardShortcut("[", modifiers: [.control, .shift])
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Deadline +1 Day") {
                adjustDeadlines(byDays: 1)
            }
            .keyboardShortcut(".", modifiers: .control)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Deadline -1 Day") {
                adjustDeadlines(byDays: -1)
            }
            .keyboardShortcut(",", modifiers: .control)
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Deadline +1 Week") {
                adjustDeadlines(byDays: 7)
            }
            .keyboardShortcut(".", modifiers: [.control, .shift])
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)

            Button("Deadline -1 Week") {
                adjustDeadlines(byDays: -7)
            }
            .keyboardShortcut(",", modifiers: [.control, .shift])
            .disabled(selectedTodos.isEmpty && focusedToolbarTodo == nil)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func navigationShortcut(
        _ title: String,
        key: KeyEquivalent,
        list: WaniSmartList
    ) -> some View {
        Button(title) {
            selection = .smart(list)
        }
        .keyboardShortcut(key, modifiers: .command)
    }

    private var standardToolbar: some View {
        HStack(spacing: 4) {
            toolbarButton("plus", label: "New To-Do") {
                quickEntryOpen = true
            }
            .keyboardShortcut("n", modifiers: [])
            .disabled(!canAddToCurrentList)
            if selectedProject != nil {
                toolbarButton("rectangle.stack.badge.plus", label: "New Heading") {
                    openHeadingComposer()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            } else {
                toolbarButton("plus.app", label: "Quick Entry") {
                    quickEntryOpen = true
                }
                .disabled(!canAddToCurrentList)
            }
            toolbarButton("calendar", label: "When") {
                toolbarDateEditorOpen = true
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(focusedToolbarTodo == nil)
            .popover(isPresented: $toolbarDateEditorOpen, arrowEdge: .bottom) {
                if let todo = focusedToolbarTodo {
                    WaniTaskDateEditor(
                        todo: todo,
                        palette: palette,
                        save: saveChanges,
                        reminderChanged: { syncReminder(for: todo) },
                        recurrenceChanged: generateDueRepeatingTodos
                    )
                    .frame(width: 420)
                    .padding(8)
                    .background(palette.panel)
                }
            }
            toolbarButton("arrow.right", label: "Move", action: openMoveForExpandedTodo)
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(focusedToolbarTodo == nil)
            toolbarButton("magnifyingglass", label: "Search") {
                searchOpen = true
            }
        }
    }

    private var batchToolbar: some View {
        ViewThatFits(in: .horizontal) {
            batchToolbarContent(showsTitles: true)
            batchToolbarContent(showsTitles: false)
        }
        .buttonStyle(.waniInteractive(palette))
        .font(.system(size: 12.5))
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 18)
    }

    private func batchToolbarContent(showsTitles: Bool) -> some View {
        HStack(spacing: 8) {
            Text("\(selectedTodos.count) selected")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .padding(.trailing, 8)
                .fixedSize()

            batchToolbarButton(
                "Copy",
                systemImage: "doc.on.doc",
                showsTitle: showsTitles,
                action: copySelectedTodos
            )
                .keyboardShortcut("c", modifiers: .command)

            batchToolbarButton(
                "Duplicate",
                systemImage: "plus.square.on.square",
                showsTitle: showsTitles,
                action: duplicateItemCommand
            )

            batchToolbarButton(
                "Complete",
                systemImage: "checkmark",
                showsTitle: showsTitles,
                action: completeSelectedTodos
            )
                .disabled(!selectedTodos.contains { $0.status == .open })

            batchToolbarButton(
                "Cancel",
                systemImage: "xmark",
                showsTitle: showsTitles,
                action: cancelSelectedTodos
            )
                .disabled(!selectedTodos.contains { $0.status == .open })

            batchToolbarButton(
                "Log Now",
                systemImage: "archivebox",
                showsTitle: showsTitles,
                action: logSelectedTodosNow
            )
                .keyboardShortcut("y", modifiers: [.command, .shift])
                .disabled(!selectedTodos.contains {
                    WaniTaskRules.isAwaitingMidnightArchive(
                        $0,
                        enabled: moveToLogbookAtMidnight
                    )
                })

            batchToolbarButton(
                "When",
                systemImage: "calendar",
                showsTitle: showsTitles
            ) {
                batchDateEditorOpen = true
            }
            .keyboardShortcut("s", modifiers: .command)
            .popover(isPresented: $batchDateEditorOpen, arrowEdge: .bottom) {
                WaniBatchDateEditor(
                    palette: palette,
                    apply: scheduleSelectedTodos,
                    applyReminder: setReminderForSelectedTodos
                )
                .frame(width: 420)
                .padding(8)
                .background(palette.panel)
            }
            .popover(isPresented: $batchDeadlineEditorOpen, arrowEdge: .bottom) {
                WaniBatchDeadlineEditor(
                    palette: palette,
                    apply: setDeadlineForSelectedTodos
                )
                .frame(width: 320)
                .padding(8)
                .background(palette.panel)
            }

            batchToolbarButton(
                "Tags",
                systemImage: "tag",
                showsTitle: showsTitles
            ) {
                batchTagEditorOpen = true
            }
            .popover(isPresented: $batchTagEditorOpen, arrowEdge: .bottom) {
                WaniBatchTagEditor(
                    palette: palette,
                    knownTags: WaniTaskRules.tags(in: todos),
                    selectedTagNames: selectedTodos.map(\.tagNames),
                    setTag: setTagForSelectedTodos,
                    clear: clearSelectedTags
                )
                .frame(width: 320)
                .padding(8)
                .background(palette.panel)
            }

            if canGroupSelectionInNewHeading {
                Button {
                    openHeadingComposer(groupingSelection: true)
                } label: {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .frame(width: 28, height: 28)
                }
                .keyboardShortcut("n", modifiers: [.command, .option, .shift])
                .accessibilityLabel("New Heading with Selection")
            }

            batchToolbarButton(
                "Move",
                systemImage: "arrow.right",
                showsTitle: showsTitles
            ) {
                batchMoveOpen = true
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            batchToolbarButton(
                "Trash",
                systemImage: "trash",
                showsTitle: showsTitles,
                action: trashSelectedTodos
            )
                .disabled(!selectedTodos.contains { $0.deletedAt == nil })

            Spacer()

            batchToolbarButton(
                "Deselect",
                systemImage: "xmark.circle",
                showsTitle: showsTitles,
                action: clearTodoSelection
            )
                .keyboardShortcut("a", modifiers: [.command, .option])
        }
    }

    private func batchToolbarButton(
        _ title: String,
        systemImage: String,
        showsTitle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if showsTitle {
                Label(title, systemImage: systemImage)
                    .fixedSize()
            } else {
                Image(systemName: systemImage)
                    .frame(width: 28, height: 28)
            }
        }
        .accessibilityLabel(title)
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
        batchDateEditorOpen = false
        batchDeadlineEditorOpen = false
        batchTagEditorOpen = false
        repeatEditorTodoID = nil
        closeBatchMove()
    }

    private func handleTaskListKeyEvent(_ event: NSEvent) -> Bool {
        guard
            event.window == NSApp.keyWindow,
            !quickEntryOpen,
            !searchOpen,
            repeatEditorTodo == nil,
            !batchMoveOpen,
            !batchDateEditorOpen,
            !batchDeadlineEditorOpen,
            !batchTagEditorOpen,
            !toolbarDateEditorOpen,
            !(NSApp.keyWindow?.firstResponder is NSTextView)
        else { return false }

        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty, event.charactersIgnoringModifiers == " " {
            return openQuickEntryBelowSelection()
        }

        if modifiers.contains(.command),
           !modifiers.contains(.control),
           !modifiers.contains(.shift) {
            let direction: WaniSelectionDirection
            switch event.specialKey {
            case .upArrow:
                direction = .previous
            case .downArrow:
                direction = .next
            default:
                return false
            }
            return reorderKeyboardTodo(
                in: direction,
                toBoundary: modifiers.contains(.option)
            )
        }
        guard !modifiers.contains(.command), !modifiers.contains(.control) else { return false }

        if event.specialKey == .carriageReturn || event.specialKey == .enter {
            guard modifiers.isEmpty, selectedTodos.count == 1 else { return false }
            openSelectedTodo()
            return true
        }

        let direction: WaniSelectionDirection
        switch event.specialKey {
        case .upArrow:
            direction = .previous
        case .downArrow:
            direction = .next
        default:
            return false
        }

        let extending = modifiers.contains(.shift)
        let boundary = modifiers.contains(.option)

        let targetID = boundary
            ? WaniSelectionRules.boundaryID(in: direction, in: displayedTodoIDs)
            : WaniSelectionRules.movedID(
                in: direction,
                selectedIDs: selectedTodoIDs,
                anchorID: selectionAnchorID,
                extending: extending,
                in: displayedTodoIDs
            )
        guard let targetID else { return false }

        if extending {
            if selectionAnchorID == nil || selectedTodoIDs.isEmpty {
                selectionAnchorID = targetID
            }
            selectedTodoIDs = WaniSelectionRules.range(
                from: selectionAnchorID,
                through: targetID,
                in: displayedTodoIDs
            )
        } else {
            selectedTodoIDs = [targetID]
            selectionAnchorID = targetID
        }
        expandedTodoID = nil
        return true
    }

    private func openQuickEntryBelowSelection() -> Bool {
        guard
            canAddToCurrentList,
            selectedTodos.count == 1,
            displayedTodoIDs.contains(selectedTodos[0].id)
        else { return false }

        quickEntryInsertionAfterTodoID = selectedTodos[0].id
        quickEntryOpen = true
        return true
    }

    private func reorderKeyboardTodo(
        in direction: WaniSelectionDirection,
        toBoundary: Bool
    ) -> Bool {
        let todo = selectedTodos.count == 1 ? selectedTodos[0] : focusedToolbarTodo
        guard
            let todo,
            let rows = displayedTodoSections.first(where: { section in
                section.contains { $0.id == todo.id }
            }),
            let currentIndex = rows.firstIndex(where: { $0.id == todo.id })
        else { return false }

        let targetIndex: Int
        if toBoundary {
            targetIndex = direction == .previous
                ? rows.startIndex
                : rows.index(before: rows.endIndex)
        } else {
            let offset = direction == .previous ? -1 : 1
            targetIndex = min(
                max(currentIndex + offset, rows.startIndex),
                rows.index(before: rows.endIndex)
            )
        }
        guard targetIndex != currentIndex else { return true }
        return reorderTodo(todo.id, to: rows[targetIndex].id, in: rows)
    }

    private func openSelectedTodo() {
        guard selectedTodos.count == 1 else { return }
        let todoID = selectedTodos[0].id
        clearTodoSelection()
        expandedTodoID = todoID
    }

    private func copySelectedTodos() {
        let text = selectedTodos.map(\.title).joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyItemCommand() {
        if NSApp.keyWindow?.firstResponder is NSTextView {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return
        }
        copySelectedTodos()
    }

    private func pasteTodosFromClipboard() {
        if NSApp.keyWindow?.firstResponder is NSTextView {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            return
        }

        guard
            canAddToCurrentList,
            !quickEntryOpen,
            !searchOpen,
            repeatEditorTodo == nil,
            !batchMoveOpen,
            let text = NSPasteboard.general.string(forType: .string)
        else { return }

        let titles = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !titles.isEmpty else { return }

        var sortOrder = (todos.map(\.sortOrder).max() ?? 0) + 1
        let pastedTodos = titles.map { title in
            let todo = selection.makeTodo(
                title: title,
                areas: areas,
                projects: projects
            )
            todo.sortOrder = sortOrder
            sortOrder += 1
            modelContext.insert(todo)
            return todo
        }
        saveChanges()

        expandedTodoID = nil
        selectedTodoIDs = Set(pastedTodos.map(\.id))
        selectionAnchorID = pastedTodos.first?.id
    }

    private func duplicateItemCommand() {
        let sourceTodos = duplicateCommandTodos
        guard !sourceTodos.isEmpty else { return }

        let now = Date.now
        let orderedTodos = todos.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
        let duplicates = sourceTodos.map { todo in
            let nextSortOrder = orderedTodos.first {
                $0.sortOrder > todo.sortOrder
            }?.sortOrder
            let sortOrder = nextSortOrder.map {
                (todo.sortOrder + $0) / 2
            } ?? (todo.sortOrder + 1)
            return WaniTaskRules.duplicate(todo, sortOrder: sortOrder, at: now)
        }

        for duplicate in duplicates {
            modelContext.insert(duplicate)
        }
        saveChanges()

        for duplicate in duplicates {
            syncReminder(for: duplicate, requestAuthorization: false)
        }
        expandedTodoID = nil
        selectedTodoIDs = Set(duplicates.map(\.id))
        selectionAnchorID = duplicates.first?.id
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

    private func logSelectedTodosNow() {
        for todo in selectedTodos where WaniTaskRules.isAwaitingMidnightArchive(
            todo,
            enabled: moveToLogbookAtMidnight
        ) {
            WaniTaskRules.logNow(todo)
        }
        saveChanges()
        expandedTodoID = nil
        clearTodoSelection()
    }

    private func scheduleSelectedTodos(
        _ schedule: WaniTaskSchedule,
        startDate: Date?,
        isEvening: Bool
    ) {
        let updatedAt = Date.now
        for todo in selectedTodos {
            WaniTaskRules.schedule(
                todo,
                as: schedule,
                startDate: startDate,
                isEvening: isEvening,
                at: updatedAt
            )
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func scheduleItemCommand(
        _ schedule: WaniTaskSchedule,
        startDate: Date?,
        isEvening: Bool
    ) {
        if !selectedTodos.isEmpty {
            scheduleSelectedTodos(
                schedule,
                startDate: startDate,
                isEvening: isEvening
            )
            return
        }

        guard let todo = focusedToolbarTodo else { return }
        WaniTaskRules.schedule(
            todo,
            as: schedule,
            startDate: startDate,
            isEvening: isEvening
        )
        syncReminder(for: todo, requestAuthorization: false)
        saveChanges()
    }

    private func adjustStartDates(byDays days: Int) {
        let commandTodos = selectedTodos.isEmpty
            ? focusedToolbarTodo.map { [$0] } ?? []
            : selectedTodos
        let updatedAt = Date.now
        for todo in commandTodos {
            WaniTaskRules.adjustStartDate(
                todo,
                byDays: days,
                now: updatedAt,
                at: updatedAt
            )
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        selectedTodoIDs.formIntersection(displayedTodoIDs)
        if let selectionAnchorID, !selectedTodoIDs.contains(selectionAnchorID) {
            self.selectionAnchorID = displayedTodoIDs.first(where: selectedTodoIDs.contains)
        }
    }

    private func adjustDeadlines(byDays days: Int) {
        let commandTodos = selectedTodos.isEmpty
            ? focusedToolbarTodo.map { [$0] } ?? []
            : selectedTodos
        let updatedAt = Date.now
        for todo in commandTodos {
            WaniTaskRules.adjustDeadline(
                todo,
                byDays: days,
                now: updatedAt,
                at: updatedAt
            )
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
    }

    private func setReminderForSelectedTodos(_ reminderTime: Date?) {
        let updatedAt = Date.now
        for todo in selectedTodos {
            WaniTaskRules.setReminder(todo, to: reminderTime, at: updatedAt)
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func setDeadlineForSelectedTodos(_ deadline: Date?) {
        let updatedAt = Date.now
        for todo in selectedTodos {
            WaniTaskRules.setDeadline(todo, to: deadline, at: updatedAt)
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func openWhenCommand() {
        if selectedTodos.isEmpty {
            toolbarDateEditorOpen = focusedToolbarTodo != nil
        } else {
            batchDateEditorOpen = true
        }
    }

    private func openDeadlineCommand() {
        if selectedTodos.isEmpty {
            toolbarDateEditorOpen = focusedToolbarTodo != nil
        } else {
            batchDeadlineEditorOpen = true
        }
    }

    private func openRepeatCommand() {
        repeatEditorTodoID = repeatCommandTodo?.id
    }

    private func applyRepeatConfiguration(
        _ configuration: WaniRepeatConfiguration
    ) {
        guard let todo = repeatEditorTodo else { return }
        let updatedAt = Date.now
        WaniTaskRules.setRepeatFrequency(configuration.frequency, for: todo, at: updatedAt)
        todo.repeatInterval = max(configuration.interval, 1)
        todo.repeatsAfterCompletion = configuration.afterCompletion
        todo.repeatWeekdays = configuration.afterCompletion ? [] : configuration.weekdays
        todo.repeatDateRules = configuration.afterCompletion ? [] : configuration.dateRules
        todo.repeatEndDate = configuration.afterCompletion ? nil : configuration.endDate
        todo.repeatEndAfterCount = configuration.afterCompletion
            ? nil
            : configuration.endAfterCount
        todo.repeatOccurrenceIndex = 1
        WaniTaskRules.setReminder(todo, to: configuration.reminderTime, at: updatedAt)
        WaniTaskRules.setDeadline(todo, to: configuration.deadline, at: updatedAt)
        syncReminder(for: todo, requestAuthorization: false)
        saveChanges()
        closeRepeatEditor()
        generateDueRepeatingTodos()
    }

    private func closeRepeatEditor() {
        repeatEditorTodoID = nil
    }

    private func openMoveCommand() {
        if selectedTodos.isEmpty {
            openMoveForExpandedTodo()
        } else {
            batchMoveOpen = true
        }
    }

    private func openTagsCommand() {
        if selectedTodos.isEmpty {
            guard let todo = focusedToolbarTodo else { return }
            selectedTodoIDs = [todo.id]
            selectionAnchorID = todo.id
            expandedTodoID = nil
        }
        batchTagEditorOpen = true
    }

    private func completeItemCommand() {
        if selectedTodos.isEmpty {
            if let todo = focusedToolbarTodo {
                toggleCompleted(todo)
                expandedTodoID = nil
            } else if canCloseSelectedProject {
                completeSelectedProject()
            }
        } else {
            completeSelectedTodos()
        }
    }

    private func trashItemCommand() {
        if selectedTodos.isEmpty {
            guard let todo = focusedToolbarTodo else { return }
            moveToTrash(todo)
        } else {
            trashSelectedTodos()
        }
    }

    private func cancelItemCommand() {
        if selectedTodos.isEmpty {
            if let todo = focusedToolbarTodo {
                cancel(todo)
            } else if canCloseSelectedProject {
                cancelSelectedProject()
            }
        } else {
            cancelSelectedTodos()
        }
    }

    private func saveAndCloseItemCommand() {
        guard focusedToolbarTodo != nil else { return }
        saveChanges()
        expandedTodoID = nil
    }

    private func setTagForSelectedTodos(_ tag: String, enabled: Bool) {
        let updatedAt = Date.now
        for todo in selectedTodos {
            var tags = todo.tagNames.filter {
                $0.caseInsensitiveCompare(tag) != .orderedSame
            }
            if enabled {
                tags.append(tag)
            }
            WaniTaskRules.setTags(tags, for: todo, at: updatedAt)
        }
        saveChanges()
    }

    private func clearSelectedTags() {
        let updatedAt = Date.now
        for todo in selectedTodos {
            WaniTaskRules.setTags([], for: todo, at: updatedAt)
        }
        saveChanges()
    }

    private func moveSelectedToInbox() {
        for todo in selectedTodos {
            WaniTaskRules.moveToInbox(todo)
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func moveSelectedTodos(to area: WaniArea) {
        for todo in selectedTodos {
            WaniTaskRules.move(todo, to: area)
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func moveSelectedTodos(to project: WaniProject, heading: WaniHeading?) {
        for todo in selectedTodos {
            WaniTaskRules.move(todo, to: project, heading: heading)
            syncReminder(for: todo, requestAuthorization: false)
        }
        saveChanges()
        clearTodoSelection()
    }

    private func closeBatchMove() {
        batchMoveOpen = false
        batchMoveQuery = ""
    }

    private func openMoveForExpandedTodo() {
        guard let todo = focusedToolbarTodo else { return }
        selectedTodoIDs = [todo.id]
        selectionAnchorID = todo.id
        expandedTodoID = nil
        batchMoveOpen = true
    }

    private func saveQuickEntry() {
        let title = quickEntryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let todo: WaniTodo
        if let anchor = quickEntryInsertionTodo,
           let section = displayedTodoSections.first(where: {
               $0.contains { $0.id == anchor.id }
           }),
           let anchorIndex = section.firstIndex(where: { $0.id == anchor.id }) {
            let nextTodo = section.indices.contains(anchorIndex + 1)
                ? section[anchorIndex + 1]
                : nil
            todo = WaniTaskRules.todoBelow(anchor, title: title, nextTodo: nextTodo)
        } else {
            todo = quickEntryDestination.makeTodo(
                title: title,
                areas: areas,
                projects: projects
            )
            todo.sortOrder = (todos.map(\.sortOrder).max() ?? 0) + 1
        }

        withAnimation(WaniMotion.standard) {
            modelContext.insert(todo)
            try? modelContext.save()
        }
        closeQuickEntry()
        expandedTodoID = nil
        selectedTodoIDs = [todo.id]
        selectionAnchorID = todo.id
    }

    private func toggleCompleted(_ todo: WaniTodo) {
        withAnimation(WaniMotion.standard) {
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
    }

    private func toggleStatus(_ todo: WaniTodo) {
        if todo.status == .open, NSEvent.modifierFlags.contains(.option) {
            cancel(todo)
        } else {
            toggleCompleted(todo)
        }
    }

    private func cancel(_ todo: WaniTodo) {
        withAnimation(WaniMotion.standard) {
            WaniTaskRules.cancel(todo)
            WaniReminderScheduler.cancel(todo)
            expandedTodoID = nil
            saveChanges()
        }
    }

    private func logNow(_ todo: WaniTodo) {
        guard WaniTaskRules.logNow(todo) else { return }
        withAnimation(WaniMotion.standard) {
            expandedTodoID = nil
            saveChanges()
        }
    }

    private func moveToTrash(_ todo: WaniTodo) {
        withAnimation(WaniMotion.standard) {
            WaniTaskRules.moveToTrash(todo)
            WaniReminderScheduler.cancel(todo)
            expandedTodoID = nil
            try? modelContext.save()
        }
    }

    private func restore(_ todo: WaniTodo) {
        withAnimation(WaniMotion.standard) {
            WaniTaskRules.restore(todo)
            expandedTodoID = nil
            try? modelContext.save()
        }
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
        let awaitingArchive = WaniTaskRules.isAwaitingMidnightArchive(
            todo,
            enabled: moveToLogbookAtMidnight
        )
        let primaryList = WaniTaskRules.primaryList(
            for: todo,
            deferCompletedUntilMidnight: moveToLogbookAtMidnight
        )
        if (todo.status == .open || awaitingArchive),
           todo.deletedAt == nil,
           let project = todo.project {
            selection = .project(project.id)
        } else if (todo.status == .open || awaitingArchive),
                  todo.deletedAt == nil,
                  let area = todo.area {
            selection = .area(area.id)
        } else {
            selection = .smart(primaryList)
        }
        expandedTodoID = todo.id
        closeSearch()
    }

    private func openSearchResult(_ project: WaniProject) {
        selection = .project(project.id)
        expandedTodoID = nil
        closeSearch()
    }

    private func openSearchResult(_ area: WaniArea) {
        selection = .area(area.id)
        expandedTodoID = nil
        closeSearch()
    }

    private func createArea() {
        let area = WaniArea(
            title: "New Area",
            sortOrder: (areas.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(area)
        saveChanges()
        selection = .area(area.id)
        focusHeaderTitle()
    }

    private func createProject() {
        let area = selectedArea ?? selectedProject?.area
        let project = WaniProject(
            title: "New Project",
            area: area,
            sortOrder: (projects.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(project)
        saveChanges()
        selection = .project(project.id)
        expandedTodoID = nil
        focusHeaderTitle()
    }

    private func reorderArea(_ movingID: UUID, before targetID: UUID) -> Bool {
        let orderedIDs = WaniTaskRules.reorderedIDs(
            areas.map(\.id),
            moving: movingID,
            to: targetID
        )
        guard orderedIDs != areas.map(\.id) else { return false }
        let updatedAt = Date.now
        for (index, id) in orderedIDs.enumerated() {
            guard let area = areas.first(where: { $0.id == id }) else { continue }
            area.sortOrder = Double(index)
            area.updatedAt = updatedAt
        }
        saveChanges()
        return true
    }

    private func reorderProject(_ movingID: UUID, before targetID: UUID) -> Bool {
        guard
            let movingProject = activeProjects.first(where: { $0.id == movingID }),
            let targetProject = activeProjects.first(where: { $0.id == targetID }),
            movingProject.area?.id == targetProject.area?.id
        else { return false }

        let siblings = activeProjects.filter { $0.area?.id == targetProject.area?.id }
        let orderedIDs = WaniTaskRules.reorderedIDs(
            siblings.map(\.id),
            moving: movingID,
            to: targetID
        )
        guard orderedIDs != siblings.map(\.id) else { return false }
        let updatedAt = Date.now
        for (index, id) in orderedIDs.enumerated() {
            guard let project = siblings.first(where: { $0.id == id }) else { continue }
            project.sortOrder = Double(index)
            project.updatedAt = updatedAt
        }
        saveChanges()
        return true
    }

    private func reorderHeading(_ movingID: UUID, before targetID: UUID) -> Bool {
        let orderedIDs = WaniTaskRules.reorderedIDs(
            projectHeadings.map(\.id),
            moving: movingID,
            to: targetID
        )
        guard orderedIDs != projectHeadings.map(\.id) else { return false }
        let updatedAt = Date.now
        for (index, id) in orderedIDs.enumerated() {
            guard let heading = projectHeadings.first(where: { $0.id == id }) else { continue }
            heading.sortOrder = Double(index)
            heading.updatedAt = updatedAt
        }
        saveChanges()
        return true
    }

    private func reorderTodo(
        _ movingID: UUID,
        to targetID: UUID,
        in rows: [WaniTodo]
    ) -> Bool {
        guard WaniTaskRules.reorder(rows, moving: movingID, to: targetID) else {
            return false
        }
        saveChanges()
        return true
    }

    private func normalizePageTitle() {
        let trimmedTitle = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let project = selectedProject {
            project.title = trimmedTitle.isEmpty ? "New Project" : trimmedTitle
            project.updatedAt = .now
            for todo in todos where todo.project?.id == project.id {
                syncReminder(for: todo, requestAuthorization: false)
            }
        } else if let area = selectedArea {
            area.title = trimmedTitle.isEmpty ? "New Area" : trimmedTitle
            area.updatedAt = .now
        }
        headerTitleFocused = false
        saveChanges()
    }

    private func moveSelectedProject(to area: WaniArea?) {
        guard let project = selectedProject else { return }
        project.area = area
        project.updatedAt = .now
        saveChanges()
    }

    private func moveSelectedProjectToTrash() {
        guard let project = selectedProject else { return }
        WaniTaskRules.moveProjectToTrash(project, todos: todos)
        for todo in todos where todo.project?.id == project.id {
            WaniReminderScheduler.cancel(todo)
        }
        saveChanges()
        selection = .smart(.trash)
    }

    private func deleteSelectedArea() {
        guard let area = selectedArea else { return }
        let areaProjects = projects.filter { $0.area?.id == area.id }
        let projectIDs = Set(areaProjects.map(\.id))
        let areaTodos = todos.filter { todo in
            todo.area?.id == area.id
                || todo.project.map { projectIDs.contains($0.id) } == true
        }
        WaniTaskRules.moveAreaContentsToTrash(
            area,
            projects: areaProjects,
            todos: todos
        )
        for todo in areaTodos {
            WaniReminderScheduler.cancel(todo)
        }
        modelContext.delete(area)
        saveChanges()
        // Loose to-dos land in the Trash just like projects do, so an area that only
        // held to-dos must not send you somewhere that shows none of them.
        selection = areaProjects.isEmpty && areaTodos.isEmpty
            ? .smart(.today)
            : .smart(.trash)
    }

    private func focusHeaderTitle() {
        Task { @MainActor in
            await Task.yield()
            headerTitleFocused = true
        }
    }

    private func completeSelectedProject() {
        guard
            let project = selectedProject,
            WaniTaskRules.completeProject(
                project,
                todos: todos,
                headings: headings
            )
        else { return }

        saveChanges()
        selection = .smart(.logbook)
    }

    private func cancelSelectedProject() {
        guard
            let project = selectedProject,
            WaniTaskRules.cancelProject(
                project,
                todos: todos,
                headings: headings
            )
        else { return }

        saveChanges()
        selection = .smart(.logbook)
    }

    private func reopen(_ project: WaniProject) {
        WaniTaskRules.reopenProject(project)
        saveChanges()
        selection = .project(project.id)
    }

    private func archive(_ heading: WaniHeading) {
        guard WaniTaskRules.archiveHeading(heading, todos: todos) else { return }
        saveChanges()
        withAnimation(WaniMotion.standard) {
            projectLogbookExpanded = true
        }
    }

    private func reopen(_ heading: WaniHeading) {
        WaniTaskRules.reopenHeading(heading)
        saveChanges()
    }

    private func restore(_ project: WaniProject) {
        WaniTaskRules.restoreProject(project, todos: todos)
        saveChanges()
        let restoredTodos = todos.filter {
            $0.project?.id == project.id && $0.deletedAt == nil
        }
        Task {
            for todo in restoredTodos {
                await WaniReminderScheduler.sync(
                    todo,
                    requestAuthorization: false,
                    deadlineNotificationsEnabled: deadlineNotificationsEnabled
                )
            }
        }
        selection = project.completedAt == nil && project.canceledAt == nil
            ? .project(project.id)
            : .smart(.logbook)
    }

    private func deletePermanently(_ project: WaniProject) {
        deleteProjectPermanently(project)
        saveChanges()
    }

    private func deleteProjectPermanently(_ project: WaniProject) {
        for todo in todos where todo.project?.id == project.id {
            WaniReminderScheduler.cancel(todo)
            modelContext.delete(todo)
        }
        for heading in headings where heading.project?.id == project.id {
            modelContext.delete(heading)
        }
        modelContext.delete(project)
    }

    private func emptyTrash() {
        let projectsToDelete = trashedProjects
        let projectIDs = Set(projectsToDelete.map(\.id))
        // A to-do trashed before its project now has its own row, so skip it here and
        // let deleteProjectPermanently sweep it exactly once.
        let todosToDelete = standaloneTrashedTodos.filter { todo in
            todo.project.map { !projectIDs.contains($0.id) } ?? true
        }

        for todo in todosToDelete {
            WaniReminderScheduler.cancel(todo)
            modelContext.delete(todo)
        }
        for project in projectsToDelete {
            deleteProjectPermanently(project)
        }
        saveChanges()
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

        let groupedSelection = groupingSelectionInNewHeading
        if groupedSelection {
            _ = WaniTaskRules.groupUnheadedTodos(
                selectedTodos,
                under: heading,
                in: project
            )
        }
        saveChanges()
        closeHeadingComposer()
        if groupedSelection {
            clearTodoSelection()
        }
    }

    private var canGroupSelectionInNewHeading: Bool {
        guard
            case .project(let projectID) = selection,
            !selectedTodos.isEmpty
        else { return false }

        return selectedTodos.allSatisfy {
            $0.project?.id == projectID && $0.heading == nil
        }
    }

    private func openHeadingComposer(groupingSelection: Bool = false) {
        guard selectedProject != nil else { return }
        groupingSelectionInNewHeading = groupingSelection
        withAnimation(WaniMotion.standard) {
            addingHeading = true
        }
        Task { @MainActor in
            await Task.yield()
            headingTitleFocused = true
        }
    }

    private func closeHeadingComposer() {
        headingTitleFocused = false
        withAnimation(WaniMotion.standard) {
            addingHeading = false
        }
        newHeadingTitle = ""
        groupingSelectionInNewHeading = false
    }

    private func moveToInbox(_ todo: WaniTodo) {
        WaniTaskRules.moveToInbox(todo)
        syncReminder(for: todo, requestAuthorization: false)
        saveChanges()
    }

    private func move(_ todo: WaniTodo, to area: WaniArea) {
        WaniTaskRules.move(todo, to: area)
        syncReminder(for: todo, requestAuthorization: false)
        saveChanges()
    }

    private func move(
        _ todo: WaniTodo,
        to project: WaniProject,
        heading: WaniHeading?
    ) {
        WaniTaskRules.move(todo, to: project, heading: heading)
        syncReminder(for: todo, requestAuthorization: false)
        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }

    private func closeQuickEntry() {
        quickEntryOpen = false
        quickEntryTitle = ""
        quickEntryInsertionAfterTodoID = nil
        widgetQuickEntryDestination = nil
    }

    private var widgetSnapshotRevision: WaniSnapshotRevision {
        WaniSnapshotRevision(
            todoCount: todos.count,
            projectCount: projects.count,
            latestChange: max(
                todos.lazy.map(\.updatedAt).max() ?? .distantPast,
                projects.lazy.map(\.updatedAt).max() ?? .distantPast
            )
        )
    }

    /// Title and note edits touch `updatedAt` on every keystroke; rewriting the
    /// snapshot and reloading every timeline that often is wasted work, so edits
    /// are coalesced before the file is written.
    private func scheduleWidgetSnapshotRefresh() {
        widgetSnapshotRefreshTask?.cancel()
        widgetSnapshotRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            refreshWidgetSnapshot()
        }
    }

    private func refreshWidgetSnapshot() {
        widgetSnapshotRefreshTask?.cancel()
        widgetSnapshotRefreshTask = nil
        let snapshot = WaniWidgetSnapshot(
            generatedAt: .now,
            tasks: todos.map { todo in
                WaniWidgetTaskSnapshot(
                    id: todo.id,
                    title: todo.title,
                    projectID: todo.project?.id,
                    projectTitle: todo.project?.title,
                    status: todo.status.rawValue,
                    schedule: todo.schedule.rawValue,
                    startDate: todo.startDate,
                    deadline: todo.deadline,
                    createdAt: todo.createdAt,
                    updatedAt: todo.updatedAt,
                    completedAt: todo.completedAt,
                    deletedAt: todo.deletedAt,
                    sortOrder: todo.sortOrder
                )
            },
            projects: projects.map { project in
                WaniWidgetProjectSnapshot(
                    id: project.id,
                    title: project.title,
                    sortOrder: project.sortOrder,
                    completedAt: project.completedAt,
                    canceledAt: project.canceledAt,
                    deletedAt: project.deletedAt
                )
            }
        )
        if WaniWidgetSnapshotStore.save(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "wani", url.host == "widget" else { return }
        let path = url.pathComponents.filter { $0 != "/" }
        guard let action = path.first else { return }

        switch action {
        case "complete":
            guard path.count == 2,
                  let id = UUID(uuidString: path[1]),
                  let todo = todos.first(where: {
                      $0.id == id && $0.status == .open && $0.deletedAt == nil
                  })
            else { return }
            toggleCompleted(todo)
        case "postpone":
            guard path.count == 2,
                  let id = UUID(uuidString: path[1]),
                  let todo = todos.first(where: {
                      $0.id == id && $0.status == .open && $0.deletedAt == nil
                  }),
                  let tomorrow = Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: Calendar.current.startOfDay(for: .now)
                  )
            else { return }
            WaniTaskRules.schedule(
                todo,
                as: .date,
                startDate: tomorrow,
                isEvening: false
            )
            syncReminder(for: todo, requestAuthorization: false)
            saveChanges()
        case "quick-capture":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let destination = components?.queryItems?.first {
                $0.name == "destination"
            }?.value
            let projectID = components?.queryItems?.first {
                $0.name == "project"
            }?.value.flatMap(UUID.init(uuidString:))

            if destination == "today" {
                widgetQuickEntryDestination = .smart(.today)
            } else if destination == "project",
                      let projectID,
                      projects.contains(where: { $0.id == projectID }) {
                widgetQuickEntryDestination = .project(projectID)
            } else {
                widgetQuickEntryDestination = .smart(.inbox)
            }
            quickEntryInsertionAfterTodoID = nil
            quickEntryOpen = true
        default:
            return
        }
    }

    private func registerGlobalQuickEntry() {
        _ = WaniGlobalHotKey.shared.register(quickEntryShortcut)
    }

    private func closeSearch() {
        searchOpen = false
        searchQuery = ""
    }

    private func updateDockBadge() {
        WaniDockBadge.update(count: showDockBadge ? dockBadgeCount : 0)
    }

    private func syncAllNotifications() {
        Task {
            await syncNotifications()
        }
    }

    private func syncReminder(
        for todo: WaniTodo,
        requestAuthorization: Bool = true
    ) {
        Task {
            await WaniReminderScheduler.sync(
                todo,
                requestAuthorization: requestAuthorization,
                deadlineNotificationsEnabled: deadlineNotificationsEnabled
            )
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

    private func generateDueRepeatingTodos() {
        let generated = todos.flatMap {
            WaniTaskRules.generateDueRegularOccurrences(from: $0)
        }
        guard !generated.isEmpty else { return }

        for todo in generated {
            modelContext.insert(todo)
        }
        saveChanges()

        Task {
            for todo in generated {
                await WaniReminderScheduler.sync(
                    todo,
                    requestAuthorization: false,
                    deadlineNotificationsEnabled: deadlineNotificationsEnabled
                )
            }
        }
    }
}

private struct WaniTodayGroup: Identifiable {
    let id: String
    let title: String?
    var todos: [WaniTodo]
}

private struct WaniKeyEventMonitor: NSViewRepresentable {
    let handle: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(handle: handle)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handle = handle
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var handle: (NSEvent) -> Bool
        private var monitor: Any?
        private weak var view: NSView?

        init(handle: @escaping (NSEvent) -> Bool) {
            self.handle = handle
        }

        func start(for view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.view?.window else { return event }
                return self.handle(event) ? nil : event
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

#Preview {
    ContentView()
        .modelContainer(try! WaniPersistence.makeContainer(inMemory: true, cloudSync: false))
}

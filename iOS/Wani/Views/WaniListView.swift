import SwiftData
import SwiftUI

struct WaniListView: View {
    @Environment(\.modelContext) private var modelContext
    let route: WaniRoute
    let projects: [WaniProject]
    let todos: [WaniTodo]
    let projectMetrics: [UUID: WaniProjectTally]
    let initiallyExpandedTodoID: UUID?
    let palette: WaniPalette
    let openProject: (UUID) -> Void
    @AppStorage("wani.logAtMidnight") private var logAtMidnight = true
    @State private var expandedTodoID: UUID?
    @State private var showLogged = false

    private var project: WaniProject? {
        guard case .project(let id) = route else { return nil }
        return projects.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WaniPageHeader(
                    title: title,
                    symbol: symbol,
                    color: headerColor,
                    progress: project.map { projectMetrics[$0.id]?.progress ?? 0 },
                    palette: palette
                )
                if let project {
                    Text(project.notes.isEmpty ? "Notes" : project.notes)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.tertiary)
                        .padding(.top, 10)
                }
                if case .smart(.trash) = route {
                    Text("Deleted to-dos wait here for thirty days")
                        .font(.system(size: 13.5))
                        .foregroundStyle(palette.tertiary)
                        .padding(.top, 9)
                }
                if smartList == .today && !newTodos.isEmpty {
                    HStack(spacing: 12) {
                        Text("You have \(newTodos.count) new to-dos")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(palette.accent)
                        Spacer()
                        Button("OK", action: dismissNewTodoBanner)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .padding(.vertical, 11)
                    .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 18)
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 100)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar { WaniNavigationToolbar(palette: palette) }
        .onAppear {
            if expandedTodoID == nil { expandedTodoID = initiallyExpandedTodoID }
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .smart(.upcoming) = route {
            upcomingContent
        } else if case .smart(.logbook) = route {
            logbookContent
        } else if let project {
            projectContent(project)
        } else {
            smartListContent
        }
    }

    private var smartListContent: some View {
        let list = smartList ?? .inbox
        let matches = WaniTaskRules.tasks(
            todos,
            in: list,
            deferCompletedUntilMidnight: logAtMidnight
        )
        return VStack(spacing: 0) {
            if matches.isEmpty {
                WaniEmptyState(
                    title: list == .trash ? "The Trash is empty" : "Empty for now",
                    message: list == .trash
                        ? "Deleted to-dos wait here for thirty days."
                        : "Nothing parked in this list.",
                    palette: palette
                )
            } else if list == .inbox || list == .trash {
                ForEach(matches) { todo in taskRow(todo) }
            } else {
                groupedTasks(matches)
            }
        }
        .padding(.top, 20)
    }

    private func groupedTasks(_ matches: [WaniTodo]) -> some View {
        let unprojected = matches.filter { $0.project == nil }
        let activeProjects = projects.filter {
            $0.completedAt == nil && $0.canceledAt == nil && $0.deletedAt == nil
        }
        return VStack(alignment: .leading, spacing: 24) {
            if !unprojected.isEmpty {
                VStack(spacing: 0) {
                    ForEach(unprojected) { todo in taskRow(todo) }
                }
            }
            ForEach(activeProjects) { project in
                let projectTodos = matches.filter { $0.project?.id == project.id }
                if !projectTodos.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Button { openProject(project.id) } label: {
                            HStack(spacing: 10) {
                                WaniProgressRing(
                                    progress: projectMetrics[project.id]?.progress ?? 0,
                                    color: palette.accent,
                                    background: palette.line,
                                    size: 19,
                                    lineWidth: 3
                                )
                                Text(project.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(palette.text)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.tertiary)
                                Spacer()
                            }
                            .padding(.bottom, 8)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(palette.line).padding(.bottom, 3)
                        ForEach(projectTodos) { todo in taskRow(todo) }
                    }
                }
            }
        }
    }

    private var upcomingContent: some View {
        VStack(spacing: 0) {
            ForEach(WaniTaskRules.upcomingDays(
                todos,
                deferCompletedUntilMidnight: logAtMidnight
            )) { day in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 11) {
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(day.todos.isEmpty ? palette.tertiary : palette.text)
                        Text(dayLabel(day))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.tertiary)
                        Rectangle().fill(palette.line).frame(height: 0.5)
                    }
                    .padding(.bottom, 5)
                    ForEach(day.todos) { todo in taskRow(todo, showsProject: true) }
                }
                .padding(.bottom, day.todos.isEmpty ? 26 : 18)
            }
        }
        .padding(.top, 20)
    }

    private var logbookContent: some View {
        let months = WaniTaskRules.logbookMonths(
            todos,
            deferCompletedUntilMidnight: logAtMidnight
        )
        return VStack(alignment: .leading, spacing: 28) {
            if months.isEmpty {
                WaniEmptyState(
                    title: "Nothing logged yet",
                    message: "Completed to-dos collect here.",
                    palette: palette
                )
            }
            ForEach(months, id: \.month) { month in
                VStack(alignment: .leading, spacing: 0) {
                    WaniSectionTitle(month.month.formatted(.dateTime.month(.wide)), palette: palette)
                    ForEach(month.todos) { todo in
                        taskRow(todo, showsDate: true, showsProject: true)
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    private func dayLabel(_ day: WaniUpcomingDay) -> String {
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: .now)
        )
        if tomorrow.map({ Calendar.current.isDate($0, inSameDayAs: day.date) }) == true {
            return "Tomorrow"
        }
        return day.date.formatted(.dateTime.weekday(.wide))
    }

    private func projectContent(_ project: WaniProject) -> some View {
        let projectTodos = todos.filter {
            $0.project?.id == project.id && $0.deletedAt == nil
        }
        let logged = projectTodos.filter {
            WaniTaskRules.isProjectLogged($0, deferCompletedUntilMidnight: logAtMidnight)
        }
        let open = projectTodos.filter {
            !WaniTaskRules.isProjectLogged($0, deferCompletedUntilMidnight: logAtMidnight)
        }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(open) { todo in taskRow(todo) }
            if !logged.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showLogged.toggle() }
                } label: {
                    Text("\(showLogged ? "Hide" : "Show") \(logged.count) logged items")
                        .font(.system(size: 14.5))
                        .foregroundStyle(palette.tertiary)
                        .padding(.vertical, 14)
                }
                if showLogged {
                    ForEach(logged) { todo in taskRow(todo, showsDate: true) }
                }
            }
            if open.isEmpty && logged.isEmpty {
                WaniEmptyState(
                    title: "A blank project",
                    message: "Add the first to-do and the shape of the work appears.",
                    palette: palette
                )
            }
        }
        .padding(.top, 20)
    }

    private func taskRow(
        _ todo: WaniTodo,
        showsDate: Bool = false,
        showsProject: Bool = false
    ) -> some View {
        WaniTaskRow(
            todo: todo,
            isExpanded: expandedTodoID == todo.id,
            showsDate: showsDate,
            showsProject: showsProject,
            palette: palette,
            onOpen: {
                if todo.isNew {
                    todo.isNew = false
                    todo.updatedAt = .now
                    try? modelContext.save()
                }
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedTodoID = expandedTodoID == todo.id ? nil : todo.id
                }
            },
            onToggle: { toggle(todo) },
            onDelete: { delete(todo) }
        )
    }

    private var smartList: WaniSmartList? {
        guard case .smart(let list) = route else { return nil }
        return list
    }

    private var newTodos: [WaniTodo] {
        todos.filter { $0.isNew && $0.status == .open && $0.deletedAt == nil }
    }

    private func dismissNewTodoBanner() {
        for todo in newTodos {
            todo.isNew = false
            todo.updatedAt = .now
        }
        try? modelContext.save()
    }

    private var title: String {
        project?.title ?? smartList?.title ?? ""
    }

    private var symbol: String {
        project == nil ? (smartList?.symbolName ?? "circle") : ""
    }

    private var headerColor: Color {
        switch smartList {
        case .inbox: Color(rgb: 0x4A7BA7)
        case .today: Color(rgb: 0xC9922A)
        case .upcoming: Color(rgb: 0xC3564C)
        case .anytime, .logbook: Color(rgb: 0x5B8C6C)
        case .someday: Color(rgb: 0x9A8A5F)
        case .trash, .none: palette.tertiary
        }
    }

    private func toggle(_ todo: WaniTodo) {
        if todo.deletedAt != nil {
            WaniTaskRules.restore(todo)
        } else if todo.status == .open {
            WaniTodoActions.complete(todo, in: modelContext)
        } else {
            WaniTaskRules.reopen(todo)
        }
        try? modelContext.save()
    }

    private func delete(_ todo: WaniTodo) {
        WaniTaskRules.moveToTrash(todo)
        expandedTodoID = nil
        try? modelContext.save()
    }
}

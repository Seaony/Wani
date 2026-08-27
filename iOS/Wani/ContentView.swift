import SwiftData
import SwiftUI
import WidgetKit

enum WaniRoute: Hashable {
    case smart(WaniSmartList)
    case project(UUID)
    case task(UUID)
    case search
    case settings
}

enum WaniAddDestination: Hashable, Identifiable {
    case inbox
    case today
    case project(UUID)

    var id: String {
        switch self {
        case .inbox: "inbox"
        case .today: "today"
        case .project(let id): "project-\(id.uuidString)"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WaniArea.sortOrder) private var areas: [WaniArea]
    @Query(sort: \WaniProject.sortOrder) private var projects: [WaniProject]
    @Query(sort: \WaniTodo.sortOrder) private var todos: [WaniTodo]
    @AppStorage("wani.appearance") private var appearanceRawValue = WaniAppearance.system.rawValue
    @AppStorage("wani.accent") private var accentRawValue = WaniAccent.terracotta.rawValue
    @AppStorage("wani.logAtMidnight") private var logAtMidnight = true
    @State private var path: [WaniRoute] = []
    @State private var addSheetVisible = false
    @State private var widgetSnapshotRefreshTask: Task<Void, Never>?

    private var palette: WaniPalette {
        WaniPalette(
            colorScheme: colorScheme,
            accent: WaniAccent(rawValue: accentRawValue) ?? .terracotta
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            WaniRootView(
                areas: areas,
                projects: projects,
                todos: todos,
                projectMetrics: projectMetrics,
                listCounts: listCounts,
                palette: palette,
                open: { path.append($0) }
            )
            .navigationDestination(for: WaniRoute.self) { route in
                destination(for: route)
            }
        }
        .tint(palette.accent)
        .preferredColorScheme(
            (WaniAppearance(rawValue: appearanceRawValue) ?? .system).colorScheme
        )
        .overlay(alignment: .bottomTrailing) {
            Button { addSheetVisible = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(palette.accent, in: Circle())
                    .shadow(color: palette.accent.opacity(0.34), radius: 12, y: 7)
            }
            .accessibilityLabel("Add to-do")
            .accessibilityIdentifier("add-todo")
            .padding(.trailing, 24)
            .padding(.bottom, 18)
        }
        .sheet(isPresented: $addSheetVisible) {
            WaniAddTodoSheet(
                projects: activeProjects,
                initialDestination: addDestination,
                palette: palette
            )
            .presentationDetents([.height(265)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
        }
        .task {
            do {
                try WaniSeedData.insertIfRequested(into: modelContext)
            } catch {
                assertionFailure("Unable to insert preview data: \(error)")
            }
        }
        .onChange(of: widgetSnapshotRevision, initial: true) {
            scheduleWidgetSnapshotRefresh()
        }
        .onChange(of: scenePhase) {
            // Leaving the foreground must not strand a coalesced refresh.
            if scenePhase != .active, widgetSnapshotRefreshTask != nil {
                refreshWidgetSnapshot()
            }
        }
        .onOpenURL(perform: handleWidgetDeepLink)
    }

    @ViewBuilder
    private func destination(for route: WaniRoute) -> some View {
        switch route {
        case .smart, .project:
            WaniListView(
                route: route,
                projects: projects,
                todos: todos,
                projectMetrics: projectMetrics,
                initiallyExpandedTodoID: nil,
                palette: palette,
                openProject: { path.append(.project($0)) }
            )
        case .task(let id):
            if let todo = todos.first(where: { $0.id == id }) {
                WaniListView(
                    route: listRoute(for: todo),
                    projects: projects,
                    todos: todos,
                    projectMetrics: projectMetrics,
                    initiallyExpandedTodoID: id,
                    palette: palette,
                    openProject: { path.append(.project($0)) }
                )
            }
        case .search:
            WaniSearchView(todos: todos, palette: palette) { todo in
                path.append(.task(todo.id))
            }
        case .settings:
            WaniSettingsView(palette: palette)
        }
    }

    private var activeProjects: [WaniProject] {
        projects.filter {
            $0.completedAt == nil && $0.canceledAt == nil && $0.deletedAt == nil
        }
    }

    private var projectMetrics: [UUID: WaniProjectTally] {
        WaniTaskRules.projectTallies(todos)
    }

    private var listCounts: [WaniSmartList: Int] {
        WaniTaskRules.smartListCounts(todos, deferCompletedUntilMidnight: logAtMidnight)
    }

    private func listRoute(for todo: WaniTodo) -> WaniRoute {
        if let projectID = todo.project?.id { return .project(projectID) }
        switch todo.schedule {
        case .inbox: return .smart(.inbox)
        case .anytime: return .smart(.anytime)
        case .someday: return .smart(.someday)
        case .date:
            let tomorrow = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Calendar.current.startOfDay(for: .now)
            )!
            return .smart(todo.startDate.map { $0 >= tomorrow } == true ? .upcoming : .today)
        }
    }

    private var addDestination: WaniAddDestination {
        guard let route = path.last else { return .inbox }
        switch route {
        case .smart(.today): return WaniAddDestination.today
        case .project(let id): return WaniAddDestination.project(id)
        default: return WaniAddDestination.inbox
        }
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
            tasks: todos.map {
                WaniWidgetTaskSnapshot(
                    id: $0.id,
                    title: $0.title,
                    projectID: $0.project?.id,
                    projectTitle: $0.project?.title,
                    status: $0.status.rawValue,
                    schedule: $0.schedule.rawValue,
                    startDate: $0.startDate,
                    deadline: $0.deadline,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    completedAt: $0.completedAt,
                    deletedAt: $0.deletedAt,
                    sortOrder: $0.sortOrder
                )
            },
            projects: projects.map {
                WaniWidgetProjectSnapshot(
                    id: $0.id,
                    title: $0.title,
                    sortOrder: $0.sortOrder,
                    completedAt: $0.completedAt,
                    canceledAt: $0.canceledAt,
                    deletedAt: $0.deletedAt
                )
            }
        )
        guard WaniWidgetSnapshotStore.save(snapshot) else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Widgets only ever offer these actions for open to-dos, so a link from a stale
    /// timeline must not complete or reschedule something that has since changed.
    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "wani",
              url.host == "widget",
              url.pathComponents.count == 3,
              let todoID = UUID(uuidString: url.pathComponents[2]),
              let todo = todos.first(where: {
                  $0.id == todoID && $0.status == .open && $0.deletedAt == nil
              })
        else { return }

        switch url.pathComponents[1] {
        case "complete":
            WaniTodoActions.complete(todo, in: modelContext)
        case "postpone":
            // Same as the macOS widget: push the start to tomorrow, leave the deadline.
            let calendar = Calendar.current
            guard let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: .now)
            ) else { return }
            WaniTaskRules.schedule(todo, as: .date, startDate: tomorrow, isEvening: false)
        default:
            return
        }
        try? modelContext.save()
    }
}

#Preview {
    let container = try! WaniPersistence.makeContainer(inMemory: true)
    ContentView().modelContainer(container)
}

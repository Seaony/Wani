import Foundation

enum WaniSmartList: String, CaseIterable, Identifiable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case trash

    var id: String { rawValue }
}

struct WaniUpcomingDay {
    let date: Date
    let todos: [WaniTodo]
}

struct WaniLogbookMonth {
    let month: Date
    let todos: [WaniTodo]
}

struct WaniCompletedProjectMonth {
    let month: Date
    let projects: [WaniProject]
}

enum WaniTaskRules {
    static func contains(
        _ todo: WaniTodo,
        in list: WaniSmartList,
        now: Date = Date(),
        calendar: Calendar = .current,
        deferCompletedUntilMidnight: Bool = false
    ) -> Bool {
        if list == .trash {
            return todo.deletedAt != nil
        }

        guard todo.deletedAt == nil else { return false }

        if list == .logbook {
            guard todo.status != .open else { return false }
            return !isAwaitingMidnightArchive(
                todo,
                enabled: deferCompletedUntilMidnight,
                now: now,
                calendar: calendar
            )
        }

        guard todo.status == .open else { return false }

        switch list {
        case .inbox:
            return todo.schedule == .inbox
        case .today:
            guard todo.schedule == .date, let startDate = todo.startDate else {
                return false
            }
            let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            )!
            return startDate < tomorrow
        case .upcoming:
            guard todo.schedule == .date, let startDate = todo.startDate else {
                return false
            }
            let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            )!
            return startDate >= tomorrow
        case .anytime:
            return todo.schedule == .anytime || todo.schedule == .date
        case .someday:
            return todo.schedule == .someday
        case .logbook, .trash:
            return false
        }
    }

    static func tasks(
        _ todos: [WaniTodo],
        in list: WaniSmartList,
        now: Date = Date(),
        calendar: Calendar = .current,
        deferCompletedUntilMidnight: Bool = false
    ) -> [WaniTodo] {
        todos
            .filter {
                contains(
                    $0,
                    in: list,
                    now: now,
                    calendar: calendar,
                    deferCompletedUntilMidnight: deferCompletedUntilMidnight
                )
            }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    static func todayTasks(
        _ todos: [WaniTodo],
        evening: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        deferCompletedUntilMidnight: Bool = false
    ) -> [WaniTodo] {
        tasks(
            todos,
            in: .today,
            now: now,
            calendar: calendar,
            deferCompletedUntilMidnight: deferCompletedUntilMidnight
        )
        .filter { $0.isEvening == evening }
    }

    static func upcomingDays(
        _ todos: [WaniTodo],
        now: Date = Date(),
        calendar: Calendar = .current,
        previewDayCount: Int = 8
    ) -> [WaniUpcomingDay] {
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )!
        let upcomingTodos = tasks(todos, in: .upcoming, now: now, calendar: calendar)
        var dates = Set((0..<max(previewDayCount, 0)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: tomorrow)
        })

        for todo in upcomingTodos {
            guard let startDate = todo.startDate else { continue }
            dates.insert(calendar.startOfDay(for: startDate))
        }

        return dates.sorted().map { date in
            WaniUpcomingDay(
                date: date,
                todos: upcomingTodos.filter {
                    guard let startDate = $0.startDate else { return false }
                    return calendar.isDate(startDate, inSameDayAs: date)
                }
            )
        }
    }

    static func logbookMonths(
        _ todos: [WaniTodo],
        now: Date = Date(),
        calendar: Calendar = .current,
        deferCompletedUntilMidnight: Bool = false
    ) -> [WaniLogbookMonth] {
        let archivedTodos = tasks(
            todos,
            in: .logbook,
            now: now,
            calendar: calendar,
            deferCompletedUntilMidnight: deferCompletedUntilMidnight
        )
        let grouped = Dictionary(grouping: archivedTodos) { todo in
            let archivedAt = todo.completedAt ?? todo.canceledAt ?? todo.updatedAt
            return calendar.date(
                from: calendar.dateComponents([.year, .month], from: archivedAt)
            )!
        }

        return grouped.keys.sorted(by: >).map { month in
            WaniLogbookMonth(
                month: month,
                todos: grouped[month, default: []].sorted { lhs, rhs in
                    let leftDate = lhs.completedAt ?? lhs.canceledAt ?? lhs.updatedAt
                    let rightDate = rhs.completedAt ?? rhs.canceledAt ?? rhs.updatedAt
                    if leftDate == rightDate {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return leftDate > rightDate
                }
            )
        }
    }

    static func primaryList(
        for todo: WaniTodo,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaniSmartList {
        if todo.deletedAt != nil { return .trash }
        if todo.status != .open { return .logbook }

        switch todo.schedule {
        case .inbox:
            return .inbox
        case .anytime:
            return .anytime
        case .someday:
            return .someday
        case .date:
            guard let startDate = todo.startDate else { return .anytime }
            let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            )!
            return startDate < tomorrow ? .today : .upcoming
        }
    }

    static func projectTasks(
        _ todos: [WaniTodo],
        projectID: UUID
    ) -> [WaniTodo] {
        todos.filter { $0.project?.id == projectID && $0.deletedAt == nil }
    }

    static func projectProgress(
        _ todos: [WaniTodo],
        projectID: UUID
    ) -> Double {
        let projectTodos = projectTasks(todos, projectID: projectID)
            .filter { $0.status != .canceled }
        guard !projectTodos.isEmpty else { return 0 }
        let completed = projectTodos.filter { $0.status == .completed }.count
        return Double(completed) / Double(projectTodos.count)
    }

    static func canCompleteProject(
        _ project: WaniProject,
        todos: [WaniTodo]
    ) -> Bool {
        projectTasks(todos, projectID: project.id).allSatisfy { $0.status != .open }
    }

    @discardableResult
    static func completeProject(
        _ project: WaniProject,
        todos: [WaniTodo],
        at date: Date = Date()
    ) -> Bool {
        guard canCompleteProject(project, todos: todos) else { return false }
        project.completedAt = date
        project.updatedAt = date
        return true
    }

    static func reopenProject(_ project: WaniProject, at date: Date = Date()) {
        project.completedAt = nil
        project.updatedAt = date
    }

    static func completedProjectMonths(
        _ projects: [WaniProject],
        calendar: Calendar = .current
    ) -> [WaniCompletedProjectMonth] {
        let completedProjects = projects.filter {
            $0.completedAt != nil && $0.deletedAt == nil
        }
        let grouped = Dictionary(grouping: completedProjects) { project in
            calendar.date(
                from: calendar.dateComponents([.year, .month], from: project.completedAt!)
            )!
        }

        return grouped.keys.sorted(by: >).map { month in
            WaniCompletedProjectMonth(
                month: month,
                projects: grouped[month, default: []].sorted {
                    ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
                }
            )
        }
    }

    static func isAwaitingMidnightArchive(
        _ todo: WaniTodo,
        enabled: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard enabled, todo.deletedAt == nil, todo.status != .open else {
            return false
        }
        guard let archivedAt = todo.completedAt ?? todo.canceledAt else {
            return false
        }
        return calendar.isDate(archivedAt, inSameDayAs: now)
    }

    static func move(
        _ todo: WaniTodo,
        to project: WaniProject,
        heading: WaniHeading? = nil,
        at date: Date = Date()
    ) {
        todo.project = project
        todo.heading = heading
        if todo.schedule == .inbox {
            todo.schedule = .anytime
        }
        todo.updatedAt = date
    }

    static func moveToInbox(_ todo: WaniTodo, at date: Date = Date()) {
        todo.project = nil
        todo.heading = nil
        todo.schedule = .inbox
        todo.startDate = nil
        todo.isEvening = false
        todo.updatedAt = date
    }

    static func schedule(
        _ todo: WaniTodo,
        as schedule: WaniTaskSchedule,
        startDate: Date? = nil,
        isEvening: Bool = false,
        at date: Date = Date()
    ) {
        todo.schedule = schedule
        if schedule == .date {
            todo.startDate = startDate ?? date
            todo.isEvening = isEvening
        } else {
            todo.startDate = nil
            todo.isEvening = false
        }
        todo.updatedAt = date
    }

    static func suggestedReminderDate(
        for todo: WaniTodo,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let scheduledMorning = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: todo.startDate ?? now
        )!
        let oneHourFromNow = calendar.date(byAdding: .hour, value: 1, to: now)!
        return max(scheduledMorning, oneHourFromNow)
    }

    static func tags(from input: String) -> [String] {
        var seen: Set<String> = []
        return input
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { tag in
                guard !tag.isEmpty else { return false }
                return seen.insert(tag.lowercased()).inserted
            }
    }

    static func tags(in todos: [WaniTodo]) -> [String] {
        var seen: Set<String> = []
        return todos.flatMap(\.tagNames).filter { tag in
            seen.insert(tag.lowercased()).inserted
        }
    }

    static func tasks(_ todos: [WaniTodo], matchingTag tag: String?) -> [WaniTodo] {
        guard let tag else { return todos }
        return todos.filter { todo in
            todo.tagNames.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
    }

    static func matches(_ todo: WaniTodo, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let values = [
            todo.title,
            todo.notes,
            todo.tagNames.joined(separator: " "),
            todo.project?.title ?? "",
            todo.project?.area?.title ?? "",
        ]

        return values.contains { value in
            value.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    @discardableResult
    static func complete(
        _ todo: WaniTodo,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> WaniTodo? {
        let next = nextOccurrence(for: todo, completedAt: date, calendar: calendar)
        todo.status = .completed
        todo.completedAt = date
        todo.canceledAt = nil
        todo.updatedAt = date
        return next
    }

    static func cancel(_ todo: WaniTodo, at date: Date = Date()) {
        todo.status = .canceled
        todo.completedAt = nil
        todo.canceledAt = date
        todo.updatedAt = date
    }

    static func reopen(_ todo: WaniTodo, at date: Date = Date()) {
        todo.status = .open
        todo.completedAt = nil
        todo.canceledAt = nil
        todo.updatedAt = date
    }

    static func moveToTrash(_ todo: WaniTodo, at date: Date = Date()) {
        todo.deletedAt = date
        todo.updatedAt = date
    }

    static func restore(_ todo: WaniTodo, at date: Date = Date()) {
        todo.deletedAt = nil
        todo.updatedAt = date
    }

    static func moveProjectToTrash(
        _ project: WaniProject,
        todos: [WaniTodo],
        at date: Date = Date()
    ) {
        project.deletedAt = date
        project.updatedAt = date

        for todo in todos where todo.project?.id == project.id && todo.deletedAt == nil {
            todo.deletedAt = date
            todo.updatedAt = date
        }
    }

    static func restoreProject(
        _ project: WaniProject,
        todos: [WaniTodo],
        at date: Date = Date()
    ) {
        let projectDeletedAt = project.deletedAt
        project.deletedAt = nil
        project.updatedAt = date

        for todo in todos where
            todo.project?.id == project.id && todo.deletedAt == projectDeletedAt
        {
            todo.deletedAt = nil
            todo.updatedAt = date
        }
    }

    private static func nextOccurrence(
        for todo: WaniTodo,
        completedAt: Date,
        calendar: Calendar
    ) -> WaniTodo? {
        guard todo.repeatFrequency != .none else { return nil }

        let baseDate = todo.repeatsAfterCompletion
            ? completedAt
            : (todo.startDate ?? completedAt)
        guard let nextDate = nextDate(
            after: baseDate,
            frequency: todo.repeatFrequency,
            interval: todo.repeatInterval,
            calendar: calendar
        ) else {
            return nil
        }

        let next = WaniTodo(
            title: todo.title,
            notes: todo.notes,
            schedule: .date,
            startDate: nextDate,
            project: todo.project,
            heading: todo.heading,
            sortOrder: todo.sortOrder
        )
        next.isEvening = todo.isEvening
        next.repeatFrequency = todo.repeatFrequency
        next.repeatInterval = max(todo.repeatInterval, 1)
        next.repeatsAfterCompletion = todo.repeatsAfterCompletion
        next.tagNames = todo.tagNames

        if let originalStartDate = todo.startDate {
            if let deadline = todo.deadline {
                next.deadline = nextDate.addingTimeInterval(
                    deadline.timeIntervalSince(originalStartDate)
                )
            }
            if let reminderDate = todo.reminderDate {
                next.reminderDate = nextDate.addingTimeInterval(
                    reminderDate.timeIntervalSince(originalStartDate)
                )
            }
        }

        next.checklistItems = (todo.checklistItems ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { item in
                WaniChecklistItem(
                    title: item.title,
                    todo: next,
                    sortOrder: item.sortOrder
                )
            }
        return next
    }

    private static func nextDate(
        after date: Date,
        frequency: WaniRepeatFrequency,
        interval: Int,
        calendar: Calendar
    ) -> Date? {
        let interval = max(interval, 1)
        let component: Calendar.Component

        switch frequency {
        case .none:
            return nil
        case .daily:
            component = .day
        case .weekly:
            component = .weekOfYear
        case .monthly:
            component = .month
        case .yearly:
            component = .year
        }

        return calendar.date(byAdding: component, value: interval, to: date)
    }
}

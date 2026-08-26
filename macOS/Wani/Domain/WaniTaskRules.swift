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

struct WaniArchivedProjectMonth {
    let month: Date
    let projects: [WaniProject]
}

enum WaniTaskRules {
    static func reorderedIDs(
        _ ids: [UUID],
        moving movingID: UUID,
        to targetID: UUID
    ) -> [UUID] {
        guard
            movingID != targetID,
            let sourceIndex = ids.firstIndex(of: movingID),
            let targetIndex = ids.firstIndex(of: targetID)
        else { return ids }

        var result = ids
        result.remove(at: sourceIndex)
        result.insert(movingID, at: min(targetIndex, result.count))
        return result
    }

    static func reorder(
        _ todos: [WaniTodo],
        moving movingID: UUID,
        to targetID: UUID,
        at date: Date = .now
    ) -> Bool {
        let orderedTodos = todos.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
        let ids = orderedTodos.map(\.id)
        let reordered = reorderedIDs(ids, moving: movingID, to: targetID)
        guard reordered != ids else { return false }

        let sortOrders = orderedTodos.map(\.sortOrder).sorted()
        for (id, sortOrder) in zip(reordered, sortOrders) {
            guard let todo = orderedTodos.first(where: { $0.id == id }) else { continue }
            todo.sortOrder = sortOrder
            todo.updatedAt = date
        }
        return true
    }

    static func reorderChecklistItems(
        _ items: [WaniChecklistItem],
        moving movingID: UUID,
        to targetID: UUID,
        at date: Date = .now
    ) -> Bool {
        let orderedItems = items.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
        let ids = orderedItems.map(\.id)
        let reordered = reorderedIDs(ids, moving: movingID, to: targetID)
        guard reordered != ids else { return false }

        let sortOrders = orderedItems.map(\.sortOrder).sorted()
        for (id, sortOrder) in zip(reordered, sortOrders) {
            guard let item = orderedItems.first(where: { $0.id == id }) else { continue }
            item.sortOrder = sortOrder
            item.updatedAt = date
        }
        return true
    }

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
            return isProjectLogged(
                todo,
                deferCompletedUntilMidnight: deferCompletedUntilMidnight,
                now: now,
                calendar: calendar
            )
        }

        guard todo.status == .open || isAwaitingMidnightArchive(
            todo,
            enabled: deferCompletedUntilMidnight,
            now: now,
            calendar: calendar
        ) else { return false }

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
            if todo.schedule == .anytime {
                return true
            }
            guard todo.schedule == .date, let startDate = todo.startDate else {
                return false
            }
            let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            )!
            return startDate < tomorrow
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
        previewDayCount: Int = 8,
        deferCompletedUntilMidnight: Bool = false
    ) -> [WaniUpcomingDay] {
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )!
        let upcomingTodos = tasks(
            todos,
            in: .upcoming,
            now: now,
            calendar: calendar,
            deferCompletedUntilMidnight: deferCompletedUntilMidnight
        )
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
        calendar: Calendar = .current,
        deferCompletedUntilMidnight: Bool = false
    ) -> WaniSmartList {
        if todo.deletedAt != nil { return .trash }
        if todo.status != .open && !isAwaitingMidnightArchive(
            todo,
            enabled: deferCompletedUntilMidnight,
            now: now,
            calendar: calendar
        ) {
            return .logbook
        }

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
        todos: [WaniTodo],
        headings: [WaniHeading]
    ) -> Bool {
        projectTasks(todos, projectID: project.id).allSatisfy { $0.status != .open }
            && headings
                .filter { $0.project?.id == project.id }
                .allSatisfy { $0.archivedAt != nil }
    }

    @discardableResult
    static func completeProject(
        _ project: WaniProject,
        todos: [WaniTodo],
        headings: [WaniHeading],
        at date: Date = Date()
    ) -> Bool {
        guard canCompleteProject(project, todos: todos, headings: headings) else {
            return false
        }
        project.completedAt = date
        project.canceledAt = nil
        project.updatedAt = date
        return true
    }

    @discardableResult
    static func cancelProject(
        _ project: WaniProject,
        todos: [WaniTodo],
        headings: [WaniHeading],
        at date: Date = Date()
    ) -> Bool {
        guard canCompleteProject(project, todos: todos, headings: headings) else {
            return false
        }
        project.completedAt = nil
        project.canceledAt = date
        project.updatedAt = date
        return true
    }

    static func reopenProject(_ project: WaniProject, at date: Date = Date()) {
        project.completedAt = nil
        project.canceledAt = nil
        project.updatedAt = date
    }

    static func canArchiveHeading(
        _ heading: WaniHeading,
        todos: [WaniTodo]
    ) -> Bool {
        todos
            .filter { $0.heading?.id == heading.id && $0.deletedAt == nil }
            .allSatisfy { $0.status != .open }
    }

    @discardableResult
    static func archiveHeading(
        _ heading: WaniHeading,
        todos: [WaniTodo],
        at date: Date = Date()
    ) -> Bool {
        guard canArchiveHeading(heading, todos: todos) else { return false }
        heading.archivedAt = date
        heading.updatedAt = date
        return true
    }

    static func reopenHeading(_ heading: WaniHeading, at date: Date = Date()) {
        heading.archivedAt = nil
        heading.updatedAt = date
    }

    static func archivedProjectMonths(
        _ projects: [WaniProject],
        calendar: Calendar = .current
    ) -> [WaniArchivedProjectMonth] {
        let archivedProjects = projects.filter {
            ($0.completedAt != nil || $0.canceledAt != nil) && $0.deletedAt == nil
        }
        let grouped = Dictionary(grouping: archivedProjects) { project in
            calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: project.completedAt ?? project.canceledAt ?? project.updatedAt
                )
            )!
        }

        return grouped.keys.sorted(by: >).map { month in
            WaniArchivedProjectMonth(
                month: month,
                projects: grouped[month, default: []].sorted {
                    ($0.completedAt ?? $0.canceledAt ?? .distantPast)
                        > ($1.completedAt ?? $1.canceledAt ?? .distantPast)
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
        guard enabled,
              todo.deletedAt == nil,
              todo.status != .open,
              todo.loggedAt == nil else {
            return false
        }
        guard let archivedAt = todo.completedAt ?? todo.canceledAt else {
            return false
        }
        return calendar.isDate(archivedAt, inSameDayAs: now)
    }

    static func isProjectLogged(
        _ todo: WaniTodo,
        deferCompletedUntilMidnight: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard todo.status != .open, todo.deletedAt == nil else { return false }
        if todo.heading?.archivedAt != nil { return true }
        return !isAwaitingMidnightArchive(
            todo,
            enabled: deferCompletedUntilMidnight,
            now: now,
            calendar: calendar
        )
    }

    static func move(
        _ todo: WaniTodo,
        to project: WaniProject,
        heading: WaniHeading? = nil,
        at date: Date = Date()
    ) {
        todo.project = project
        todo.heading = heading
        todo.area = nil
        if todo.schedule == .inbox {
            todo.schedule = .anytime
        }
        todo.updatedAt = date
    }

    @discardableResult
    static func groupUnheadedTodos(
        _ todos: [WaniTodo],
        under heading: WaniHeading,
        in project: WaniProject,
        at date: Date = Date()
    ) -> Bool {
        guard
            !todos.isEmpty,
            heading.project?.id == project.id,
            todos.allSatisfy({
                $0.project?.id == project.id && $0.heading == nil
            })
        else { return false }

        for todo in todos {
            move(todo, to: project, heading: heading, at: date)
        }
        return true
    }

    static func moveToInbox(_ todo: WaniTodo, at date: Date = Date()) {
        todo.project = nil
        todo.heading = nil
        todo.area = nil
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
        matches([
            todo.title,
            todo.notes,
            todo.tagNames.joined(separator: " "),
            todo.project?.title ?? "",
            todo.project?.area?.title ?? todo.area?.title ?? "",
        ], query: query)
    }

    static func matches(_ project: WaniProject, query: String) -> Bool {
        matches([
            project.title,
            project.notes,
            project.area?.title ?? "",
        ], query: query)
    }

    static func matches(_ area: WaniArea, query: String) -> Bool {
        matches([area.title, area.notes], query: query)
    }

    private static func matches(_ values: [String], query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

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
        let next: WaniTodo?
        if todo.repeatGeneratedNextStartDate == nil {
            next = nextOccurrence(for: todo, completedAt: date, calendar: calendar)
            todo.repeatGeneratedNextStartDate = next?.startDate
        } else {
            next = nil
        }
        todo.status = .completed
        todo.completedAt = date
        todo.canceledAt = nil
        todo.loggedAt = nil
        todo.updatedAt = date
        return next
    }

    static func generateDueRegularOccurrences(
        from todo: WaniTodo,
        through date: Date = Date(),
        calendar: Calendar = .current
    ) -> [WaniTodo] {
        guard
            todo.status == .open,
            todo.deletedAt == nil,
            todo.schedule == .date,
            todo.repeatFrequency != .none,
            !todo.repeatsAfterCompletion,
            todo.repeatGeneratedNextStartDate == nil
        else { return [] }

        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        )!
        var source = todo
        var occurrences: [WaniTodo] = []

        while
            let startDate = source.startDate,
            startDate < tomorrow,
            source.repeatGeneratedNextStartDate == nil,
            let next = nextOccurrence(
                for: source,
                completedAt: startDate,
                calendar: calendar
            )
        {
            source.repeatGeneratedNextStartDate = next.startDate
            source.updatedAt = date
            occurrences.append(next)
            source = next
        }

        return occurrences
    }

    static func cancel(_ todo: WaniTodo, at date: Date = Date()) {
        todo.status = .canceled
        todo.completedAt = nil
        todo.canceledAt = date
        todo.loggedAt = nil
        todo.updatedAt = date
    }

    @discardableResult
    static func logNow(_ todo: WaniTodo, at date: Date = Date()) -> Bool {
        guard todo.status != .open,
              todo.deletedAt == nil,
              todo.loggedAt == nil else { return false }
        todo.loggedAt = date
        todo.updatedAt = date
        return true
    }

    static func reopen(_ todo: WaniTodo, at date: Date = Date()) {
        todo.status = .open
        todo.completedAt = nil
        todo.canceledAt = nil
        todo.loggedAt = nil
        todo.updatedAt = date
        if let heading = todo.heading, heading.archivedAt != nil {
            reopenHeading(heading, at: date)
        }
    }

    static func moveToTrash(_ todo: WaniTodo, at date: Date = Date()) {
        todo.deletedAt = date
        todo.updatedAt = date
    }

    static func restore(_ todo: WaniTodo, at date: Date = Date()) {
        todo.deletedAt = nil
        todo.updatedAt = date
    }

    static func move(
        _ todo: WaniTodo,
        to area: WaniArea,
        at date: Date = Date()
    ) {
        todo.area = area
        todo.project = nil
        todo.heading = nil
        if todo.schedule == .inbox {
            todo.schedule = .anytime
        }
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

    static func moveAreaContentsToTrash(
        _ area: WaniArea,
        projects: [WaniProject],
        todos: [WaniTodo],
        at date: Date = Date()
    ) {
        for todo in todos where todo.area?.id == area.id {
            if todo.deletedAt == nil {
                moveToTrash(todo, at: date)
            }
            todo.area = nil
        }

        for project in projects where project.area?.id == area.id {
            if project.deletedAt == nil {
                moveProjectToTrash(project, todos: todos, at: date)
            }
            project.area = nil
            project.updatedAt = date
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
            area: todo.area,
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

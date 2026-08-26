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

enum WaniTaskRules {
    static func contains(
        _ todo: WaniTodo,
        in list: WaniSmartList,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if list == .trash {
            return todo.deletedAt != nil
        }

        guard todo.deletedAt == nil else { return false }

        if list == .logbook {
            return todo.status != .open
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
        calendar: Calendar = .current
    ) -> [WaniTodo] {
        todos
            .filter { contains($0, in: list, now: now, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
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

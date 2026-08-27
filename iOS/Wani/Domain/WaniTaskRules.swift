import Foundation

enum WaniSmartList: String, CaseIterable, Identifiable, Hashable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case trash

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .today: "star.fill"
        case .upcoming: "calendar"
        case .anytime: "square.3.layers.3d"
        case .someday: "archivebox"
        case .logbook: "checkmark.square"
        case .trash: "trash"
        }
    }
}

struct WaniUpcomingDay: Identifiable {
    let date: Date
    let todos: [WaniTodo]

    var id: Date { date }
}

struct WaniProjectMetrics {
    var total = 0
    var open = 0
    var completed = 0

    var progress: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }
}

enum WaniTaskRules {
    static func tasks(
        _ todos: [WaniTodo],
        in list: WaniSmartList,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WaniTodo] {
        todos.filter { todo in
            if list == .trash { return todo.deletedAt != nil }
            guard todo.deletedAt == nil else { return false }
            if list == .logbook { return todo.status != .open }
            guard todo.status == .open else { return false }

            switch list {
            case .inbox:
                return todo.schedule == .inbox
            case .today:
                let tomorrow = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: now)
                )!
                let startsByToday = todo.schedule == .date
                    && todo.startDate.map { $0 < tomorrow } == true
                let deadlineToday = todo.deadline.map {
                    calendar.isDate($0, inSameDayAs: now)
                } == true
                return startsByToday || deadlineToday
            case .upcoming:
                let tomorrow = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: now)
                )!
                return todo.schedule == .date
                    && todo.startDate.map { $0 >= tomorrow } == true
            case .anytime:
                if todo.schedule == .anytime { return true }
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
        .sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder { return lhs.createdAt < rhs.createdAt }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    static func upcomingDays(
        _ todos: [WaniTodo],
        count: Int = 8,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WaniUpcomingDay] {
        let start = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )!
        let upcoming = tasks(todos, in: .upcoming, now: now, calendar: calendar)
        let byDay = Dictionary(grouping: upcoming) { todo in
            calendar.startOfDay(for: todo.startDate ?? start)
        }
        return (0..<max(count, 0)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            return WaniUpcomingDay(date: date, todos: byDay[date] ?? [])
        }
    }

    static func projectMetrics(_ todos: [WaniTodo]) -> [UUID: WaniProjectMetrics] {
        var result: [UUID: WaniProjectMetrics] = [:]
        for todo in todos where todo.deletedAt == nil {
            guard let projectID = todo.project?.id else { continue }
            result[projectID, default: WaniProjectMetrics()].total += 1
            if todo.status == .open {
                result[projectID, default: WaniProjectMetrics()].open += 1
            } else if todo.status == .completed {
                result[projectID, default: WaniProjectMetrics()].completed += 1
            }
        }
        return result
    }

    static func listCounts(
        _ todos: [WaniTodo],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WaniSmartList: Int] {
        var result = Dictionary(uniqueKeysWithValues: WaniSmartList.allCases.map { ($0, 0) })
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )!

        for todo in todos {
            if todo.deletedAt != nil {
                result[.trash, default: 0] += 1
                continue
            }
            guard todo.status == .open else {
                result[.logbook, default: 0] += 1
                continue
            }
            switch todo.schedule {
            case .inbox:
                result[.inbox, default: 0] += 1
            case .anytime:
                result[.anytime, default: 0] += 1
            case .someday:
                result[.someday, default: 0] += 1
            case .date:
                if todo.startDate.map({ $0 < tomorrow }) == true {
                    result[.today, default: 0] += 1
                    result[.anytime, default: 0] += 1
                } else if todo.startDate != nil {
                    result[.upcoming, default: 0] += 1
                }
            }
            if todo.deadline.map({ calendar.isDate($0, inSameDayAs: now) }) == true,
               !(todo.schedule == .date && todo.startDate.map { $0 < tomorrow } == true) {
                result[.today, default: 0] += 1
            }
        }
        return result
    }
}

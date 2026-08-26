import Foundation

struct WaniWidgetTaskSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let projectID: UUID?
    let projectTitle: String?
    let status: String
    let schedule: String
    let startDate: Date?
    let deadline: Date?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let deletedAt: Date?
    let sortOrder: Double
}

struct WaniWidgetProjectSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let sortOrder: Double
    let completedAt: Date?
    let canceledAt: Date?
    let deletedAt: Date?
}

struct WaniWidgetUpcomingDay: Equatable, Identifiable {
    let date: Date
    let tasks: [WaniWidgetTaskSnapshot]

    var id: Date { date }
}

struct WaniWidgetProjectProgress: Equatable, Identifiable {
    let project: WaniWidgetProjectSnapshot
    let openCount: Int
    let completedCount: Int
    let progress: Double

    var id: UUID { project.id }
}

struct WaniWidgetDateMarks: Equatable {
    var scheduled = false
    var deadline = false
}

struct WaniWidgetSnapshot: Codable, Equatable {
    let generatedAt: Date
    let tasks: [WaniWidgetTaskSnapshot]
    let projects: [WaniWidgetProjectSnapshot]

    static let empty = WaniWidgetSnapshot(
        generatedAt: .distantPast,
        tasks: [],
        projects: []
    )

    func inboxTasks() -> [WaniWidgetTaskSnapshot] {
        orderedOpenTasks.filter { $0.schedule == "inbox" }
    }

    func todayTasks(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WaniWidgetTaskSnapshot] {
        guard let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) else { return [] }

        return orderedOpenTasks.filter { task in
            let startsByToday = task.schedule == "date"
                && task.startDate.map { $0 < tomorrow } == true
            let deadlineIsToday = task.deadline.map {
                calendar.isDate($0, inSameDayAs: now)
            } == true
            return startsByToday || deadlineIsToday
        }
    }

    func completedTodayCount(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        tasks.filter { task in
            task.deletedAt == nil
                && task.status == "completed"
                && task.completedAt.map { calendar.isDate($0, inSameDayAs: now) } == true
        }.count
    }

    func upcomingDays(
        count: Int = 6,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WaniWidgetUpcomingDay] {
        guard let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) else { return [] }

        return (0..<max(count, 0)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: tomorrow) else {
                return nil
            }
            let tasks = orderedOpenTasks.filter { task in
                if task.schedule == "date",
                   let startDate = task.startDate,
                   calendar.isDate(startDate, inSameDayAs: date) {
                    return true
                }
                return task.deadline.map { calendar.isDate($0, inSameDayAs: date) } == true
            }
            return WaniWidgetUpcomingDay(date: date, tasks: tasks)
        }
    }

    func projectProgress() -> [WaniWidgetProjectProgress] {
        let tasksByProject = Dictionary(
            grouping: tasks.filter {
                $0.projectID != nil
                    && $0.deletedAt == nil
                    && $0.status != "canceled"
            },
            by: { $0.projectID! }
        )

        return projects
            .filter {
                $0.completedAt == nil
                    && $0.canceledAt == nil
                    && $0.deletedAt == nil
            }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map { project in
                let projectTasks = tasksByProject[project.id] ?? []
                let completed = projectTasks.filter { $0.status == "completed" }.count
                let open = projectTasks.filter { $0.status == "open" }.count
                let progress = projectTasks.isEmpty
                    ? 0
                    : Double(completed) / Double(projectTasks.count)
                return WaniWidgetProjectProgress(
                    project: project,
                    openCount: open,
                    completedCount: completed,
                    progress: progress
                )
            }
    }

    func datedTaskCount(
        in month: Date,
        calendar: Calendar = .current
    ) -> Int {
        Set(tasks.compactMap { task -> Date? in
            guard task.deletedAt == nil else { return nil }
            let date = task.deadline ?? task.startDate
            guard let date, calendar.isDate(date, equalTo: month, toGranularity: .month) else {
                return nil
            }
            return calendar.startOfDay(for: date)
        }).count
    }

    func monthMarks(
        in month: Date,
        calendar: Calendar = .current
    ) -> [Date: WaniWidgetDateMarks] {
        var result: [Date: WaniWidgetDateMarks] = [:]
        for task in tasks where task.deletedAt == nil {
            if let startDate = task.startDate,
               calendar.isDate(startDate, equalTo: month, toGranularity: .month) {
                let day = calendar.startOfDay(for: startDate)
                result[day, default: WaniWidgetDateMarks()].scheduled = true
            }
            if let deadline = task.deadline,
               calendar.isDate(deadline, equalTo: month, toGranularity: .month) {
                let day = calendar.startOfDay(for: deadline)
                result[day, default: WaniWidgetDateMarks()].deadline = true
            }
        }
        return result
    }

    private var orderedOpenTasks: [WaniWidgetTaskSnapshot] {
        tasks
            .filter { $0.status == "open" && $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }
}

enum WaniWidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.seaony.wani.Wani"
    private static let fileName = "widget-snapshot.json"

    @discardableResult
    static func save(_ snapshot: WaniWidgetSnapshot) -> Bool {
        guard let fileURL else { return false }

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load() -> WaniWidgetSnapshot? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL)
        else { return nil }
        return try? JSONDecoder().decode(WaniWidgetSnapshot.self, from: data)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

enum WaniWidgetDeepLink {
    static func complete(todoID: UUID) -> URL {
        URL(string: "wani://widget/complete/\(todoID.uuidString)")!
    }

    static func postpone(todoID: UUID) -> URL {
        URL(string: "wani://widget/postpone/\(todoID.uuidString)")!
    }

    static func quickCapture(destination: String, projectID: UUID? = nil) -> URL {
        var components = URLComponents(string: "wani://widget/quick-capture")!
        components.queryItems = [URLQueryItem(name: "destination", value: destination)]
        if let projectID {
            components.queryItems?.append(
                URLQueryItem(name: "project", value: projectID.uuidString)
            )
        }
        return components.url!
    }
}

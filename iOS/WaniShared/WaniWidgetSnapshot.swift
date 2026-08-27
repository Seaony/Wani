import Foundation

struct WaniWidgetTaskSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
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

struct WaniWidgetSnapshot: Codable, Equatable {
    let generatedAt: Date
    let tasks: [WaniWidgetTaskSnapshot]

    static let empty = WaniWidgetSnapshot(generatedAt: .distantPast, tasks: [])

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
            let deadlineToday = task.deadline.map {
                calendar.isDate($0, inSameDayAs: now)
            } == true
            return startsByToday || deadlineToday
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
        let byDay = Dictionary(grouping: orderedOpenTasks.compactMap { task -> WaniWidgetTaskSnapshot? in
            guard task.schedule == "date",
                  let startDate = task.startDate,
                  startDate >= tomorrow
            else { return nil }
            return task
        }) { task in
            calendar.startOfDay(for: task.startDate ?? tomorrow)
        }
        return (0..<max(count, 0)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: tomorrow) else {
                return nil
            }
            return WaniWidgetUpcomingDay(date: date, tasks: byDay[date] ?? [])
        }
    }

    private var orderedOpenTasks: [WaniWidgetTaskSnapshot] {
        tasks
            .filter { $0.status == "open" && $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder { return lhs.createdAt < rhs.createdAt }
                return lhs.sortOrder < rhs.sortOrder
            }
    }
}

struct WaniWidgetUpcomingDay: Equatable, Identifiable {
    let date: Date
    let tasks: [WaniWidgetTaskSnapshot]

    var id: Date { date }
}

enum WaniWidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.seaony.wani.Wani"
    private static let fileName = "ios-widget-snapshot.json"

    @discardableResult
    static func save(_ snapshot: WaniWidgetSnapshot) -> Bool {
        guard let fileURL else { return false }
        do {
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load() -> WaniWidgetSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
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
}

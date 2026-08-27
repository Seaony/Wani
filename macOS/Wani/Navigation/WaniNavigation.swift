import Foundation
import SwiftUI

enum WaniNavigationTarget: Hashable {
    case smart(WaniSmartList)
    case area(UUID)
    case project(UUID)

    func acceptsNewTodos(
        areas: [WaniArea],
        projects: [WaniProject]
    ) -> Bool {
        switch self {
        case .smart(.logbook), .smart(.trash):
            return false
        case .smart:
            return true
        case .area(let areaID):
            return areas.contains { $0.id == areaID }
        case .project(let projectID):
            guard let project = projects.first(where: { $0.id == projectID }) else {
                return false
            }
            return project.completedAt == nil
                && project.canceledAt == nil
                && project.deletedAt == nil
        }
    }

    func makeTodo(
        title: String,
        areas: [WaniArea],
        projects: [WaniProject],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WaniTodo {
        guard acceptsNewTodos(areas: areas, projects: projects) else {
            return WaniTodo(title: title, schedule: .inbox)
        }

        switch self {
        case .smart(.today):
            return WaniTodo(
                title: title,
                schedule: .date,
                startDate: calendar.startOfDay(for: now)
            )
        case .smart(.upcoming):
            return WaniTodo(
                title: title,
                schedule: .date,
                startDate: calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: now)
                )
            )
        case .smart(.anytime):
            return WaniTodo(title: title, schedule: .anytime)
        case .smart(.someday):
            return WaniTodo(title: title, schedule: .someday)
        case .area(let areaID):
            return WaniTodo(
                title: title,
                schedule: .anytime,
                area: areas.first { $0.id == areaID }
            )
        case .project(let projectID):
            return WaniTodo(
                title: title,
                schedule: .anytime,
                project: projects.first { $0.id == projectID }
            )
        default:
            return WaniTodo(title: title, schedule: .inbox)
        }
    }
}

extension WaniSmartList {
    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .anytime: "Anytime"
        case .someday: "Someday"
        case .logbook: "Logbook"
        case .trash: "Trash"
        }
    }

    var symbolName: String {
        switch self {
        case .inbox: "tray.fill"
        case .today: "star.fill"
        case .upcoming: "calendar"
        case .anytime: "square.3.layers.3d"
        case .someday: "archivebox.fill"
        case .logbook: "checkmark"
        case .trash: "trash.fill"
        }
    }

    var symbolColor: Color {
        switch self {
        case .inbox: Color(hex: 0x4A7BA7)
        case .today: Color(hex: 0xC9922A)
        case .upcoming: Color(hex: 0xC3564C)
        case .anytime: Color(hex: 0x5B8C6C)
        case .someday: Color(hex: 0x9A8A5F)
        case .logbook: Color(hex: 0x5B8C6C)
        case .trash: Color.gray
        }
    }
}

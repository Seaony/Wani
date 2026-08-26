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
        case .inbox: Color(red: 0.29, green: 0.48, blue: 0.65)
        case .today: Color(red: 0.79, green: 0.57, blue: 0.16)
        case .upcoming: Color(red: 0.76, green: 0.34, blue: 0.30)
        case .anytime: Color(red: 0.36, green: 0.55, blue: 0.42)
        case .someday: Color(red: 0.60, green: 0.54, blue: 0.37)
        case .logbook: Color(red: 0.36, green: 0.55, blue: 0.42)
        case .trash: Color.gray
        }
    }
}

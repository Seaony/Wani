import Foundation
import SwiftData

enum WaniTaskStatus: String, Codable, CaseIterable {
    case open
    case completed
    case canceled
}

enum WaniTaskSchedule: String, Codable, CaseIterable {
    case inbox
    case anytime
    case someday
    case date
}

enum WaniRepeatFrequency: String, Codable, CaseIterable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
}

@Model
final class WaniArea {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var sortOrder: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \WaniProject.area)
    var projects: [WaniProject]? = []

    @Relationship(deleteRule: .nullify, inverse: \WaniTodo.area)
    var todos: [WaniTodo]? = []

    init(title: String, sortOrder: Double = 0) {
        self.title = title
        self.sortOrder = sortOrder
    }
}

@Model
final class WaniProject {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var sortOrder: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?
    var deletedAt: Date?
    var area: WaniArea?

    @Relationship(deleteRule: .nullify, inverse: \WaniHeading.project)
    var headings: [WaniHeading]? = []

    @Relationship(deleteRule: .nullify, inverse: \WaniTodo.project)
    var todos: [WaniTodo]? = []

    init(title: String, area: WaniArea? = nil, sortOrder: Double = 0) {
        self.title = title
        self.area = area
        self.sortOrder = sortOrder
    }
}

@Model
final class WaniHeading {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var project: WaniProject?

    @Relationship(deleteRule: .nullify, inverse: \WaniTodo.heading)
    var todos: [WaniTodo]? = []

    init(title: String, project: WaniProject? = nil, sortOrder: Double = 0) {
        self.title = title
        self.project = project
        self.sortOrder = sortOrder
    }
}

@Model
final class WaniTodo {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var statusRawValue: String = WaniTaskStatus.open.rawValue
    var scheduleRawValue: String = WaniTaskSchedule.inbox.rawValue
    var startDate: Date?
    var isEvening: Bool = false
    var deadline: Date?
    var reminderDate: Date?
    var repeatFrequencyRawValue: String = WaniRepeatFrequency.none.rawValue
    var repeatInterval: Int = 1
    var repeatsAfterCompletion: Bool = false
    var tagNamesData: Data?
    var sortOrder: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?
    var canceledAt: Date?
    var deletedAt: Date?
    var area: WaniArea?
    var project: WaniProject?
    var heading: WaniHeading?

    @Relationship(deleteRule: .cascade, inverse: \WaniChecklistItem.todo)
    var checklistItems: [WaniChecklistItem]? = []

    var status: WaniTaskStatus {
        get { WaniTaskStatus(rawValue: statusRawValue) ?? .open }
        set { statusRawValue = newValue.rawValue }
    }

    var schedule: WaniTaskSchedule {
        get { WaniTaskSchedule(rawValue: scheduleRawValue) ?? .inbox }
        set { scheduleRawValue = newValue.rawValue }
    }

    var repeatFrequency: WaniRepeatFrequency {
        get { WaniRepeatFrequency(rawValue: repeatFrequencyRawValue) ?? .none }
        set { repeatFrequencyRawValue = newValue.rawValue }
    }

    var tagNames: [String] {
        get {
            guard let tagNamesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: tagNamesData)) ?? []
        }
        set {
            tagNamesData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        title: String,
        notes: String = "",
        schedule: WaniTaskSchedule = .inbox,
        startDate: Date? = nil,
        area: WaniArea? = nil,
        project: WaniProject? = nil,
        heading: WaniHeading? = nil,
        sortOrder: Double = 0
    ) {
        self.title = title
        self.notes = notes
        self.scheduleRawValue = schedule.rawValue
        self.startDate = startDate
        self.area = area
        self.project = project
        self.heading = heading
        self.sortOrder = sortOrder
    }
}

@Model
final class WaniChecklistItem {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var sortOrder: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var todo: WaniTodo?

    init(title: String, todo: WaniTodo? = nil, sortOrder: Double = 0) {
        self.title = title
        self.todo = todo
        self.sortOrder = sortOrder
    }
}

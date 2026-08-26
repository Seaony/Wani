import Foundation
import UserNotifications

struct WaniReminderRequest: Equatable {
    let identifier: String
    let title: String
    let body: String
    let dateComponents: DateComponents
}

@MainActor
enum WaniReminderScheduler {
    static func makeRequest(
        for todo: WaniTodo,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaniReminderRequest? {
        guard
            todo.status == .open,
            todo.deletedAt == nil,
            todo.schedule == .date,
            todo.startDate != nil,
            let reminderDate = todo.reminderDate,
            reminderDate > now
        else { return nil }

        return WaniReminderRequest(
            identifier: identifier(for: todo),
            title: todo.title,
            body: todo.notes.isEmpty ? (todo.project?.title ?? "Wani") : todo.notes,
            dateComponents: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
        )
    }

    static func makeDeadlineRequest(
        for todo: WaniTodo,
        enabled: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaniReminderRequest? {
        guard
            enabled,
            todo.status == .open,
            todo.deletedAt == nil,
            let deadline = todo.deadline,
            let notificationDate = calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: deadline
            ),
            notificationDate > now
        else { return nil }

        return WaniReminderRequest(
            identifier: deadlineIdentifier(for: todo),
            title: todo.title,
            body: todo.project.map { "Deadline today · \($0.title)" } ?? "Deadline today",
            dateComponents: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            )
        )
    }

    static func sync(
        _ todo: WaniTodo,
        requestAuthorization: Bool,
        deadlineNotificationsEnabled: Bool = true
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            identifier(for: todo),
            deadlineIdentifier(for: todo),
        ])

        let requests = [
            makeRequest(for: todo),
            makeDeadlineRequest(for: todo, enabled: deadlineNotificationsEnabled),
        ].compactMap { $0 }
        guard !requests.isEmpty else { return }

        let settings = await center.notificationSettings()
        var authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        if !authorized, requestAuthorization, settings.authorizationStatus == .notDetermined {
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        }

        guard authorized else { return }

        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: request.dateComponents,
                repeats: false
            )
            try? await center.add(UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: trigger
            ))
        }
    }

    static func cancel(_ todo: WaniTodo) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                identifier(for: todo),
                deadlineIdentifier(for: todo),
            ]
        )
    }

    private static func identifier(for todo: WaniTodo) -> String {
        "wani.todo.\(todo.id.uuidString)"
    }

    private static func deadlineIdentifier(for todo: WaniTodo) -> String {
        "wani.todo.\(todo.id.uuidString).deadline"
    }
}

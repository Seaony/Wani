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

    static func sync(
        _ todo: WaniTodo,
        requestAuthorization: Bool
    ) async {
        let center = UNUserNotificationCenter.current()
        let identifier = identifier(for: todo)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let request = makeRequest(for: todo) else { return }

        let settings = await center.notificationSettings()
        var authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        if !authorized, requestAuthorization, settings.authorizationStatus == .notDetermined {
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        }

        guard authorized else { return }

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

    static func cancel(_ todo: WaniTodo) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: todo)]
        )
    }

    private static func identifier(for todo: WaniTodo) -> String {
        "wani.todo.\(todo.id.uuidString)"
    }
}

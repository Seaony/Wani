import Foundation
import Testing
@testable import Wani

@Suite("Wani task rules")
struct WaniTaskRulesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Global Quick Entry exposes distinct configurable shortcuts")
    func globalQuickEntryShortcuts() {
        let shortcuts = WaniQuickEntryShortcut.allCases
        #expect(shortcuts.count == 3)
        #expect(Set(shortcuts.map(\.rawValue)).count == shortcuts.count)
        #expect(shortcuts.first?.title == "⌃Space")
    }

    @Test("Smart lists classify tasks by lifecycle and date")
    func smartListClassification() {
        let now = date(2026, 8, 26, 12)
        let inbox = WaniTodo(title: "Inbox", schedule: .inbox)
        let anytime = WaniTodo(title: "Anytime", schedule: .anytime)
        let today = WaniTodo(
            title: "Today",
            schedule: .date,
            startDate: date(2026, 8, 26, 18)
        )
        let overdue = WaniTodo(
            title: "Overdue",
            schedule: .date,
            startDate: date(2026, 8, 25, 9)
        )
        let future = WaniTodo(
            title: "Future",
            schedule: .date,
            startDate: date(2026, 8, 28, 9)
        )
        let someday = WaniTodo(title: "Someday", schedule: .someday)
        let completed = WaniTodo(title: "Completed", schedule: .anytime)
        completed.status = .completed
        completed.completedAt = now
        let deleted = WaniTodo(title: "Deleted", schedule: .inbox)
        deleted.deletedAt = now

        #expect(WaniTaskRules.contains(inbox, in: .inbox, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(today, in: .today, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(overdue, in: .today, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(future, in: .upcoming, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(anytime, in: .anytime, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(today, in: .anytime, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(future, in: .anytime, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(someday, in: .someday, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(completed, in: .logbook, now: now, calendar: calendar))
        #expect(WaniTaskRules.contains(deleted, in: .trash, now: now, calendar: calendar))
        #expect(!WaniTaskRules.contains(deleted, in: .inbox, now: now, calendar: calendar))
        #expect(WaniTaskRules.primaryList(for: today, now: now, calendar: calendar) == .today)
        #expect(WaniTaskRules.primaryList(for: future, now: now, calendar: calendar) == .upcoming)
        #expect(WaniTaskRules.primaryList(for: completed, now: now, calendar: calendar) == .logbook)
        #expect(WaniTaskRules.primaryList(for: deleted, now: now, calendar: calendar) == .trash)
    }

    @Test("Search covers task content and hierarchy")
    func searchCoverage() {
        let area = WaniArea(title: "Personal")
        let project = WaniProject(title: "Garden", area: area)
        let todo = WaniTodo(
            title: "Water the fig tree",
            notes: "Use the rain barrel",
            schedule: .anytime,
            project: project
        )
        todo.tagNames = ["Outdoors"]

        #expect(WaniTaskRules.matches(todo, query: "fig"))
        #expect(WaniTaskRules.matches(todo, query: "RAIN"))
        #expect(WaniTaskRules.matches(todo, query: "outdoor"))
        #expect(WaniTaskRules.matches(todo, query: "garden"))
        #expect(WaniTaskRules.matches(todo, query: "personal"))
        #expect(!WaniTaskRules.matches(todo, query: "work"))
    }

    @Test("Completing a repeating task creates the next occurrence")
    func repeatingCompletion() {
        let completedAt = date(2026, 8, 26, 12)
        let todo = WaniTodo(
            title: "Weekly review",
            notes: "Clear the inbox",
            schedule: .date,
            startDate: date(2026, 8, 24, 9)
        )
        todo.deadline = date(2026, 8, 25, 17)
        todo.reminderDate = date(2026, 8, 24, 8)
        todo.repeatFrequency = .weekly
        todo.repeatInterval = 2
        todo.repeatsAfterCompletion = true
        todo.tagNames = ["Review"]
        todo.checklistItems = [
            WaniChecklistItem(title: "Process notes", todo: todo, sortOrder: 0),
        ]

        let next = WaniTaskRules.complete(todo, at: completedAt, calendar: calendar)

        #expect(todo.status == .completed)
        #expect(todo.completedAt == completedAt)
        #expect(next?.title == todo.title)
        #expect(next?.startDate == date(2026, 9, 9, 12))
        #expect(next?.deadline == date(2026, 9, 10, 20))
        #expect(next?.reminderDate == date(2026, 9, 9, 11))
        #expect(next?.tagNames == ["Review"])
        #expect(next?.checklistItems?.first?.isCompleted == false)
    }

    @Test("Trash restore and cancellation preserve state transitions")
    func lifecycleTransitions() {
        let now = date(2026, 8, 26, 12)
        let todo = WaniTodo(title: "Lifecycle", schedule: .anytime)

        WaniTaskRules.cancel(todo, at: now)
        #expect(todo.status == .canceled)
        #expect(todo.canceledAt == now)

        WaniTaskRules.reopen(todo, at: now.addingTimeInterval(60))
        #expect(todo.status == .open)
        #expect(todo.completedAt == nil)
        #expect(todo.canceledAt == nil)

        WaniTaskRules.moveToTrash(todo, at: now)
        #expect(todo.deletedAt == now)

        WaniTaskRules.restore(todo, at: now.addingTimeInterval(60))
        #expect(todo.deletedAt == nil)
    }

    @Test("Project progress includes open and completed tasks")
    func projectProgress() {
        let project = WaniProject(title: "Launch")
        let open = WaniTodo(title: "Open", project: project)
        let completed = WaniTodo(title: "Completed", project: project)
        completed.status = .completed
        let canceled = WaniTodo(title: "Canceled", project: project)
        canceled.status = .canceled
        let deleted = WaniTodo(title: "Deleted", project: project)
        deleted.deletedAt = date(2026, 8, 26, 12)

        let todos = [open, completed, canceled, deleted]
        #expect(WaniTaskRules.projectTasks(todos, projectID: project.id).count == 3)
        #expect(WaniTaskRules.projectProgress(todos, projectID: project.id) == 0.5)
    }

    @Test("Moving tasks updates project heading and Inbox scheduling")
    func moveTask() {
        let now = date(2026, 8, 26, 12)
        let project = WaniProject(title: "Launch")
        let heading = WaniHeading(title: "Polish", project: project)
        let todo = WaniTodo(title: "Move me", schedule: .inbox)

        WaniTaskRules.move(todo, to: project, heading: heading, at: now)
        #expect(todo.project?.id == project.id)
        #expect(todo.heading?.id == heading.id)
        #expect(todo.schedule == .anytime)
        #expect(todo.updatedAt == now)

        WaniTaskRules.moveToInbox(todo, at: now.addingTimeInterval(60))
        #expect(todo.project == nil)
        #expect(todo.heading == nil)
        #expect(todo.schedule == .inbox)
        #expect(todo.startDate == nil)
    }

    @Test("Tags are trimmed and deduplicated")
    func tagParsing() {
        #expect(
            WaniTaskRules.tags(from: " Work, home\nWORK,  errands ")
                == ["Work", "home", "errands"]
        )
    }

    @Test("Project tag filters preserve tag order and match without case sensitivity")
    func projectTagFiltering() {
        let first = WaniTodo(title: "First")
        first.tagNames = ["Work", "Urgent"]
        let second = WaniTodo(title: "Second")
        second.tagNames = ["work", "Home"]

        #expect(WaniTaskRules.tags(in: [first, second]) == ["Work", "Urgent", "Home"])
        #expect(
            WaniTaskRules.tasks([first, second], matchingTag: "WORK").map(\.title)
                == ["First", "Second"]
        )
        #expect(WaniTaskRules.tasks([first, second], matchingTag: nil).count == 2)
    }

    @Test("Scheduling updates date and evening state consistently")
    func scheduleTask() {
        let now = date(2026, 8, 26, 12)
        let tomorrow = date(2026, 8, 27, 9)
        let todo = WaniTodo(title: "Schedule", schedule: .inbox)

        WaniTaskRules.schedule(
            todo,
            as: .date,
            startDate: tomorrow,
            isEvening: true,
            at: now
        )
        #expect(todo.schedule == .date)
        #expect(todo.startDate == tomorrow)
        #expect(todo.isEvening)
        #expect(todo.updatedAt == now)

        WaniTaskRules.schedule(todo, as: .someday, at: now)
        #expect(todo.schedule == .someday)
        #expect(todo.startDate == nil)
        #expect(!todo.isEvening)
    }

    @Test("Today separates daytime and evening tasks")
    func todaySections() {
        let now = date(2026, 8, 26, 12)
        let daytime = WaniTodo(
            title: "Daytime",
            schedule: .date,
            startDate: date(2026, 8, 26, 9)
        )
        let evening = WaniTodo(
            title: "Evening",
            schedule: .date,
            startDate: date(2026, 8, 26, 18)
        )
        evening.isEvening = true
        let futureEvening = WaniTodo(
            title: "Future evening",
            schedule: .date,
            startDate: date(2026, 8, 27, 18)
        )
        futureEvening.isEvening = true

        let todos = [daytime, evening, futureEvening]
        #expect(
            WaniTaskRules.todayTasks(
                todos,
                evening: false,
                now: now,
                calendar: calendar
            ).map(\.title) == ["Daytime"]
        )
        #expect(
            WaniTaskRules.todayTasks(
                todos,
                evening: true,
                now: now,
                calendar: calendar
            ).map(\.title) == ["Evening"]
        )
    }

    @Test("Upcoming includes empty preview days, month boundaries, and distant tasks")
    func upcomingDays() {
        let now = date(2026, 8, 26, 12)
        let tomorrow = WaniTodo(
            title: "Tomorrow",
            schedule: .date,
            startDate: date(2026, 8, 27, 9)
        )
        let september = WaniTodo(
            title: "September",
            schedule: .date,
            startDate: date(2026, 9, 1, 9)
        )
        let distant = WaniTodo(
            title: "Distant",
            schedule: .date,
            startDate: date(2026, 9, 9, 9)
        )

        let days = WaniTaskRules.upcomingDays(
            [tomorrow, september, distant],
            now: now,
            calendar: calendar
        )

        #expect(days.count == 9)
        #expect(days.first?.date == date(2026, 8, 27, 0))
        #expect(days.first?.todos.map(\.title) == ["Tomorrow"])
        #expect(days[1].date == date(2026, 8, 28, 0))
        #expect(days[1].todos.isEmpty)
        #expect(days[5].date == date(2026, 9, 1, 0))
        #expect(days[5].todos.map(\.title) == ["September"])
        #expect(days.last?.date == date(2026, 9, 9, 0))
        #expect(days.last?.todos.map(\.title) == ["Distant"])
    }

    @Test("Logbook groups completed and canceled tasks by month in reverse order")
    func logbookMonths() {
        let july = WaniTodo(title: "July")
        july.status = .completed
        july.completedAt = date(2026, 7, 9, 10)
        let augustCanceled = WaniTodo(title: "August canceled")
        augustCanceled.status = .canceled
        augustCanceled.canceledAt = date(2026, 8, 20, 12)
        let augustCompleted = WaniTodo(title: "August completed")
        augustCompleted.status = .completed
        augustCompleted.completedAt = date(2026, 8, 25, 12)

        let months = WaniTaskRules.logbookMonths(
            [july, augustCanceled, augustCompleted],
            now: date(2026, 8, 26, 12),
            calendar: calendar
        )

        #expect(months.count == 2)
        #expect(months[0].month == date(2026, 8, 1, 0))
        #expect(months[0].todos.map(\.title) == ["August completed", "August canceled"])
        #expect(months[1].month == date(2026, 7, 1, 0))
        #expect(months[1].todos.map(\.title) == ["July"])
    }

    @Test("Suggested reminders never start in the past")
    func suggestedReminder() {
        let now = date(2026, 8, 26, 12)
        let todo = WaniTodo(
            title: "Reminder",
            schedule: .date,
            startDate: date(2026, 8, 26, 0)
        )

        #expect(
            WaniTaskRules.suggestedReminderDate(
                for: todo,
                now: now,
                calendar: calendar
            ) == date(2026, 8, 26, 13)
        )
    }

    @Test("Reminder requests include stable identity and future date")
    func reminderRequest() {
        let now = date(2026, 8, 26, 12)
        let project = WaniProject(title: "Launch")
        let todo = WaniTodo(title: "Review", project: project)
        todo.reminderDate = date(2026, 8, 27, 9)

        let request = WaniReminderScheduler.makeRequest(
            for: todo,
            now: now,
            calendar: calendar
        )

        #expect(request?.identifier == "wani.todo.\(todo.id.uuidString)")
        #expect(request?.title == "Review")
        #expect(request?.body == "Launch")
        #expect(request?.dateComponents.day == 27)
        #expect(request?.dateComponents.hour == 9)

        todo.status = .completed
        #expect(
            WaniReminderScheduler.makeRequest(for: todo, now: now, calendar: calendar) == nil
        )
    }

    @Test("Deadline notifications fire at nine on the deadline date")
    func deadlineRequest() {
        let now = date(2026, 8, 26, 12)
        let project = WaniProject(title: "Launch")
        let todo = WaniTodo(title: "Ship", project: project)
        todo.deadline = date(2026, 8, 28, 17)

        let request = WaniReminderScheduler.makeDeadlineRequest(
            for: todo,
            enabled: true,
            now: now,
            calendar: calendar
        )

        #expect(request?.identifier == "wani.todo.\(todo.id.uuidString).deadline")
        #expect(request?.body == "Deadline today · Launch")
        #expect(request?.dateComponents.day == 28)
        #expect(request?.dateComponents.hour == 9)
        #expect(
            WaniReminderScheduler.makeDeadlineRequest(
                for: todo,
                enabled: false,
                now: now,
                calendar: calendar
            ) == nil
        )
    }

    @Test("Midnight archive defers today's completed items")
    func midnightArchive() {
        let now = date(2026, 8, 26, 12)
        let today = WaniTodo(title: "Today")
        today.status = .completed
        today.completedAt = date(2026, 8, 26, 9)
        let yesterday = WaniTodo(title: "Yesterday")
        yesterday.status = .completed
        yesterday.completedAt = date(2026, 8, 25, 18)

        #expect(WaniTaskRules.isAwaitingMidnightArchive(
            today,
            enabled: true,
            now: now,
            calendar: calendar
        ))
        #expect(!WaniTaskRules.contains(
            today,
            in: .logbook,
            now: now,
            calendar: calendar,
            deferCompletedUntilMidnight: true
        ))
        #expect(WaniTaskRules.contains(
            yesterday,
            in: .logbook,
            now: now,
            calendar: calendar,
            deferCompletedUntilMidnight: true
        ))
    }

    @Test("Range selection includes both endpoints in display order")
    func rangeSelection() {
        let ids = [UUID(), UUID(), UUID(), UUID()]

        #expect(WaniSelectionRules.range(
            from: ids[3],
            through: ids[1],
            in: ids
        ) == Set([ids[1], ids[2], ids[3]]))
        #expect(WaniSelectionRules.range(
            from: nil,
            through: ids[2],
            in: ids
        ) == Set([ids[2]]))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}

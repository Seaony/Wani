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

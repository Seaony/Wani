import Foundation
import Testing
@testable import Wani

@Suite("Wani iOS task rules")
struct WaniTaskRulesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Test launches select an in-memory store")
    func ephemeralStoreSelection() {
        #expect(WaniPersistence.usesEphemeralStore(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/Wani.xctestconfiguration"]
        ))
        #expect(WaniPersistence.usesEphemeralStore(
            arguments: ["--in-memory"],
            environment: [:]
        ))
        #expect(!WaniPersistence.usesEphemeralStore(arguments: [], environment: [:]))
    }

    @Test("iOS shares the macOS model and CloudKit container")
    func sharedDataLayer() throws {
        #expect(
            WaniPersistence.cloudKitContainerIdentifier == "iCloud.com.seaony.wani.Wani"
        )
        // The full model, not the reduced one iOS used to carry: headings, areas on a
        // to-do, cancellation, reminders and repeat rules all have to round-trip or
        // macOS changes would be dropped on sync.
        let entities = Set(WaniPersistence.schema.entities.map(\.name))
        #expect(entities == [
            "WaniArea",
            "WaniProject",
            "WaniHeading",
            "WaniTodo",
            "WaniChecklistItem",
        ])

        let todo = WaniTodo(title: "Round trip", schedule: .anytime)
        todo.heading = WaniHeading(title: "Heading")
        todo.area = WaniArea(title: "Personal")
        todo.reminderDate = date(2026, 8, 27, 9)
        todo.repeatFrequency = .weekly
        WaniTaskRules.cancel(todo, at: date(2026, 8, 27, 10))

        #expect(todo.heading?.title == "Heading")
        #expect(todo.area?.title == "Personal")
        #expect(todo.canceledAt == date(2026, 8, 27, 10))
        #expect(todo.repeatFrequency == .weekly)
    }

    @Test("List counts preserve Today and Anytime overlap")
    func listCounts() {
        let now = date(2026, 8, 27, 12)
        let today = WaniTodo(
            title: "Today",
            schedule: .date,
            startDate: date(2026, 8, 27, 0)
        )
        let upcoming = WaniTodo(
            title: "Tomorrow",
            schedule: .date,
            startDate: date(2026, 8, 28, 0)
        )
        let inbox = WaniTodo(title: "Inbox", schedule: .inbox)
        let logged = WaniTodo(title: "Done", schedule: .anytime)
        logged.status = .completed
        let deleted = WaniTodo(title: "Deleted", schedule: .anytime)
        deleted.deletedAt = now

        let counts = WaniTaskRules.smartListCounts(
            [today, upcoming, inbox, logged, deleted],
            now: now,
            calendar: calendar
        )

        #expect(counts[.today] == 1)
        #expect(counts[.anytime] == 1)
        #expect(counts[.upcoming] == 1)
        #expect(counts[.inbox] == 1)
        #expect(counts[.logbook] == 1)
        #expect(counts[.trash] == 1)
    }

    @Test("Project tallies are built in one task pass")
    func projectTallies() {
        let project = WaniProject(title: "Mantis")
        let open = WaniTodo(title: "Open", schedule: .anytime, project: project)
        let completed = WaniTodo(title: "Done", schedule: .anytime, project: project)
        completed.status = .completed
        let deleted = WaniTodo(title: "Deleted", schedule: .anytime, project: project)
        deleted.deletedAt = .now

        let tally = WaniTaskRules.projectTallies([open, completed, deleted])[project.id]

        #expect(tally?.uncanceled == 2)
        #expect(tally?.open == 1)
        #expect(tally?.completed == 1)
        #expect(tally?.progress == 0.5)
    }

    @Test("Upcoming returns continuous days including empty dates")
    func upcomingDays() {
        let now = date(2026, 8, 27, 12)
        let scheduled = WaniTodo(
            title: "Later",
            schedule: .date,
            startDate: date(2026, 8, 29, 0)
        )

        let days = WaniTaskRules.upcomingDays(
            [scheduled],
            now: now,
            calendar: calendar,
            previewDayCount: 3
        )

        #expect(days.count == 3)
        #expect(days[0].todos.isEmpty)
        #expect(days[1].todos.map(\.id) == [scheduled.id])
        #expect(days[2].todos.isEmpty)
    }

    @Test("Widget snapshot derives Today, completed, and upcoming data")
    func widgetSnapshot() {
        let now = date(2026, 8, 27, 12)
        let today = widgetTask(
            title: "Today",
            startDate: date(2026, 8, 27, 0),
            sortOrder: 1
        )
        let completed = widgetTask(
            title: "Completed",
            status: .completed,
            completedAt: date(2026, 8, 27, 10),
            sortOrder: 2
        )
        let upcoming = widgetTask(
            title: "Upcoming",
            startDate: date(2026, 8, 29, 0),
            sortOrder: 3
        )
        let spanning = widgetTask(
            title: "Spanning",
            startDate: date(2026, 8, 29, 0),
            deadline: date(2026, 8, 30, 0),
            sortOrder: 4
        )
        let snapshot = WaniWidgetSnapshot(
            generatedAt: now,
            tasks: [today, completed, upcoming, spanning],
            projects: []
        )

        #expect(snapshot.todayTasks(now: now, calendar: calendar).map(\.title) == ["Today"])
        #expect(snapshot.completedTodayCount(now: now, calendar: calendar) == 1)
        let days = snapshot.upcomingDays(count: 3, now: now, calendar: calendar)
        #expect(days.count == 3)
        #expect(days[0].tasks.isEmpty)
        // A scheduled start wins over the deadline, so the spanning task is not
        // listed a second time on its due day.
        #expect(days[1].tasks.map(\.title) == ["Upcoming", "Spanning"])
        #expect(days[2].tasks.isEmpty)
    }

    @Test("Widget actions produce routable URLs")
    func widgetDeepLinks() {
        let id = UUID(uuidString: "9A04E8D4-4EAC-4C3E-A7F2-0481715EB72C")!

        #expect(WaniWidgetDeepLink.complete(todoID: id).absoluteString
            == "wani://widget/complete/9A04E8D4-4EAC-4C3E-A7F2-0481715EB72C")
        #expect(WaniWidgetDeepLink.postpone(todoID: id).absoluteString
            == "wani://widget/postpone/9A04E8D4-4EAC-4C3E-A7F2-0481715EB72C")
    }

    private func widgetTask(
        title: String,
        status: WaniTaskStatus = .open,
        startDate: Date? = nil,
        deadline: Date? = nil,
        completedAt: Date? = nil,
        sortOrder: Double
    ) -> WaniWidgetTaskSnapshot {
        WaniWidgetTaskSnapshot(
            id: UUID(),
            title: title,
            projectID: nil,
            projectTitle: nil,
            status: status.rawValue,
            schedule: startDate == nil ? WaniTaskSchedule.inbox.rawValue : WaniTaskSchedule.date.rawValue,
            startDate: startDate,
            deadline: deadline,
            createdAt: date(2026, 8, 20, 0),
            updatedAt: date(2026, 8, 27, 0),
            completedAt: completedAt,
            deletedAt: nil,
            sortOrder: sortOrder
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}

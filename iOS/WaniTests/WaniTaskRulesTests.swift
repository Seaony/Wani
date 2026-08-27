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

        let counts = WaniTaskRules.listCounts(
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

    @Test("Project metrics are built in one task pass")
    func projectMetrics() {
        let project = WaniProject(title: "Mantis")
        let open = WaniTodo(title: "Open", schedule: .anytime, project: project)
        let completed = WaniTodo(title: "Done", schedule: .anytime, project: project)
        completed.status = .completed
        let deleted = WaniTodo(title: "Deleted", schedule: .anytime, project: project)
        deleted.deletedAt = .now

        let metrics = WaniTaskRules.projectMetrics([open, completed, deleted])[project.id]

        #expect(metrics?.total == 2)
        #expect(metrics?.open == 1)
        #expect(metrics?.completed == 1)
        #expect(metrics?.progress == 0.5)
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
            count: 3,
            now: now,
            calendar: calendar
        )

        #expect(days.count == 3)
        #expect(days[0].todos.isEmpty)
        #expect(days[1].todos.map(\.id) == [scheduled.id])
        #expect(days[2].todos.isEmpty)
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

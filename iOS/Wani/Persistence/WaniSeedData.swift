import Foundation
import SwiftData

enum WaniSeedData {
    @MainActor
    static func insertIfRequested(
        into context: ModelContext,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        guard arguments.contains("--seed-preview-data") else { return }
        let existing = try context.fetch(FetchDescriptor<WaniTodo>())
        guard existing.isEmpty else { return }

        let jobs = WaniArea(title: "Jobs", sortOrder: 0)
        let personal = WaniArea(title: "Personal", sortOrder: 1)
        let mantis = WaniProject(title: "Mantis", area: jobs, sortOrder: 0)
        mantis.notes = "Notes"
        let yesimart = WaniProject(title: "Yesimart", area: jobs, sortOrder: 1)
        let ideas = WaniProject(title: "Ideas", area: personal, sortOrder: 0)
        let things = WaniProject(title: "Things", area: personal, sortOrder: 1)
        let hobbies = WaniProject(title: "Hobbies", area: personal, sortOrder: 2)
        [jobs, personal].forEach(context.insert)
        [mantis, yesimart, ideas, things, hobbies].forEach(context.insert)

        let today = calendar.startOfDay(for: now)
        let samples: [(String, WaniTaskSchedule, Int?, WaniProject?, String, [String])] = [
            ("Send the revised Mantis scope to Dana", .date, 0, mantis, "Include the Q3 timeline and the new pricing tier.", ["Work"]),
            ("Book flights for the Yesimart workshop", .date, 0, nil, "", ["Travel"]),
            ("Water the fig tree", .date, 0, nil, "", []),
            ("Thirty minutes of guitar", .date, 0, hobbies, "", []),
            ("Read two chapters of A Pattern Language", .date, 0, ideas, "", []),
            ("Send August invoices", .date, 1, yesimart, "Mantis retainer plus the two Yesimart sprints.", ["Money"]),
            ("Yesimart analytics handoff", .date, 1, yesimart, "", ["Important"]),
            ("Weekly review", .date, 2, nil, "", []),
            ("Draft the quarterly planning doc", .date, 4, mantis, "", []),
            ("Renew both domain names", .date, 6, nil, "", []),
            ("Mantis onboarding copy pass", .date, 7, mantis, "", ["Work"]),
            ("Ask Ana about the studio lease", .inbox, nil, nil, "", []),
            ("Portfolio should show one dense desktop tool", .anytime, nil, ideas, "", ["Important"]),
            ("CloudWatch stalls when the parameter JSON expands", .anytime, nil, mantis, "", []),
            ("Plan the autumn reading list", .someday, nil, ideas, "", []),
        ]

        for (index, sample) in samples.enumerated() {
            let todo = WaniTodo(
                title: sample.0,
                notes: sample.4,
                schedule: sample.1,
                startDate: sample.2.flatMap {
                    calendar.date(byAdding: .day, value: $0, to: today)
                },
                project: sample.3,
                sortOrder: Double(index)
            )
            todo.tagNames = sample.5
            todo.isNew = index < 2
            if index == 0 {
                todo.deadline = today
                let checklist = [
                    WaniChecklistItem(title: "Update timeline sheet", todo: todo, sortOrder: 0),
                    WaniChecklistItem(title: "Re-price tier 3", todo: todo, sortOrder: 1),
                    WaniChecklistItem(title: "Export as PDF", todo: todo, sortOrder: 2),
                ]
                checklist[0].isCompleted = true
                checklist.forEach(context.insert)
            }
            context.insert(todo)
        }

        let completed = [
            "Remove the Credits refund flow entirely",
            "Nautilus command history points everything at system",
            "Format every backend timestamp to local time",
            "Yesimart UI and UX polish",
        ]
        for (index, title) in completed.enumerated() {
            let todo = WaniTodo(
                title: title,
                schedule: .anytime,
                project: index == 3 ? yesimart : mantis,
                sortOrder: Double(100 + index)
            )
            todo.status = .completed
            todo.completedAt = calendar.date(byAdding: .day, value: -(index * 12 + 4), to: today)
            todo.loggedAt = todo.completedAt
            context.insert(todo)
        }
        try context.save()
    }
}

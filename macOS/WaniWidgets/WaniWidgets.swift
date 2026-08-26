import SwiftUI
import WidgetKit

struct WaniWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WaniWidgetSnapshot
}

struct WaniWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaniWidgetEntry {
        WaniWidgetEntry(date: .now, snapshot: .preview())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (WaniWidgetEntry) -> Void
    ) {
        let snapshot = context.isPreview
            ? WaniWidgetSnapshot.preview()
            : WaniWidgetSnapshotStore.load() ?? .empty
        completion(WaniWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<WaniWidgetEntry>) -> Void
    ) {
        let entry = WaniWidgetEntry(
            date: .now,
            snapshot: WaniWidgetSnapshotStore.load() ?? .empty
        )
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)
            ?? entry.date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

private struct WaniWidgetPalette {
    let card: Color
    let text: Color
    let secondary: Color
    let tertiary: Color
    let line: Color
    let hover: Color
    let accent: Color
    let softAccent: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            card = Color(rgb: 0x28221B)
            text = Color(rgb: 0xEFE7DC)
            secondary = Color(rgb: 0xAC9F92)
            tertiary = Color(rgb: 0x83766A)
            line = Color.white.opacity(0.10)
            hover = Color.white.opacity(0.08)
            accent = Color(rgb: 0xE0794E)
            softAccent = Color(rgb: 0xE0794E).opacity(0.18)
        } else {
            card = Color(rgb: 0xFFFDF9)
            text = Color(rgb: 0x3A312A)
            secondary = Color(rgb: 0x786A5E)
            tertiary = Color(rgb: 0xAAA095)
            line = Color(rgb: 0x8C735A).opacity(0.15)
            hover = Color(rgb: 0xB49678).opacity(0.13)
            accent = Color(rgb: 0xC05A34)
            softAccent = Color(rgb: 0xF7E4D9)
        }
    }
}

private struct WaniWidgetHeader: View {
    let symbol: String
    let title: String
    let color: Color
    let palette: WaniWidgetPalette
    var trailing: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(palette.tertiary)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.tertiary)
            }
        }
    }
}

private struct WaniTodaySummaryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let tasks = entry.snapshot.todayTasks(now: entry.date)
        let completed = entry.snapshot.completedTodayCount(now: entry.date)

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "star.fill",
                title: "Today",
                color: Color(rgb: 0xC9922A),
                palette: palette
            )
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(tasks.count.formatted())
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(-2)
                    .foregroundStyle(palette.text)
                Text("to do")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondary)
            }
            .padding(.top, 7)
            Text(completed == 0 ? "Nothing logged yet" : "\(completed) done today")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.tertiary)
                .padding(.top, 1)
            Spacer(minLength: 4)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<7, id: \.self) { offset in
                    let count = dayTaskCount(offset: offset)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(offset == weekdayOffset ? palette.accent : palette.line)
                            .frame(height: CGFloat(4 + min(count, 7) * 2))
                        Text(weekdayLetter(offset: offset))
                            .font(.system(size: 8))
                            .foregroundStyle(palette.tertiary)
                    }
                }
            }
            .frame(height: 22, alignment: .bottom)
        }
        .padding(14)
        .waniWidgetBackground(palette.card)
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
    }

    private var weekdayOffset: Int {
        Calendar.current.dateComponents([.day], from: weekStart, to: entry.date).day ?? 0
    }

    private func dayTaskCount(offset: Int) -> Int {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        else { return 0 }
        return entry.snapshot.tasks.filter { task in
            task.deletedAt == nil
                && (task.startDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
                    || task.deadline.map { Calendar.current.isDate($0, inSameDayAs: date) } == true)
        }.count
    }

    private func weekdayLetter(offset: Int) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        else { return "" }
        return date.formatted(.dateTime.weekday(.narrow))
    }
}

private struct WaniProjectProgressView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let progress = entry.snapshot.projectProgress().first

        VStack(spacing: 0) {
            WaniWidgetHeader(
                symbol: "circle.fill",
                title: progress?.project.title ?? "Project",
                color: palette.accent,
                palette: palette
            )
            ZStack {
                Circle()
                    .stroke(palette.line, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress?.progress ?? 0)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text((progress?.progress ?? 0).formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text("complete")
                        .font(.system(size: 8.5))
                        .foregroundStyle(palette.tertiary)
                }
            }
            .frame(width: 70, height: 70)
            .padding(.top, 9)
            Spacer(minLength: 3)
            Text("\(progress?.openCount ?? 0) open · \(progress?.completedCount ?? 0) done")
                .font(.system(size: 11))
                .foregroundStyle(palette.secondary)
        }
        .padding(14)
        .waniWidgetBackground(palette.card)
    }
}

private struct WaniInboxView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let tasks = entry.snapshot.inboxTasks()

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "tray",
                title: "Inbox",
                color: Color(rgb: 0x4A7BA7),
                palette: palette
            )
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tasks.prefix(3)) { task in
                    HStack(spacing: 7) {
                        Circle().fill(palette.tertiary).frame(width: 4, height: 4)
                        Text(task.title)
                            .font(.system(size: 11.5))
                            .lineLimit(1)
                            .foregroundStyle(palette.text)
                    }
                }
                if tasks.isEmpty {
                    Text("Inbox is clear")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tertiary)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            Text("\(tasks.count) unsorted")
                .font(.system(size: 11))
                .foregroundStyle(palette.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 7)
                .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
        }
        .padding(14)
        .waniWidgetBackground(palette.card)
    }
}

private struct WaniNextUpView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let task = entry.snapshot.todayTasks(now: entry.date).first

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "clock.arrow.circlepath",
                title: "Next up",
                color: palette.accent,
                palette: palette
            )
            VStack(alignment: .leading, spacing: 5) {
                Text(task?.title ?? "Nothing left today")
                    .font(.system(size: 13.5, weight: .medium))
                    .lineLimit(3)
                    .foregroundStyle(palette.text)
                Text(task.map { ($0.projectTitle ?? "Inbox") + deadlineSuffix($0) } ?? "Enjoy the quiet")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(palette.tertiary)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            if let task {
                HStack(spacing: 5) {
                    Link(destination: WaniWidgetDeepLink.complete(todoID: task.id)) {
                        Text("Complete")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .foregroundStyle(palette.accent)
                    Link(destination: WaniWidgetDeepLink.postpone(todoID: task.id)) {
                        Text("1d")
                            .frame(width: 32)
                            .padding(.vertical, 6)
                            .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .foregroundStyle(palette.secondary)
                }
                .font(.system(size: 11, weight: .medium))
            }
        }
        .padding(14)
        .waniWidgetBackground(palette.card)
    }

    private func deadlineSuffix(_ task: WaniWidgetTaskSnapshot) -> String {
        guard let deadline = task.deadline else { return "" }
        return " · due " + deadline.formatted(date: .omitted, time: .shortened)
    }
}

private struct WaniTodayListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let tasks = entry.snapshot.todayTasks(now: entry.date)

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "star.fill",
                title: "Today",
                color: Color(rgb: 0xC9922A),
                palette: palette,
                trailing: entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            )
            .padding(.bottom, 6)
            VStack(spacing: 1) {
                ForEach(tasks.prefix(3)) { task in
                    Link(destination: WaniWidgetDeepLink.complete(todoID: task.id)) {
                        HStack(spacing: 9) {
                            Circle()
                                .stroke(palette.tertiary, lineWidth: 1.4)
                                .frame(width: 14, height: 14)
                            Text(task.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .foregroundStyle(palette.text)
                            Spacer(minLength: 4)
                            Text(task.projectTitle ?? "Inbox")
                                .font(.system(size: 10))
                                .foregroundStyle(palette.tertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            Text(tasks.count > 3 ? "\(tasks.count - 3) more in Today" : "All caught up")
                .font(.system(size: 10.5))
                .foregroundStyle(palette.tertiary)
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .waniWidgetBackground(palette.card)
    }
}

private struct WaniProjectsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let projects = entry.snapshot.projectProgress()

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "square.3.layers.3d",
                title: "Projects",
                color: Color(rgb: 0x5B8C6B),
                palette: palette
            )
            VStack(spacing: 8) {
                ForEach(projects.prefix(4)) { item in
                    HStack(spacing: 10) {
                        Text(item.project.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .frame(width: 66, alignment: .leading)
                            .foregroundStyle(palette.text)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(palette.line)
                                Capsule()
                                    .fill(progressColor(item.progress, palette: palette))
                                    .frame(width: geometry.size.width * item.progress)
                            }
                        }
                        .frame(height: 5)
                        Text(item.progress.formatted(.percent.precision(.fractionLength(0))))
                            .font(.system(size: 10.5))
                            .monospacedDigit()
                            .foregroundStyle(palette.tertiary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .waniWidgetBackground(palette.card)
    }

    private func progressColor(_ progress: Double, palette: WaniWidgetPalette) -> Color {
        if progress >= 0.6 { return palette.accent }
        if progress >= 0.3 { return Color(rgb: 0xC9922A) }
        return palette.tertiary
    }
}

private struct WaniQuickCaptureView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let projects = entry.snapshot.projectProgress().prefix(2)

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "plus.app",
                title: "Quick capture",
                color: palette.accent,
                palette: palette
            )
            Link(destination: WaniWidgetDeepLink.quickCapture(destination: "inbox")) {
                HStack(spacing: 8) {
                    Text("Anything on your mind…")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.tertiary)
                    Spacer()
                    Text("N")
                        .font(.system(size: 10.5))
                        .foregroundStyle(palette.tertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(palette.hover, in: RoundedRectangle(cornerRadius: 11))
            }
            .padding(.top, 10)
            Spacer(minLength: 5)
            HStack(spacing: 6) {
                destinationLink("Inbox", destination: "inbox", projectID: nil, palette: palette)
                destinationLink("Today", destination: "today", projectID: nil, palette: palette)
                ForEach(projects) { item in
                    destinationLink(
                        item.project.title,
                        destination: "project",
                        projectID: item.project.id,
                        palette: palette
                    )
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .waniWidgetBackground(palette.card)
    }

    private func destinationLink(
        _ title: String,
        destination: String,
        projectID: UUID?,
        palette: WaniWidgetPalette
    ) -> some View {
        Link(destination: WaniWidgetDeepLink.quickCapture(
            destination: destination,
            projectID: projectID
        )) {
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .foregroundStyle(destination == "inbox" ? palette.accent : palette.secondary)
                .background(
                    destination == "inbox" ? palette.softAccent : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
    }
}

private struct WaniUpcomingView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let days = entry.snapshot.upcomingDays(count: 6, now: entry.date)

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "calendar",
                title: "Upcoming",
                color: Color(rgb: 0xC3564C),
                palette: palette,
                trailing: "Next 6 days"
            )
            .padding(.bottom, 7)
            VStack(spacing: 2) {
                ForEach(days) { day in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(day.date.formatted(.dateTime.day()))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(day.tasks.isEmpty ? palette.tertiary : palette.text)
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                .font(.system(size: 8.5))
                                .foregroundStyle(palette.tertiary)
                        }
                        .frame(width: 27, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            if day.tasks.isEmpty {
                                Text("—")
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.tertiary)
                            } else {
                                ForEach(day.tasks.prefix(2)) { task in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(task.deadline != nil ? palette.accent : Color(rgb: 0xC9922A))
                                            .frame(width: 5, height: 5)
                                        Text(task.title)
                                            .font(.system(size: 11.5))
                                            .lineLimit(1)
                                            .foregroundStyle(palette.text)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        .padding(.leading, 11)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(palette.line).frame(width: 1)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .waniWidgetBackground(palette.card)
    }
}

private struct WaniMonthView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WaniWidgetEntry

    var body: some View {
        let palette = WaniWidgetPalette(colorScheme: colorScheme)
        let cells = monthCells
        let marksByDay = entry.snapshot.monthMarks(in: entry.date)

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "calendar",
                title: entry.date.formatted(.dateTime.month(.wide)),
                color: Color(rgb: 0xC9922A),
                palette: palette,
                trailing: "\(entry.snapshot.datedTaskCount(in: entry.date)) dated days"
            )
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 5)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(cells.indices, id: \.self) { index in
                    if let date = cells[index] {
                        let marks = marksByDay[Calendar.current.startOfDay(for: date)]
                            ?? WaniWidgetDateMarks()
                        let isToday = Calendar.current.isDate(date, inSameDayAs: entry.date)
                        VStack(spacing: 3) {
                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 11.5, weight: isToday ? .semibold : .regular))
                                .foregroundStyle(isToday ? palette.accent : palette.text)
                            HStack(spacing: 2) {
                                if marks.deadline {
                                    Circle().fill(palette.accent).frame(width: 4, height: 4)
                                }
                                if marks.scheduled {
                                    Circle().fill(Color(rgb: 0xC9922A)).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 35)
                        .background(isToday ? palette.softAccent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color.clear.frame(height: 35)
                    }
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 13) {
                legend("Deadline", color: palette.accent, textColor: palette.secondary)
                legend("Scheduled", color: Color(rgb: 0xC9922A), textColor: palette.secondary)
                Spacer()
                Text("Today is the \(entry.date.formatted(.dateTime.day()))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.tertiary)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .waniWidgetBackground(palette.card)
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private var monthCells: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: entry.date),
              let dayRange = calendar.range(of: .day, in: .month, for: entry.date)
        else { return Array(repeating: nil, count: 42) }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday + 5) % 7
        let dates = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        return Array(repeating: nil, count: leading)
            + dates.map(Optional.some)
            + Array(repeating: nil, count: max(42 - leading - dates.count, 0))
    }

    private func legend(_ title: String, color: Color, textColor: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title).font(.system(size: 10.5)).foregroundStyle(textColor)
        }
    }
}

private extension View {
    func waniWidgetBackground(_ color: Color) -> some View {
        containerBackground(for: .widget) { color }
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255
        )
    }
}

private extension WaniWidgetSnapshot {
    static func preview(now: Date = .now) -> WaniWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let mantis = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let yesimart = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let ideas = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let projects = [
            WaniWidgetProjectSnapshot(id: mantis, title: "Mantis", sortOrder: 0, completedAt: nil, canceledAt: nil, deletedAt: nil),
            WaniWidgetProjectSnapshot(id: yesimart, title: "Yesimart", sortOrder: 1, completedAt: nil, canceledAt: nil, deletedAt: nil),
            WaniWidgetProjectSnapshot(id: ideas, title: "Ideas", sortOrder: 2, completedAt: nil, canceledAt: nil, deletedAt: nil),
        ]
        let titles = [
            "Send the revised Mantis scope to Dana",
            "Book flights for the Yesimart workshop",
            "Water the fig tree",
            "Thirty minutes of guitar",
            "Read two chapters of A Pattern Language",
            "Send August invoices",
            "Yesimart analytics handoff",
            "Weekly review",
            "Draft the quarterly planning doc",
            "Renew both domain names",
            "Mantis onboarding copy pass",
        ]
        let tasks = titles.enumerated().map { index, title in
            let projectID = index.isMultiple(of: 2) ? mantis : yesimart
            let dayOffset = index < 5 ? 0 : index - 4
            return WaniWidgetTaskSnapshot(
                id: UUID(),
                title: title,
                projectID: projectID,
                projectTitle: projectID == mantis ? "Mantis" : "Yesimart",
                status: index == 2 ? "completed" : "open",
                schedule: "date",
                startDate: calendar.date(byAdding: .day, value: dayOffset, to: today),
                deadline: index.isMultiple(of: 3)
                    ? calendar.date(byAdding: .day, value: dayOffset, to: today)
                    : nil,
                createdAt: now.addingTimeInterval(Double(index) * -60),
                updatedAt: now,
                completedAt: index == 2 ? now : nil,
                deletedAt: nil,
                sortOrder: Double(index)
            )
        } + [
            WaniWidgetTaskSnapshot(
                id: UUID(),
                title: "Ask Ana about the studio lease",
                projectID: nil,
                projectTitle: nil,
                status: "open",
                schedule: "inbox",
                startDate: nil,
                deadline: nil,
                createdAt: now,
                updatedAt: now,
                completedAt: nil,
                deletedAt: nil,
                sortOrder: 20
            ),
        ]
        return WaniWidgetSnapshot(generatedAt: now, tasks: tasks, projects: projects)
    }
}

private func waniWidgetConfiguration<Content: View>(
    kind: String,
    displayName: String,
    description: String,
    family: WidgetFamily,
    @ViewBuilder content: @escaping (WaniWidgetEntry) -> Content
) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WaniWidgetProvider()) { entry in
        content(entry)
    }
    .configurationDisplayName(displayName)
    .description(description)
    .supportedFamilies([family])
    .contentMarginsDisabled()
}

private struct WaniTodaySummaryWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.TodaySummary",
            displayName: "Today at a Glance",
            description: "See today's open and completed tasks.",
            family: .systemSmall,
            content: WaniTodaySummaryView.init
        )
    }
}

private struct WaniProjectProgressWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.ProjectProgress",
            displayName: "Project Progress",
            description: "Track progress on your first active project.",
            family: .systemSmall,
            content: WaniProjectProgressView.init
        )
    }
}

private struct WaniInboxWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.Inbox",
            displayName: "Inbox",
            description: "See unsorted tasks waiting in your Inbox.",
            family: .systemSmall,
            content: WaniInboxView.init
        )
    }
}

private struct WaniNextUpWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.NextUp",
            displayName: "Next Up",
            description: "Focus on the next task and act on it quickly.",
            family: .systemSmall,
            content: WaniNextUpView.init
        )
    }
}

private struct WaniTodayListWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.TodayList",
            displayName: "Today List",
            description: "Check off today's first three tasks.",
            family: .systemMedium,
            content: WaniTodayListView.init
        )
    }
}

private struct WaniProjectsWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.Projects",
            displayName: "Projects",
            description: "Compare progress across active projects.",
            family: .systemMedium,
            content: WaniProjectsView.init
        )
    }
}

private struct WaniQuickCaptureWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.QuickCapture",
            displayName: "Quick Capture",
            description: "Open Wani ready to capture into a list.",
            family: .systemMedium,
            content: WaniQuickCaptureView.init
        )
    }
}

private struct WaniUpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.Upcoming",
            displayName: "Upcoming",
            description: "Review the next six days of scheduled tasks.",
            family: .systemLarge,
            content: WaniUpcomingView.init
        )
    }
}

private struct WaniMonthWidget: Widget {
    var body: some WidgetConfiguration {
        waniWidgetConfiguration(
            kind: "Wani.Month",
            displayName: "Month",
            description: "See scheduled tasks and deadlines across the month.",
            family: .systemLarge,
            content: WaniMonthView.init
        )
    }
}

@main
struct WaniWidgets: WidgetBundle {
    var body: some Widget {
        WaniTodaySummaryWidget()
        WaniProjectProgressWidget()
        WaniInboxWidget()
        WaniNextUpWidget()
        WaniTodayListWidget()
        WaniProjectsWidget()
        WaniQuickCaptureWidget()
        WaniUpcomingWidget()
        WaniMonthWidget()
    }
}

#Preview("Today at a Glance", as: .systemSmall) {
    WaniTodaySummaryWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Project Progress", as: .systemSmall) {
    WaniProjectProgressWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Inbox", as: .systemSmall) {
    WaniInboxWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Next Up", as: .systemSmall) {
    WaniNextUpWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Today List", as: .systemMedium) {
    WaniTodayListWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Projects", as: .systemMedium) {
    WaniProjectsWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Quick Capture", as: .systemMedium) {
    WaniQuickCaptureWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Upcoming", as: .systemLarge) {
    WaniUpcomingWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Month", as: .systemLarge) {
    WaniMonthWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

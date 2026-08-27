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
        completion(WaniWidgetEntry(
            date: .now,
            snapshot: context.isPreview
                ? .preview()
                : WaniWidgetSnapshotStore.load() ?? .empty
        ))
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
            card = Color(widgetRGB: 0x28221B)
            text = Color(widgetRGB: 0xEFE7DC)
            secondary = Color(widgetRGB: 0xAC9F92)
            tertiary = Color(widgetRGB: 0x83766A)
            line = Color.white.opacity(0.10)
            hover = Color.white.opacity(0.08)
            accent = Color(widgetRGB: 0xE0794E)
            softAccent = Color(widgetRGB: 0xE0794E).opacity(0.18)
        } else {
            card = Color(widgetRGB: 0xFFFDF9)
            text = Color(widgetRGB: 0x3A312A)
            secondary = Color(widgetRGB: 0x786A5E)
            tertiary = Color(widgetRGB: 0xAAA095)
            line = Color(widgetRGB: 0x8C735A).opacity(0.15)
            hover = Color(widgetRGB: 0xB49678).opacity(0.13)
            accent = Color(widgetRGB: 0xC05A34)
            softAccent = Color(widgetRGB: 0xF7E4D9)
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
        let open = entry.snapshot.todayTasks(now: entry.date)
        let completed = entry.snapshot.completedTodayCount(now: entry.date)

        VStack(alignment: .leading, spacing: 0) {
            WaniWidgetHeader(
                symbol: "star.fill",
                title: "Today",
                color: Color(widgetRGB: 0xC9922A),
                palette: palette
            )
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(open.count.formatted())
                    .font(.system(size: 48, weight: .semibold))
                    .tracking(-2)
                    .foregroundStyle(palette.text)
                Text("to do")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondary)
            }
            .padding(.top, 9)
            Text(completed == 0 ? "Nothing logged yet" : "\(completed) done today")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.tertiary)
                .padding(.top, 3)
            Spacer(minLength: 4)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(weekCounts.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == currentWeekday ? palette.accent : palette.line)
                            .frame(height: CGFloat(4 + min(weekCounts[index], 7) * 2))
                        Text(weekdayLetter(index))
                            .font(.system(size: 8))
                            .foregroundStyle(palette.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 26, alignment: .bottom)
        }
        .padding(15)
        .waniWidgetBackground(palette.card)
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
    }

    private var currentWeekday: Int {
        Calendar.current.dateComponents([.day], from: weekStart, to: entry.date).day ?? 0
    }

    private var weekCounts: [Int] {
        let calendar = Calendar.current
        var result = Array(repeating: 0, count: 7)
        for task in entry.snapshot.tasks where task.deletedAt == nil {
            for date in [task.startDate, task.deadline].compactMap({ $0 }) {
                let offset = calendar.dateComponents([.day], from: weekStart, to: date).day ?? -1
                if result.indices.contains(offset) { result[offset] += 1 }
            }
        }
        return result
    }

    private func weekdayLetter(_ offset: Int) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        else { return "" }
        return date.formatted(.dateTime.weekday(.narrow))
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
                color: Color(widgetRGB: 0xC9922A),
                palette: palette,
                trailing: entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            )
            .padding(.bottom, 8)
            VStack(spacing: 2) {
                ForEach(tasks.prefix(3)) { task in
                    Link(destination: WaniWidgetDeepLink.complete(todoID: task.id)) {
                        HStack(spacing: 10) {
                            Circle()
                                .stroke(palette.tertiary, lineWidth: 1.4)
                                .frame(width: 15, height: 15)
                            Text(task.title)
                                .font(.system(size: 12.5))
                                .lineLimit(1)
                                .foregroundStyle(palette.text)
                            Spacer(minLength: 4)
                            Text(task.projectTitle ?? "Inbox")
                                .font(.system(size: 10.5))
                                .foregroundStyle(palette.tertiary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            Text(tasks.count > 3 ? "\(tasks.count - 3) more in Today" : "All caught up")
                .font(.system(size: 10.5))
                .foregroundStyle(palette.tertiary)
                .padding(.horizontal, 7)
                .padding(.top, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
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
            VStack(alignment: .leading, spacing: 6) {
                Text(task?.title ?? "Nothing left today")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(3)
                    .foregroundStyle(palette.text)
                Text(task.map { ($0.projectTitle ?? "Inbox") + deadlineSuffix($0) } ?? "Enjoy the quiet")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(palette.tertiary)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            if let task {
                HStack(spacing: 6) {
                    Link(destination: WaniWidgetDeepLink.complete(todoID: task.id)) {
                        Text("Complete")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .foregroundStyle(palette.accent)
                    Link(destination: WaniWidgetDeepLink.postpone(todoID: task.id)) {
                        Text("1d")
                            .frame(width: 34)
                            .padding(.vertical, 7)
                            .background(palette.hover, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .foregroundStyle(palette.secondary)
                }
                .font(.system(size: 11.5, weight: .medium))
            }
        }
        .padding(15)
        .waniWidgetBackground(palette.card)
    }

    private func deadlineSuffix(_ task: WaniWidgetTaskSnapshot) -> String {
        guard let deadline = task.deadline else { return "" }
        return " · due " + deadline.formatted(date: .omitted, time: .shortened)
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
                color: Color(widgetRGB: 0xC3564C),
                palette: palette,
                trailing: "Next 6 days"
            )
            .padding(.bottom, 11)
            VStack(spacing: 4) {
                ForEach(days) { day in
                    HStack(alignment: .top, spacing: 11) {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(day.date.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(day.tasks.isEmpty ? palette.tertiary : palette.text)
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                .font(.system(size: 9))
                                .foregroundStyle(palette.tertiary)
                        }
                        .frame(width: 28, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 5) {
                            if day.tasks.isEmpty {
                                Text("—").font(.system(size: 11.5)).foregroundStyle(palette.tertiary)
                            } else {
                                ForEach(day.tasks.prefix(2)) { task in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(task.deadline == nil
                                                ? Color(widgetRGB: 0xC9922A)
                                                : palette.accent)
                                            .frame(width: 5, height: 5)
                                        Text(task.title)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                            .foregroundStyle(palette.text)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(palette.line).frame(width: 1)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.vertical, 17)
        .padding(.horizontal, 18)
        .waniWidgetBackground(palette.card)
    }
}

private struct WaniAccessoryCircularView: View {
    let entry: WaniWidgetEntry

    var body: some View {
        let count = entry.snapshot.todayTasks(now: entry.date).count
        Gauge(value: min(Double(count), 10), in: 0...10) {
            Text("Today")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(count.formatted()).font(.system(size: 18, weight: .semibold))
                Text("TODAY").font(.system(size: 7, weight: .medium))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

private struct WaniAccessoryRectangularView: View {
    let entry: WaniWidgetEntry

    var body: some View {
        let task = entry.snapshot.todayTasks(now: entry.date).first
        VStack(alignment: .leading, spacing: 3) {
            Text("NEXT UP")
                .font(.system(size: 8.5, weight: .semibold))
            Text(task?.title ?? "Nothing left today")
                .font(.system(size: 11.5))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func waniWidgetBackground(_ color: Color) -> some View {
        containerBackground(for: .widget) { color }
    }
}

private extension Color {
    init(widgetRGB: UInt32) {
        self.init(
            red: Double((widgetRGB >> 16) & 0xff) / 255,
            green: Double((widgetRGB >> 8) & 0xff) / 255,
            blue: Double(widgetRGB & 0xff) / 255
        )
    }
}

private extension WaniWidgetSnapshot {
    static func preview(now: Date = .now) -> WaniWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
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
            let dayOffset = index < 5 ? 0 : index - 4
            return WaniWidgetTaskSnapshot(
                id: UUID(),
                title: title,
                projectID: nil,
                projectTitle: index.isMultiple(of: 2) ? "Mantis" : "Yesimart",
                status: "open",
                schedule: "date",
                startDate: calendar.date(byAdding: .day, value: dayOffset, to: today),
                deadline: index.isMultiple(of: 3)
                    ? calendar.date(byAdding: .day, value: dayOffset, to: today)
                    : nil,
                createdAt: now.addingTimeInterval(Double(index) * -60),
                updatedAt: now,
                completedAt: nil,
                deletedAt: nil,
                sortOrder: Double(index)
            )
        }
        return WaniWidgetSnapshot(generatedAt: now, tasks: tasks, projects: [])
    }
}

private func widgetConfiguration<Content: View>(
    kind: String,
    name: String,
    description: String,
    families: [WidgetFamily],
    @ViewBuilder content: @escaping (WaniWidgetEntry) -> Content
) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WaniWidgetProvider()) { entry in
        content(entry)
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies(families)
    .contentMarginsDisabled()
}

private struct WaniTodaySummaryWidget: Widget {
    var body: some WidgetConfiguration {
        widgetConfiguration(
            kind: "Wani.iOS.TodaySummary",
            name: "Today at a Glance",
            description: "See today's open and completed tasks.",
            families: [.systemSmall],
            content: WaniTodaySummaryView.init
        )
    }
}

private struct WaniTodayListWidget: Widget {
    var body: some WidgetConfiguration {
        widgetConfiguration(
            kind: "Wani.iOS.TodayList",
            name: "Today List",
            description: "Check off today's first three tasks.",
            families: [.systemMedium],
            content: WaniTodayListView.init
        )
    }
}

private struct WaniNextUpWidget: Widget {
    var body: some WidgetConfiguration {
        widgetConfiguration(
            kind: "Wani.iOS.NextUp",
            name: "Next Up",
            description: "Focus on the next task and act quickly.",
            families: [.systemSmall],
            content: WaniNextUpView.init
        )
    }
}

private struct WaniUpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        widgetConfiguration(
            kind: "Wani.iOS.Upcoming",
            name: "Upcoming",
            description: "Review the next six days.",
            families: [.systemLarge],
            content: WaniUpcomingView.init
        )
    }
}

private struct WaniTodayAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        widgetConfiguration(
            kind: "Wani.iOS.TodayAccessory",
            name: "Today Count",
            description: "See today's open task count on the Lock Screen.",
            families: [.accessoryCircular],
            content: WaniAccessoryCircularView.init
        )
    }
}

private struct WaniNextAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        widgetConfiguration(
            kind: "Wani.iOS.NextAccessory",
            name: "Next Up",
            description: "See the next task on the Lock Screen.",
            families: [.accessoryRectangular],
            content: WaniAccessoryRectangularView.init
        )
    }
}

@main
struct WaniWidgets: WidgetBundle {
    var body: some Widget {
        WaniTodaySummaryWidget()
        WaniTodayListWidget()
        WaniNextUpWidget()
        WaniUpcomingWidget()
        WaniTodayAccessoryWidget()
        WaniNextAccessoryWidget()
    }
}

#Preview("Today at a Glance", as: .systemSmall) {
    WaniTodaySummaryWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Today List", as: .systemMedium) {
    WaniTodayListWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Next Up", as: .systemSmall) {
    WaniNextUpWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

#Preview("Upcoming", as: .systemLarge) {
    WaniUpcomingWidget()
} timeline: {
    WaniWidgetEntry(date: .now, snapshot: .preview())
}

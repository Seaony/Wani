import SwiftUI

struct WaniTaskDateEditor: View {
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let save: () -> Void
    let reminderChanged: () -> Void
    let recurrenceChanged: () -> Void
    let dismiss: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scheduleRow(
                "Today",
                symbol: "star.fill",
                symbolColor: WaniSmartList.today.symbolColor,
                isSelected: isTodaySelected
            ) {
                scheduleAndDismiss(on: calendar.startOfDay(for: .now))
            }

            scheduleRow(
                "Evening",
                symbol: "moon.fill",
                symbolColor: palette.accent,
                isSelected: isEveningSelected
            ) {
                scheduleAndDismiss(
                    on: calendar.startOfDay(for: .now),
                    isEvening: true
                )
            }

            WaniCompactDateGrid(
                palette: palette,
                selectedDate: todo.schedule == .date ? todo.startDate : nil
            ) { date in
                scheduleAndDismiss(on: date, isEvening: todo.isEvening)
            }
            .padding(.top, 5)
            .padding(.bottom, 7)

            scheduleRow(
                "Anytime",
                symbol: WaniSmartList.anytime.symbolName,
                symbolColor: WaniSmartList.anytime.symbolColor,
                isSelected: todo.schedule == .anytime
            ) {
                setScheduleAndDismiss(.anytime)
            }

            scheduleRow(
                "Someday",
                symbol: WaniSmartList.someday.symbolName,
                symbolColor: WaniSmartList.someday.symbolColor,
                isSelected: todo.schedule == .someday
            ) {
                setScheduleAndDismiss(.someday)
            }

            Divider()
                .overlay(palette.faintLine)
                .padding(.vertical, 7)

            detailRow(
                title: "Reminder",
                symbol: "bell",
                enabled: reminderEnabled
            ) {
                DatePicker(
                    "",
                    selection: reminderBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .waniPointingHand()
            }

        }
        .padding(10)
        .frame(width: 304)
        .background(palette.panel)
        .onDisappear(perform: recurrenceChanged)
    }

    private func scheduleRow(
        _ title: String,
        symbol: String,
        symbolColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(symbolColor)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
            }
            .padding(.horizontal, 7)
            .frame(height: 32)
            .background(
                isSelected ? palette.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 7,
            showsHoverBackground: !isSelected
        ))
    }

    private func detailRow<Content: View>(
        title: String,
        symbol: String,
        enabled: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: enabled) {
                Label(title, systemImage: symbol)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondaryText)
            }
            .toggleStyle(.checkbox)
            .waniPointingHand()
            Spacer()
            if enabled.wrappedValue {
                content()
                    .transition(WaniMotion.overlayTransition)
            }
        }
        .frame(height: 32)
        .animation(WaniMotion.quick, value: enabled.wrappedValue)
    }

    private var isTodaySelected: Bool {
        todo.schedule == .date
            && !todo.isEvening
            && todo.startDate.map(calendar.isDateInToday) == true
    }

    private var isEveningSelected: Bool {
        todo.schedule == .date
            && todo.isEvening
            && todo.startDate.map(calendar.isDateInToday) == true
    }

    private var reminderEnabled: Binding<Bool> {
        Binding(
            get: { todo.reminderDate != nil },
            set: { enabled in
                let reminder = enabled
                    ? WaniTaskRules.suggestedReminderDate(for: todo)
                    : nil
                WaniTaskRules.setReminder(todo, to: reminder)
                save()
                reminderChanged()
            }
        )
    }

    private var reminderBinding: Binding<Date> {
        Binding(
            get: { todo.reminderDate ?? .now },
            set: {
                WaniTaskRules.setReminderTime(todo, to: $0)
                save()
                reminderChanged()
            }
        )
    }

    private func scheduleAndDismiss(on date: Date, isEvening: Bool = false) {
        WaniTaskRules.schedule(todo, as: .date, startDate: date, isEvening: isEvening)
        save()
        reminderChanged()
        dismiss()
    }

    private func setScheduleAndDismiss(_ schedule: WaniTaskSchedule) {
        WaniTaskRules.schedule(todo, as: schedule)
        save()
        reminderChanged()
        dismiss()
    }
}

struct WaniTaskDeadlineEditor: View {
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let save: () -> Void
    let reminderChanged: () -> Void
    let dismiss: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            deadlineRow("Today", symbol: "star.fill", date: today)
            deadlineRow("Tomorrow", symbol: "sunrise.fill", date: tomorrow)
            deadlineRow("Next Week", symbol: "calendar.badge.plus", date: nextWeek)

            WaniCompactDateGrid(
                palette: palette,
                selectedDate: todo.deadline,
                select: setDeadlineAndDismiss
            )
            .padding(.top, 7)

            if todo.deadline != nil {
                Divider()
                    .overlay(palette.faintLine)
                    .padding(.vertical, 7)

                Button {
                    WaniTaskRules.setDeadline(todo, to: nil)
                    save()
                    reminderChanged()
                    dismiss()
                } label: {
                    Label("Clear Deadline", systemImage: "xmark.circle")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                        .frame(height: 32)
                }
                .buttonStyle(.waniInteractive(palette, cornerRadius: 7))
            }
        }
        .padding(10)
        .frame(width: 304)
        .background(palette.panel)
    }

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    private var tomorrow: Date {
        calendar.date(byAdding: .day, value: 1, to: today)!
    }

    private var nextWeek: Date {
        calendar.date(byAdding: .day, value: 7, to: today)!
    }

    private func deadlineRow(_ title: String, symbol: String, date: Date) -> some View {
        let isSelected = todo.deadline.map {
            calendar.isDate($0, inSameDayAs: date)
        } == true

        return Button {
            setDeadlineAndDismiss(date)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.accent)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
            }
            .padding(.horizontal, 7)
            .frame(height: 32)
            .background(
                isSelected ? palette.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 7,
            showsHoverBackground: !isSelected
        ))
    }

    private func setDeadlineAndDismiss(_ date: Date) {
        WaniTaskRules.setDeadline(todo, to: calendar.startOfDay(for: date))
        save()
        reminderChanged()
        dismiss()
    }
}

private struct WaniCompactDateGrid: View {
    let palette: WaniPalette
    let selectedDate: Date?
    let select: (Date) -> Void

    @State private var calendarPage: Int

    private let calendar = Calendar.current
    private let calendarColumns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    init(
        palette: WaniPalette,
        selectedDate: Date?,
        select: @escaping (Date) -> Void
    ) {
        self.palette = palette
        self.selectedDate = selectedDate
        self.select = select

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let selectedDay = selectedDate.map(calendar.startOfDay(for:)) ?? today
        let dayOffset = calendar.dateComponents(
            [.day],
            from: weekStart,
            to: selectedDay
        ).day ?? 0
        _calendarPage = State(initialValue: max(0, dayOffset / 28))
    }

    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: calendarColumns, spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(height: 20)
                }

                ForEach(visibleDates, id: \.self, content: calendarDay)
            }

            HStack {
                Button {
                    withAnimation(WaniMotion.quick) {
                        calendarPage -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.waniInteractive(palette, cornerRadius: 6))
                .disabled(calendarPage == 0)
                .accessibilityLabel("Earlier dates")

                Spacer()

                Button {
                    withAnimation(WaniMotion.quick) {
                        calendarPage += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.waniInteractive(palette, cornerRadius: 6))
                .accessibilityLabel("Later dates")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.secondaryText)
        }
        .animation(WaniMotion.quick, value: calendarPage)
    }

    private func calendarDay(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map {
            calendar.isDate($0, inSameDayAs: date)
        } == true

        return Button {
            select(date)
        } label: {
            Group {
                if isToday {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                } else {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 12.5, weight: .medium))
                }
            }
            .foregroundStyle(isSelected ? palette.accent : palette.text)
            .frame(maxWidth: .infinity)
            .frame(height: 27)
            .background(
                isSelected ? palette.softAccent : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 6,
            showsHoverBackground: !isSelected
        ))
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private var visibleDates: [Date] {
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let pageStart = calendar.date(
            byAdding: .day,
            value: calendarPage * 28,
            to: weekStart
        ) ?? weekStart
        return (0..<28).compactMap {
            calendar.date(byAdding: .day, value: $0, to: pageStart)
        }
    }

}

extension WaniRepeatFrequency {
    var title: String {
        switch self {
        case .none: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    func unitTitle(_ interval: Int) -> String {
        let unit: String
        switch self {
        case .none: return ""
        case .daily: unit = "day"
        case .weekly: unit = "week"
        case .monthly: unit = "month"
        case .yearly: unit = "year"
        }
        return interval == 1 ? unit : "\(unit)s"
    }
}

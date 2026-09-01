import SwiftUI

struct WaniTaskDateEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let save: () -> Void
    let reminderChanged: () -> Void
    let recurrenceChanged: () -> Void
    let dismiss: () -> Void
    var batchSchedule: ((WaniTaskSchedule, Date?, Bool) -> Void)? = nil
    var batchReminder: ((Date?) -> Void)? = nil
    var batchClearSchedule: (() -> Void)? = nil
    var showsSelection = true

    private let calendar = Calendar.current
    @State private var query = ""
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField

            if normalizedQuery.isEmpty {
                pickerContent
                    .padding(.top, 3)
            } else {
                searchResults
                    .padding(.top, 7)
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 7)
        .padding(.bottom, normalizedQuery.isEmpty ? 7 : 9)
        .frame(width: 234)
        .frame(
            minHeight: normalizedQuery.isEmpty ? 286 : 0,
            alignment: .top
        )
        .background(colorScheme == .dark ? Color(hex: 0x1F1F1F) : palette.panel)
        .task {
            await Task.yield()
            searchFieldFocused = true
        }
        .onDisappear(perform: recurrenceChanged)
    }

    private var searchField: some View {
        HStack(spacing: 3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .opacity(query.isEmpty ? 0 : 1)
            TextField("When", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.text)
                .focused($searchFieldFocused)
                .padding(.leading, query.isEmpty ? 62 : 0)
                .onExitCommand {
                    if normalizedQuery.isEmpty {
                        dismiss()
                    } else {
                        query = ""
                    }
                }
            Button {
                query = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(palette.text.opacity(0.82))
            }
            .buttonStyle(.waniInteractive(
                palette,
                cornerRadius: 6,
                showsHoverBackground: false
            ))
            .opacity(query.isEmpty ? 0 : 1)
            .allowsHitTesting(!query.isEmpty)
            .accessibilityHidden(query.isEmpty)
            .accessibilityLabel("Clear date search")
        }
        .padding(.horizontal, 6)
        .frame(height: query.isEmpty ? 24 : 26)
        .background(
            (colorScheme == .dark ? Color(hex: 0x4D4D4D) : palette.hover)
                .opacity(query.isEmpty ? 0 : 1),
            in: Capsule()
        )
        .offset(y: query.isEmpty ? -3 : 0)
    }

    @ViewBuilder
    private var pickerContent: some View {
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
                selectedDate: showsSelection && todo.schedule == .date
                    && !isScheduledByToday
                        ? todo.startDate
                        : nil,
                isCompact: true
            ) { date in
                scheduleAndDismiss(
                    on: date,
                    isEvening: showsSelection && todo.isEvening
                )
            }
            .padding(.top, 3)

            scheduleRow(
                "Someday",
                symbol: WaniSmartList.someday.symbolName,
                symbolColor: WaniSmartList.someday.symbolColor,
                isSelected: showsSelection && todo.schedule == .someday
            ) {
                setScheduleAndDismiss(.someday)
            }

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

            Button("Clear", action: clearScheduleAndDismiss)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    colorScheme == .dark ? Color(hex: 0x4D4D4D) : palette.hover,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .buttonStyle(.waniInteractive(
                    palette,
                    cornerRadius: 8,
                    showsHoverBackground: false
                ))
                .padding(.top, 8)
        }
    }

    private var searchResults: some View {
        VStack(spacing: 0) {
            if matchesQuery("Today") {
                scheduleRow(
                    "Today",
                    symbol: "star.fill",
                    symbolColor: WaniSmartList.today.symbolColor,
                    isSelected: isTodaySelected
                ) {
                    scheduleAndDismiss(on: calendar.startOfDay(for: .now))
                }
            }

            if matchesQuery("Tomorrow") {
                scheduleRow(
                    "Tomorrow",
                    symbol: "sunrise.fill",
                    symbolColor: palette.accent,
                    isSelected: isTomorrowSelected
                ) {
                    scheduleAndDismiss(on: tomorrow)
                }
            }

            if matchesQuery("Evening") {
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
            }

            if matchesQuery("Anytime") {
                scheduleRow(
                    "Anytime",
                    symbol: WaniSmartList.anytime.symbolName,
                    symbolColor: WaniSmartList.anytime.symbolColor,
                    isSelected: showsSelection && todo.schedule == .anytime
                ) {
                    setScheduleAndDismiss(.anytime)
                }
            }

            if matchesQuery("Someday") {
                scheduleRow(
                    "Someday",
                    symbol: WaniSmartList.someday.symbolName,
                    symbolColor: WaniSmartList.someday.symbolColor,
                    isSelected: showsSelection && todo.schedule == .someday
                ) {
                    setScheduleAndDismiss(.someday)
                }
            }

            ForEach(matchingDates, id: \.self) { date in
                let isSelected = date == matchingDates.first
                Button {
                    scheduleAndDismiss(on: date)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(WaniSmartList.upcoming.symbolColor)
                            .frame(width: 16)
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Spacer()
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(isSelected ? .white : palette.tertiaryText)
                    }
                    .padding(.horizontal, 5)
                    .frame(height: 25)
                    .background(
                        isSelected ? Color(hex: 0x3367BD) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                }
                .buttonStyle(.waniInteractive(
                    palette,
                    cornerRadius: 7,
                    showsHoverBackground: !isSelected
                ))
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            }

            if !hasSearchResults {
                Text("No dates found")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private func scheduleRow(
        _ title: String,
        symbol: String,
        symbolColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(symbolColor)
                    .frame(width: 19)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 5)
            .frame(height: 25)
            .background(
                isSelected ? Color(hex: 0x3367BD) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 7,
            showsHoverBackground: !isSelected
        ))
        .padding(.leading, -2)
    }

    private func detailRow<Content: View>(
        title: String,
        symbol: String,
        enabled: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                enabled.wrappedValue.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: enabled.wrappedValue ? symbol : "plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 19)
                    Text(enabled.wrappedValue ? title : "Add \(title)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(palette.secondaryText)
            }
            .buttonStyle(.waniInteractive(palette, cornerRadius: 7))
            Spacer()
            if enabled.wrappedValue {
                content()
                    .transition(WaniMotion.overlayTransition)
            }
        }
        .frame(height: 26)
        .animation(WaniMotion.quick, value: enabled.wrappedValue)
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingDates: [Date] {
        WaniDateSearchRules.matchingDays(
            normalizedQuery,
            calendar: calendar
        )
    }

    private var hasSearchResults: Bool {
        !matchingDates.isEmpty
            || ["Today", "Tomorrow", "Evening", "Anytime", "Someday"]
                .contains(where: matchesQuery)
    }

    private func matchesQuery(_ title: String) -> Bool {
        !normalizedQuery.isEmpty
            && title.localizedCaseInsensitiveContains(normalizedQuery)
    }

    private var isTodaySelected: Bool {
        showsSelection
            && todo.schedule == .date
            && !todo.isEvening
            && isScheduledByToday
    }

    private var isEveningSelected: Bool {
        showsSelection
            && todo.schedule == .date
            && todo.isEvening
            && isScheduledByToday
    }

    private var isScheduledByToday: Bool {
        todo.startDate.map {
            calendar.startOfDay(for: $0) <= calendar.startOfDay(for: .now)
        } == true
    }

    private var tomorrow: Date {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private var isTomorrowSelected: Bool {
        showsSelection
            && todo.schedule == .date
            && todo.startDate.map { calendar.isDate($0, inSameDayAs: tomorrow) } == true
    }

    private var reminderEnabled: Binding<Bool> {
        Binding(
            get: { showsSelection && todo.reminderDate != nil },
            set: { enabled in
                let reminder = enabled
                    ? WaniTaskRules.suggestedReminderDate(for: todo)
                    : nil
                if let batchReminder {
                    batchReminder(reminder)
                    dismiss()
                    return
                }
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
                if let batchReminder {
                    batchReminder($0)
                    dismiss()
                    return
                }
                WaniTaskRules.setReminderTime(todo, to: $0)
                save()
                reminderChanged()
            }
        )
    }

    private func scheduleAndDismiss(on date: Date, isEvening: Bool = false) {
        if let batchSchedule {
            batchSchedule(.date, date, isEvening)
            dismiss()
            return
        }
        WaniTaskRules.schedule(todo, as: .date, startDate: date, isEvening: isEvening)
        save()
        reminderChanged()
        dismiss()
    }

    private func setScheduleAndDismiss(_ schedule: WaniTaskSchedule) {
        if let batchSchedule {
            batchSchedule(schedule, nil, false)
            dismiss()
            return
        }
        WaniTaskRules.schedule(todo, as: schedule)
        save()
        reminderChanged()
        dismiss()
    }

    private func clearScheduleAndDismiss() {
        if let batchClearSchedule {
            batchClearSchedule()
            dismiss()
            return
        }
        setScheduleAndDismiss(todo.project == nil && todo.area == nil ? .inbox : .anytime)
    }
}

struct WaniTaskDeadlineEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    @Binding var query: String
    let save: () -> Void
    let reminderChanged: () -> Void
    let dismiss: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Group {
            if normalizedQuery.isEmpty {
                WaniDeadlineDateGrid(
                    palette: palette,
                    selectedDate: todo.deadline,
                    select: setDeadlineAndDismiss
                )
            } else {
                deadlineSearchResults
            }
        }
        .padding(.leading, normalizedQuery.isEmpty ? 9 : 6)
        .padding(.trailing, normalizedQuery.isEmpty ? 8 : 3)
        .padding(.top, normalizedQuery.isEmpty ? 10 : 6)
        .padding(.bottom, normalizedQuery.isEmpty ? 7 : 3)
        .frame(width: normalizedQuery.isEmpty ? 234 : 231)
        .background(colorScheme == .dark ? Color(hex: 0x1F1F1F) : palette.panel)
    }

    private var deadlineSearchResults: some View {
        VStack(spacing: 0) {
            ForEach(matchingDates, id: \.self) { date in
                let isSelected = date == matchingDates.first
                Button {
                    setDeadlineAndDismiss(date)
                } label: {
                    HStack(spacing: 0) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .offset(y: -2)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 24)
                    .background(
                        isSelected ? Color(hex: 0x3569C0) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                }
                .buttonStyle(.waniInteractive(
                    palette,
                    cornerRadius: 7,
                    showsHoverBackground: !isSelected
                ))
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            }

            if matchingDates.isEmpty {
                Text("No dates found")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingDates: [Date] {
        WaniDateSearchRules.matchingDays(
            normalizedQuery,
            calendar: calendar
        )
    }

    private func setDeadlineAndDismiss(_ date: Date) {
        WaniTaskRules.setDeadline(todo, to: calendar.startOfDay(for: date))
        save()
        reminderChanged()
        dismiss()
    }
}

private struct WaniDeadlineDateGrid: View {
    let palette: WaniPalette
    let selectedDate: Date?
    let select: (Date) -> Void

    private let calendar = Calendar.current
    private let weekCount = 9
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(height: 20)
            }

            ForEach(visibleDates, id: \.self) { date in
                dayButton(date)
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = selectedDate.map {
            calendar.isDate($0, inSameDayAs: date)
        } == true
        let isMonthStart = calendar.component(.day, from: date) == 1

        return Button {
            select(date)
        } label: {
            VStack(spacing: -3) {
                if isMonthStart {
                    Text(date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 9.5, weight: .semibold))
                }
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                isSelected ? palette.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 5,
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
        guard let weekStart = calendar.dateInterval(
            of: .weekOfYear,
            for: calendar.startOfDay(for: .now)
        )?.start else { return [] }

        return (0..<(weekCount * 7)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }
}

private struct WaniCompactDateGrid: View {
    let palette: WaniPalette
    let selectedDate: Date?
    let isCompact: Bool
    let select: (Date) -> Void

    @State private var calendarPage: Int

    private let calendar = Calendar.current
    private var calendarColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: isCompact ? 1 : 4),
            count: 7
        )
    }

    init(
        palette: WaniPalette,
        selectedDate: Date?,
        isCompact: Bool = false,
        select: @escaping (Date) -> Void
    ) {
        self.palette = palette
        self.selectedDate = selectedDate
        self.isCompact = isCompact
        self.select = select

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let selectedDay = selectedDate.map(calendar.startOfDay(for:)) ?? today
        let dayOffset = calendar.dateComponents([.day], from: weekStart, to: selectedDay).day ?? 0
        if isCompact {
            let todayOffset = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0
            let selectedOffset = max(0, dayOffset - todayOffset)
            let firstPageDateCount = 27 - todayOffset
            let page = selectedOffset < firstPageDateCount
                ? 0
                : 1 + (selectedOffset - firstPageDateCount) / 26
            _calendarPage = State(initialValue: page)
        } else {
            _calendarPage = State(initialValue: max(0, dayOffset / 28))
        }
    }

    var body: some View {
        VStack(spacing: isCompact ? 0 : 4) {
            LazyVGrid(columns: calendarColumns, spacing: isCompact ? 0 : 2) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.system(
                            size: isCompact ? 11.5 : 10.5,
                            weight: .semibold
                        ))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(height: isCompact ? 19 : 20)
                }

                if isCompact {
                    ForEach(0..<28, id: \.self, content: compactCalendarCell)
                } else {
                    ForEach(visibleDates, id: \.self, content: calendarDay)
                }
            }

            if !isCompact {
                HStack {
                    pageButton("chevron.left", delta: -1)
                        .disabled(calendarPage == 0)
                        .accessibilityLabel("Earlier dates")

                    Spacer()

                    pageButton("chevron.right", delta: 1)
                        .accessibilityLabel("Later dates")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            }
        }
        .animation(WaniMotion.quick, value: calendarPage)
    }

    @ViewBuilder
    private func compactCalendarCell(_ index: Int) -> some View {
        if calendarPage == 0 && index < compactLeadingEmptyCellCount {
            Color.clear.frame(height: 23)
        } else if calendarPage > 0 && index == 0 {
            pageButton("chevron.left", delta: -1)
                .accessibilityLabel("Earlier dates")
        } else if index == 27 {
            pageButton("chevron.right", delta: 1)
                .accessibilityLabel("Later dates")
        } else if let date = compactDate(at: index) {
            calendarDay(date)
        }
    }

    private func pageButton(_ symbol: String, delta: Int) -> some View {
        Button {
            withAnimation(WaniMotion.quick) {
                calendarPage += delta
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: isCompact ? nil : 22, height: isCompact ? 23 : 22)
                .frame(maxWidth: isCompact ? .infinity : nil)
        }
        .buttonStyle(.waniInteractive(palette, cornerRadius: 6))
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
                        .font(.system(size: isCompact ? 12.5 : 11))
                } else {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(
                            size: isCompact ? 14 : 12.5,
                            weight: isCompact ? .semibold : .medium
                        ))
                }
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 23 : 27)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(palette.accent, lineWidth: 2)
                }
            }
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

    private var compactLeadingEmptyCellCount: Int {
        calendar.dateComponents([.day], from: currentWeekStart, to: today).day ?? 0
    }

    private var compactFirstPageDateCount: Int {
        27 - compactLeadingEmptyCellCount
    }

    private func compactDate(at index: Int) -> Date? {
        let offset: Int
        if calendarPage == 0 {
            guard index >= compactLeadingEmptyCellCount, index < 27 else { return nil }
            offset = index - compactLeadingEmptyCellCount
        } else {
            guard index > 0, index < 27 else { return nil }
            offset = compactFirstPageDateCount + (calendarPage - 1) * 26 + index - 1
        }
        return calendar.date(byAdding: .day, value: offset, to: today)
    }

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    private var currentWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
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

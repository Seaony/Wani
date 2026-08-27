import SwiftUI

struct WaniRepeatConfiguration {
    let frequency: WaniRepeatFrequency
    let interval: Int
    let afterCompletion: Bool
    let weekdays: [Int]
    let dateRules: [WaniRepeatDateRule]
    let endDate: Date?
    let endAfterCount: Int?
    let reminderTime: Date?
    let deadline: Date?
}

private enum WaniRepeatEndCondition: Hashable {
    case never
    case afterOccurrences
    case onDate
}

struct WaniRepeatEditor: View {
    let palette: WaniPalette
    let apply: (WaniRepeatConfiguration) -> Void
    let dismiss: () -> Void
    private let defaultMonth: Int
    private let previewStartDate: Date

    @State private var frequency: WaniRepeatFrequency
    @State private var interval: Int
    @State private var afterCompletion: Bool
    @State private var weekdays: Set<Int>
    @State private var dateRules: [WaniRepeatDateRule]
    @State private var endCondition: WaniRepeatEndCondition
    @State private var endAfterCount: Int
    @State private var endDate: Date
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var deadlineEnabled: Bool
    @State private var deadline: Date

    init(
        todo: WaniTodo,
        palette: WaniPalette,
        apply: @escaping (WaniRepeatConfiguration) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.palette = palette
        self.apply = apply
        self.dismiss = dismiss
        let startDate = todo.startDate ?? Calendar.current.startOfDay(for: .now)
        self.defaultMonth = Calendar.current.component(.month, from: startDate)
        self.previewStartDate = startDate
        _frequency = State(initialValue: todo.repeatFrequency == .none ? .weekly : todo.repeatFrequency)
        _interval = State(initialValue: max(todo.repeatInterval, 1))
        _afterCompletion = State(initialValue: todo.repeatFrequency == .none || todo.repeatsAfterCompletion)
        let initialWeekdays = todo.repeatWeekdays.isEmpty
            ? [Calendar.current.component(.weekday, from: todo.startDate ?? .now)]
            : todo.repeatWeekdays
        _weekdays = State(initialValue: Set(initialWeekdays))
        _dateRules = State(initialValue: todo.repeatDateRules.isEmpty
            ? [WaniRepeatDateRule(
                ordinal: Calendar.current.component(.day, from: startDate),
                month: Calendar.current.component(.month, from: startDate)
            )]
            : todo.repeatDateRules
        )
        _endCondition = State(initialValue: {
            if todo.repeatEndAfterCount != nil { return .afterOccurrences }
            if todo.repeatEndDate != nil { return .onDate }
            return .never
        }())
        _endAfterCount = State(initialValue: max(todo.repeatEndAfterCount ?? 1, 1))
        _endDate = State(
            initialValue: todo.repeatEndDate
                ?? Calendar.current.date(byAdding: .month, value: 3, to: todo.startDate ?? .now)!
        )
        _reminderEnabled = State(initialValue: todo.reminderDate != nil)
        _reminderTime = State(
            initialValue: todo.reminderDate ?? WaniTaskRules.suggestedReminderDate(for: todo)
        )
        _deadlineEnabled = State(initialValue: todo.deadline != nil)
        _deadline = State(
            initialValue: todo.deadline
                ?? Calendar.current.startOfDay(for: todo.startDate ?? .now)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .waniPointingHand()

            VStack(spacing: 0) {
                HStack {
                    Label("Repeat", systemImage: "repeat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 50)

                Rectangle().fill(palette.line).frame(height: 1)

                VStack(alignment: .leading, spacing: 14) {
                    Picker("Pattern", selection: $afterCompletion) {
                        Text("Regularly").tag(false)
                        Text("After Completion").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .waniPointingHand()

                    HStack(spacing: 10) {
                        Text("Every")
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.secondaryText)
                        Stepper(value: $interval, in: 1...99) {
                            Text("\(interval)")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(palette.text)
                                .frame(minWidth: 18)
                        }
                        .waniPointingHand()
                        Picker("Frequency", selection: $frequency) {
                            ForEach(repeatFrequencies, id: \.self) { frequency in
                                Text(frequency.unitTitle(interval).capitalized).tag(frequency)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                        .waniPointingHand()
                        Spacer()
                        Text(afterCompletion ? "after the previous item is completed" : "on schedule")
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.tertiaryText)
                    }
                    .padding(12)
                    .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))

                    if !afterCompletion && frequency == .weekly {
                        weekdaySelector
                    }

                    if !afterCompletion && (frequency == .monthly || frequency == .yearly) {
                        dateRuleEditor
                    }

                    if !afterCompletion {
                        repeatEndSelector
                        repeatPreview
                    }

                    optionRow(
                        title: "Add Reminder",
                        symbol: "bell",
                        enabled: $reminderEnabled
                    ) {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .waniPointingHand()
                    }

                    optionRow(
                        title: "Add Deadline",
                        symbol: "flag",
                        enabled: $deadlineEnabled
                    ) {
                        DatePicker(
                            "Deadline Date",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .waniPointingHand()
                    }
                }
                .padding(18)

                Rectangle().fill(palette.line).frame(height: 1)

                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel", action: dismiss)
                        .buttonStyle(.waniInteractive(palette))
                        .keyboardShortcut(.cancelAction)
                        .foregroundStyle(palette.secondaryText)
                    Button("Save") {
                        apply(WaniRepeatConfiguration(
                            frequency: frequency,
                            interval: interval,
                            afterCompletion: afterCompletion,
                            weekdays: !afterCompletion && frequency == .weekly
                                ? Array(weekdays)
                                : [],
                            dateRules: !afterCompletion
                                && (frequency == .monthly || frequency == .yearly)
                                ? dateRulesForSave
                                : [],
                            endDate: !afterCompletion && endCondition == .onDate ? endDate : nil,
                            endAfterCount: !afterCompletion && endCondition == .afterOccurrences
                                ? endAfterCount
                                : nil,
                            reminderTime: reminderEnabled ? reminderTime : nil,
                            deadline: deadlineEnabled ? deadline : nil
                        ))
                    }
                    .buttonStyle(.borderedProminent)
                    .waniPointingHand()
                    .accessibilityLabel("Save Repeat")
                }
                .padding(.horizontal, 18)
                .frame(height: 54)
            }
            .frame(width: 500)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.32), radius: 36, y: 18)
            .padding(.top, 92)
        }
        .onExitCommand(perform: dismiss)
    }

    private var repeatFrequencies: [WaniRepeatFrequency] {
        WaniRepeatFrequency.allCases.filter { $0 != .none }
    }

    private var weekdaySelector: some View {
        HStack(spacing: 7) {
            Text("On")
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let selected = weekdays.contains(weekday)
                Button {
                    if selected && weekdays.count == 1 { return }
                    if selected {
                        weekdays.remove(weekday)
                    } else {
                        weekdays.insert(weekday)
                    }
                } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(selected ? Color.white : palette.secondaryText)
                        .frame(width: 28, height: 26)
                        .background(
                            selected ? palette.accent : palette.hover,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel("Repeat on \(Calendar.current.weekdaySymbols[weekday - 1])")
            }
            Spacer()
        }
    }

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private var dateRulesForSave: [WaniRepeatDateRule] {
        dateRules.map { rule in
            var rule = rule
            rule.month = frequency == .yearly ? (rule.month ?? defaultMonth) : nil
            return rule
        }
    }

    private var repeatEndSelector: some View {
        HStack(spacing: 10) {
            Label("End", systemImage: "calendar.badge.clock")
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
            Spacer()
            Picker("Repeat End", selection: $endCondition) {
                Text("Never").tag(WaniRepeatEndCondition.never)
                Text("After").tag(WaniRepeatEndCondition.afterOccurrences)
                Text("On Date").tag(WaniRepeatEndCondition.onDate)
            }
            .labelsHidden()
            .frame(width: 100)
            .waniPointingHand()

            switch endCondition {
            case .never:
                EmptyView()
            case .afterOccurrences:
                Stepper(value: $endAfterCount, in: 1...999) {
                    Text("\(endAfterCount) \(endAfterCount == 1 ? "occurrence" : "occurrences")")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                .waniPointingHand()
            case .onDate:
                DatePicker(
                    "Repeat End Date",
                    selection: $endDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .waniPointingHand()
            }
        }
    }

    private var repeatPreview: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Next")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Text(previewDates.isEmpty ? "No upcoming dates" : previewText)
                .font(.system(size: 11.5))
                .foregroundStyle(palette.tertiaryText)
                .lineLimit(1)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var previewDates: [Date] {
        WaniTaskRules.repeatPreviewDates(
            startingAt: previewStartDate,
            frequency: frequency,
            interval: interval,
            afterCompletion: afterCompletion,
            weekdays: frequency == .weekly ? Array(weekdays) : [],
            dateRules: frequency == .monthly || frequency == .yearly ? dateRulesForSave : [],
            endDate: endCondition == .onDate ? endDate : nil,
            endAfterCount: endCondition == .afterOccurrences ? endAfterCount : nil,
            maximumCount: 6
        )
    }

    private var previewText: String {
        previewDates.prefix(5)
            .map { $0.formatted(.dateTime.month(.abbreviated).day()) }
            .joined(separator: ", ") + (previewDates.count > 5 ? ", …" : "")
    }

    private var dateRuleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On")
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)

            ForEach($dateRules) { $rule in
                HStack(spacing: 8) {
                    if frequency == .yearly {
                        Picker("Month", selection: monthBinding($rule)) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 108)
                        .waniPointingHand()
                    }

                    Picker("Ordinal", selection: $rule.ordinal) {
                        ForEach(ordinals(for: rule), id: \.self) { ordinal in
                            Text(ordinalTitle(ordinal)).tag(ordinal)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 82)
                    .waniPointingHand()

                    Picker("Day Type", selection: weekdayBinding($rule)) {
                        Text("Day").tag(Int?.none)
                        ForEach(orderedWeekdays, id: \.self) { weekday in
                            Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(Int?.some(weekday))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                    .waniPointingHand()

                    Spacer()

                    if dateRules.count > 1 {
                        Button {
                            dateRules.removeAll { $0.id == rule.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.waniInteractive(palette))
                        .foregroundStyle(palette.tertiaryText)
                        .accessibilityLabel("Remove Repeat Date")
                    }

                    if rule.id == dateRules.last?.id {
                        Button(action: addDateRule) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.waniInteractive(palette))
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("Add Repeat Date")
                    }
                }
            }
        }
        .padding(10)
        .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
    }

    private func ordinals(for rule: WaniRepeatDateRule) -> [Int] {
        [-1] + Array(1...(rule.weekday == nil ? 31 : 5))
    }

    private func ordinalTitle(_ ordinal: Int) -> String {
        guard ordinal != -1 else { return "Last" }
        let remainder = ordinal % 100
        let suffix: String
        if (11...13).contains(remainder) {
            suffix = "th"
        } else {
            switch ordinal % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(ordinal)\(suffix)"
    }

    private func monthBinding(_ rule: Binding<WaniRepeatDateRule>) -> Binding<Int> {
        Binding(
            get: { rule.wrappedValue.month ?? defaultMonth },
            set: { rule.wrappedValue.month = $0 }
        )
    }

    private func weekdayBinding(_ rule: Binding<WaniRepeatDateRule>) -> Binding<Int?> {
        Binding(
            get: { rule.wrappedValue.weekday },
            set: { weekday in
                rule.wrappedValue.weekday = weekday
                if weekday != nil && rule.wrappedValue.ordinal > 5 {
                    rule.wrappedValue.ordinal = 1
                }
            }
        )
    }

    private func addDateRule() {
        dateRules.append(WaniRepeatDateRule(
            ordinal: 1,
            month: frequency == .yearly
                ? defaultMonth
                : nil
        ))
    }

    private func optionRow<Content: View>(
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
            }
        }
    }
}

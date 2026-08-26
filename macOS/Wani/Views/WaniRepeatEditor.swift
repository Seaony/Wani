import SwiftUI

struct WaniRepeatConfiguration {
    let frequency: WaniRepeatFrequency
    let interval: Int
    let afterCompletion: Bool
    let weekdays: [Int]
    let endDate: Date?
    let reminderTime: Date?
    let deadline: Date?
}

struct WaniRepeatEditor: View {
    let palette: WaniPalette
    let apply: (WaniRepeatConfiguration) -> Void
    let dismiss: () -> Void

    @State private var frequency: WaniRepeatFrequency
    @State private var interval: Int
    @State private var afterCompletion: Bool
    @State private var weekdays: Set<Int>
    @State private var endDateEnabled: Bool
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
        _frequency = State(initialValue: todo.repeatFrequency == .none ? .weekly : todo.repeatFrequency)
        _interval = State(initialValue: max(todo.repeatInterval, 1))
        _afterCompletion = State(initialValue: todo.repeatFrequency == .none || todo.repeatsAfterCompletion)
        let initialWeekdays = todo.repeatWeekdays.isEmpty
            ? [Calendar.current.component(.weekday, from: todo.startDate ?? .now)]
            : todo.repeatWeekdays
        _weekdays = State(initialValue: Set(initialWeekdays))
        _endDateEnabled = State(initialValue: todo.repeatEndDate != nil)
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
                        Picker("Frequency", selection: $frequency) {
                            ForEach(repeatFrequencies, id: \.self) { frequency in
                                Text(frequency.unitTitle(interval).capitalized).tag(frequency)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
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

                    if !afterCompletion {
                        optionRow(
                            title: "End Date",
                            symbol: "calendar.badge.clock",
                            enabled: $endDateEnabled
                        ) {
                            DatePicker(
                                "Repeat End Date",
                                selection: $endDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.field)
                        }
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
                    }
                }
                .padding(18)

                Rectangle().fill(palette.line).frame(height: 1)

                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel", action: dismiss)
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.secondaryText)
                    Button("Save") {
                        apply(WaniRepeatConfiguration(
                            frequency: frequency,
                            interval: interval,
                            afterCompletion: afterCompletion,
                            weekdays: !afterCompletion && frequency == .weekly
                                ? Array(weekdays)
                                : [],
                            endDate: !afterCompletion && endDateEnabled ? endDate : nil,
                            reminderTime: reminderEnabled ? reminderTime : nil,
                            deadline: deadlineEnabled ? deadline : nil
                        ))
                    }
                    .buttonStyle(.borderedProminent)
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
                .buttonStyle(.plain)
                .accessibilityLabel("Repeat on \(Calendar.current.weekdaySymbols[weekday - 1])")
            }
            Spacer()
        }
    }

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
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
            Spacer()
            if enabled.wrappedValue {
                content()
            }
        }
    }
}

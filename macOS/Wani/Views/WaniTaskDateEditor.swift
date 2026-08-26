import SwiftUI

struct WaniTaskDateEditor: View {
    @Bindable var todo: WaniTodo
    let palette: WaniPalette
    let save: () -> Void
    let reminderChanged: () -> Void
    let recurrenceChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                scheduleButton("Today", symbol: "star.fill") {
                    schedule(on: Calendar.current.startOfDay(for: .now))
                }
                scheduleButton("Evening", symbol: "moon.fill") {
                    schedule(on: Calendar.current.startOfDay(for: .now), isEvening: true)
                }
                scheduleButton("Tomorrow", symbol: "sunrise.fill") {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
                    schedule(on: Calendar.current.startOfDay(for: tomorrow))
                }
                scheduleButton("Anytime", symbol: "square.3.layers.3d") {
                    setSchedule(.anytime)
                }
                scheduleButton("Someday", symbol: "archivebox.fill") {
                    setSchedule(.someday)
                }
            }

            DatePicker(
                "Schedule",
                selection: startDateBinding,
                displayedComponents: .date
            )
            .datePickerStyle(.field)

            Divider().overlay(palette.faintLine)

            detailRow(
                title: "Deadline",
                symbol: "flag",
                enabled: deadlineEnabled
            ) {
                DatePicker(
                    "",
                    selection: deadlineBinding,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.field)
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
            }

            HStack(spacing: 10) {
                Image(systemName: "repeat")
                    .frame(width: 18)
                    .foregroundStyle(palette.tertiaryText)
                Text("Repeat")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Picker("Repeat", selection: repeatBinding) {
                    ForEach(WaniRepeatFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .labelsHidden()
                .frame(width: 112)
            }

            if todo.repeatFrequency != .none {
                HStack(spacing: 14) {
                    Stepper(value: repeatIntervalBinding, in: 1...99) {
                        Text("Every \(todo.repeatInterval) \(todo.repeatFrequency.unitTitle(todo.repeatInterval))")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Toggle("After completion", isOn: repeatAfterCompletionBinding)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                }
            }
        }
        .padding(12)
        .background(palette.hover, in: RoundedRectangle(cornerRadius: 9))
        .onDisappear(perform: recurrenceChanged)
    }

    private func scheduleButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(palette.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
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
            Spacer()
            if enabled.wrappedValue {
                content()
            }
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { todo.startDate ?? .now },
            set: { schedule(on: $0, isEvening: todo.isEvening) }
        )
    }

    private var deadlineEnabled: Binding<Bool> {
        Binding(
            get: { todo.deadline != nil },
            set: { enabled in
                let deadline = enabled
                    ? Calendar.current.date(byAdding: .day, value: 7, to: todo.startDate ?? .now)
                    : nil
                WaniTaskRules.setDeadline(todo, to: deadline)
                save()
                reminderChanged()
            }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { todo.deadline ?? .now },
            set: {
                WaniTaskRules.setDeadline(todo, to: $0)
                save()
                reminderChanged()
            }
        )
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

    private var repeatBinding: Binding<WaniRepeatFrequency> {
        Binding(
            get: { todo.repeatFrequency },
            set: {
                WaniTaskRules.setRepeatFrequency($0, for: todo)
                save()
                reminderChanged()
            }
        )
    }

    private var repeatIntervalBinding: Binding<Int> {
        Binding(
            get: { todo.repeatInterval },
            set: { todo.repeatInterval = $0; touchAndSave() }
        )
    }

    private var repeatAfterCompletionBinding: Binding<Bool> {
        Binding(
            get: { todo.repeatsAfterCompletion },
            set: {
                todo.repeatsAfterCompletion = $0
                if $0 {
                    todo.repeatWeekdays = []
                    todo.repeatDateRules = []
                    todo.repeatEndDate = nil
                    todo.repeatEndAfterCount = nil
                }
                touchAndSave()
            }
        )
    }

    private func schedule(on date: Date, isEvening: Bool = false) {
        WaniTaskRules.schedule(todo, as: .date, startDate: date, isEvening: isEvening)
        save()
        reminderChanged()
    }

    private func setSchedule(_ schedule: WaniTaskSchedule) {
        WaniTaskRules.schedule(todo, as: schedule)
        save()
        reminderChanged()
    }

    private func touchAndSave() {
        todo.updatedAt = .now
        save()
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

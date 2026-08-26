import SwiftUI

struct WaniRepeatEditor: View {
    let palette: WaniPalette
    let apply: (WaniRepeatFrequency, Int, Bool, Date?, Date?) -> Void
    let dismiss: () -> Void

    @State private var frequency: WaniRepeatFrequency
    @State private var interval: Int
    @State private var afterCompletion: Bool
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var deadlineEnabled: Bool
    @State private var deadline: Date

    init(
        todo: WaniTodo,
        palette: WaniPalette,
        apply: @escaping (WaniRepeatFrequency, Int, Bool, Date?, Date?) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.palette = palette
        self.apply = apply
        self.dismiss = dismiss
        _frequency = State(initialValue: todo.repeatFrequency == .none ? .weekly : todo.repeatFrequency)
        _interval = State(initialValue: max(todo.repeatInterval, 1))
        _afterCompletion = State(initialValue: todo.repeatFrequency == .none || todo.repeatsAfterCompletion)
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
                        apply(
                            frequency,
                            interval,
                            afterCompletion,
                            reminderEnabled ? reminderTime : nil,
                            deadlineEnabled ? deadline : nil
                        )
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

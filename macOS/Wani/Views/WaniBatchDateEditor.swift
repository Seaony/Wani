import SwiftUI

struct WaniBatchDateEditor: View {
    let palette: WaniPalette
    let apply: (WaniTaskSchedule, Date?, Bool) -> Void
    let applyReminder: (Date?) -> Void

    @State private var customDate = Calendar.current.startOfDay(for: .now)
    @State private var reminderTime = Date.now.addingTimeInterval(3_600)
    @State private var reminderEditorOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                scheduleButton("Today", symbol: "star.fill") {
                    applyDate(Calendar.current.startOfDay(for: .now))
                }
                scheduleButton("Evening", symbol: "moon.fill") {
                    applyDate(Calendar.current.startOfDay(for: .now), isEvening: true)
                }
                scheduleButton("Tomorrow", symbol: "sunrise.fill") {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
                    applyDate(Calendar.current.startOfDay(for: tomorrow))
                }
                scheduleButton("Anytime", symbol: "square.3.layers.3d") {
                    apply(.anytime, nil, false)
                }
                scheduleButton("Someday", symbol: "archivebox.fill") {
                    apply(.someday, nil, false)
                }
            }

            Divider().overlay(palette.faintLine)

            HStack(spacing: 10) {
                DatePicker(
                    "Schedule",
                    selection: $customDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.field)
                .waniPointingHand()

                Button("Apply Date") {
                    applyDate(customDate)
                }
                .buttonStyle(.borderedProminent)
                .waniPointingHand()
            }

            Divider().overlay(palette.faintLine)

            HStack(spacing: 10) {
                Button {
                    reminderEditorOpen.toggle()
                } label: {
                    Label("Add Reminder", systemImage: "bell")
                }
                .buttonStyle(.waniInteractive(palette))
                .foregroundStyle(palette.secondaryText)

                Spacer()

                Button("Clear Reminders") {
                    applyReminder(nil)
                }
                .buttonStyle(.waniInteractive(palette))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(palette.accent)
            }

            if reminderEditorOpen {
                HStack(spacing: 10) {
                    DatePicker(
                        "Reminder Time",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.field)
                    .waniPointingHand()

                    Button("Apply Reminder") {
                        applyReminder(reminderTime)
                    }
                    .buttonStyle(.borderedProminent)
                    .waniPointingHand()
                }
                .transition(WaniMotion.revealTransition)
            }
        }
        .animation(WaniMotion.standard, value: reminderEditorOpen)
        .padding(12)
        .background(palette.hover, in: RoundedRectangle(cornerRadius: 9))
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
        .buttonStyle(.waniInteractive(palette))
        .accessibilityLabel("Schedule \(title)")
    }

    private func applyDate(_ date: Date, isEvening: Bool = false) {
        apply(
            .date,
            Calendar.current.startOfDay(for: date),
            isEvening
        )
    }
}

import SwiftUI

struct WaniBatchDeadlineEditor: View {
    let palette: WaniPalette
    let apply: (Date?) -> Void

    @State private var deadline = Calendar.current.date(
        byAdding: .day,
        value: 7,
        to: Calendar.current.startOfDay(for: .now)
    )!

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Deadline", systemImage: "flag")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            DatePicker(
                "Deadline Date",
                selection: $deadline,
                displayedComponents: .date
            )
            .datePickerStyle(.field)

            HStack {
                Button("Clear Deadlines") {
                    apply(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(palette.accent)

                Spacer()

                Button("Apply Deadline") {
                    apply(deadline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(palette.hover, in: RoundedRectangle(cornerRadius: 9))
    }
}

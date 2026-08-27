import AppKit
import SwiftData
import SwiftUI

struct WaniMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \WaniTodo.sortOrder) private var todos: [WaniTodo]
    @AppStorage("moveToLogbookAtMidnight") private var moveToLogbookAtMidnight = false
    @State private var dateReference = Date.now

    /// Shares the sidebar's counting path so the menu bar cannot disagree with the
    /// main window when items linger in their list until midnight.
    private var todayCount: Int {
        WaniTaskRules.smartListCounts(
            todos,
            now: dateReference,
            deferCompletedUntilMidnight: moveToLogbookAtMidnight
        )[.today] ?? 0
    }

    var body: some View {
        Text(todayCount == 1 ? "1 to-do today" : "\(todayCount) to-dos today")
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                dateReference = .now
            }

        Divider()

        Button("Open Wani") {
            openWindow(id: "main")
            NSApplication.shared.activate()
        }

        Button("Quit Wani") {
            NSApplication.shared.terminate(nil)
        }
    }
}

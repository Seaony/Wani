import AppKit
import SwiftData
import SwiftUI

struct WaniMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \WaniTodo.sortOrder) private var todos: [WaniTodo]
    @State private var dateReference = Date.now

    private var todayCount: Int {
        WaniTaskRules.tasks(todos, in: .today, now: dateReference).count
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

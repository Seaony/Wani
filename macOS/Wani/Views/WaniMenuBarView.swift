import AppKit
import SwiftData
import SwiftUI

struct WaniMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \WaniTodo.sortOrder) private var todos: [WaniTodo]

    private var todayCount: Int {
        WaniTaskRules.tasks(todos, in: .today).count
    }

    var body: some View {
        Text(todayCount == 1 ? "1 to-do today" : "\(todayCount) to-dos today")

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

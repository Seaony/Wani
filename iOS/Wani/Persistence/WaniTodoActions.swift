import Foundation
import SwiftData

/// Status changes go through the shared rules so completing on iOS keeps the same
/// repeat, Logbook and reminder semantics as macOS.
enum WaniTodoActions {
    static func complete(_ todo: WaniTodo, in context: ModelContext) {
        if let next = WaniTaskRules.complete(todo) {
            context.insert(next)
        }
        todo.isNew = false
    }
}

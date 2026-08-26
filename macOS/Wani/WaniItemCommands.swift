import SwiftUI

struct WaniItemCommandActions {
    let canEdit: Bool
    let canClose: Bool
    let canDuplicate: Bool
    let canRepeat: Bool
    let openWhen: () -> Void
    let openMove: () -> Void
    let openTags: () -> Void
    let openDeadline: () -> Void
    let openRepeat: () -> Void
    let duplicate: () -> Void
    let complete: () -> Void
    let cancel: () -> Void
}

private struct WaniItemCommandActionsKey: FocusedValueKey {
    typealias Value = WaniItemCommandActions
}

extension FocusedValues {
    var waniItemCommandActions: WaniItemCommandActions? {
        get { self[WaniItemCommandActionsKey.self] }
        set { self[WaniItemCommandActionsKey.self] = newValue }
    }
}

struct WaniItemCommands: Commands {
    @FocusedValue(\.waniItemCommandActions) private var actions

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Duplicate To-Do") {
                actions?.duplicate()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(actions?.canDuplicate != true)
        }

        CommandMenu("Items") {
            Button("When…") {
                actions?.openWhen()
            }
            .disabled(actions?.canEdit != true)

            Button("Move…") {
                actions?.openMove()
            }
            .disabled(actions?.canEdit != true)

            Button("Tags…") {
                actions?.openTags()
            }
            .disabled(actions?.canEdit != true)

            Button("Deadline…") {
                actions?.openDeadline()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(actions?.canEdit != true)

            Divider()

            Menu("Completion") {
                Button("Mark as Completed") {
                    actions?.complete()
                }

                Button("Mark as Canceled") {
                    actions?.cancel()
                }
            }
            .disabled(actions?.canClose != true)

            Button("Repeat…") {
                actions?.openRepeat()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(actions?.canRepeat != true)
        }
    }
}

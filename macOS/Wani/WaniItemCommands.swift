import AppKit
import SwiftUI

struct WaniItemCommandActions {
    let canEdit: Bool
    let canClose: Bool
    let canDuplicate: Bool
    let canRepeat: Bool
    let canSaveAndClose: Bool
    let canTrash: Bool
    let openWhen: () -> Void
    let openMove: () -> Void
    let openTags: () -> Void
    let openDeadline: () -> Void
    let openRepeat: () -> Void
    let copy: () -> Void
    let paste: () -> Void
    let duplicate: () -> Void
    let saveAndClose: () -> Void
    let complete: () -> Void
    let cancel: () -> Void
    let moveToTrash: () -> Void
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
        // The default WindowGroup "New Window" item claims ⌘N in the File menu, and a
        // menu key equivalent wins over the in-window New To-Do shortcut.
        CommandGroup(replacing: .newItem) { }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("Copy") {
                actions?.copy()
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Paste") {
                actions?.paste()
            }
            .keyboardShortcut("v", modifiers: .command)
        }

        CommandGroup(after: .pasteboard) {
            Button("Duplicate To-Do") {
                actions?.duplicate()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(actions?.canDuplicate != true)
        }

        CommandMenu("Items") {
            Button("Save and Close") {
                actions?.saveAndClose()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(actions?.canSaveAndClose != true)

            Divider()

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
                .keyboardShortcut("k", modifiers: .command)

                Button("Mark as Canceled") {
                    actions?.cancel()
                }
                .keyboardShortcut("k", modifiers: [.command, .option])
            }
            .disabled(actions?.canClose != true)

            Button("Repeat…") {
                actions?.openRepeat()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(actions?.canRepeat != true)

            Divider()

            // Replacing the pasteboard group drops the system Delete item, which left
            // no menu path to this app's destructive action.
            Button("Move to Trash", role: .destructive) {
                actions?.moveToTrash()
            }
            .disabled(actions?.canTrash != true)
        }
    }
}

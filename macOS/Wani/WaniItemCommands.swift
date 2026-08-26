import SwiftUI

struct WaniItemCommandActions {
    let isEnabled: Bool
    let openWhen: () -> Void
    let openDeadline: () -> Void
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
        CommandMenu("Items") {
            Button("When…") {
                actions?.openWhen()
            }
            .disabled(actions?.isEnabled != true)

            Button("Deadline…") {
                actions?.openDeadline()
            }
            .disabled(actions?.isEnabled != true)
        }
    }
}

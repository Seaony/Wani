import Carbon
import Foundation

enum WaniQuickEntryShortcut: String, CaseIterable, Identifiable {
    case controlSpace
    case controlOptionSpace
    case controlCommandSpace

    var id: Self { self }

    var title: String {
        switch self {
        case .controlSpace: "⌃Space"
        case .controlOptionSpace: "⌃⌥Space"
        case .controlCommandSpace: "⌃⌘Space"
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .controlSpace: UInt32(controlKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        case .controlCommandSpace: UInt32(controlKey | cmdKey)
        }
    }
}

extension Notification.Name {
    static let waniOpenQuickEntry = Notification.Name("wani.openQuickEntry")
}

private func waniHotKeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .waniOpenQuickEntry, object: nil)
    }
    return noErr
}

final class WaniGlobalHotKey {
    static let shared = WaniGlobalHotKey()

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    private init() {}

    func register(_ shortcut: WaniQuickEntryShortcut) -> String? {
        unregister()

        if eventHandler == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                waniHotKeyHandler,
                1,
                &eventType,
                nil,
                &eventHandler
            )
            guard handlerStatus == noErr else {
                return "Global shortcut handler could not start (error \(handlerStatus))."
            }
        }

        let identifier = EventHotKeyID(signature: 0x57414E49, id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard status == noErr else {
            return "\(shortcut.title) is already in use (error \(status))."
        }
        return nil
    }

    private func unregister() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }
}

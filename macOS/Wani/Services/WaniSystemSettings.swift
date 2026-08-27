import AppKit
import ServiceManagement

@MainActor
enum WaniStartupService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openManagement() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
enum WaniDockBadge {
    static func update(count: Int) {
        NSApplication.shared.dockTile.badgeLabel = count > 0
            ? count.formatted()
            : nil
    }
}

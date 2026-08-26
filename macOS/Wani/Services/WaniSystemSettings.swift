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
}

@MainActor
enum WaniDockBadge {
    static func update(enabled: Bool, todayCount: Int) {
        NSApplication.shared.dockTile.badgeLabel = enabled && todayCount > 0
            ? todayCount.formatted()
            : nil
    }
}

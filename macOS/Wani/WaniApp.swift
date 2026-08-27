//
//  WaniApp.swift
//  Wani
//
//  Created by seaony on 2026/8/26.
//

import Foundation
import SwiftUI
import SwiftData

@main
struct WaniApp: App {
    private let modelContainer: ModelContainer
    private let cloudSyncEnabled: Bool
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    init() {
        do {
            let isRunningTests = WaniPersistence.usesEphemeralStore(
                arguments: ProcessInfo.processInfo.arguments,
                environment: ProcessInfo.processInfo.environment
            )
            #if DEBUG
            let enablesCloudSync = ProcessInfo.processInfo.arguments.contains("--cloud-sync")
                && !isRunningTests
            #else
            let enablesCloudSync = true
            #endif
            cloudSyncEnabled = enablesCloudSync
            modelContainer = try WaniPersistence.makeContainer(
                inMemory: isRunningTests,
                cloudSync: enablesCloudSync
            )
        } catch {
            fatalError("Unable to initialize Wani storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Wani", id: "main") {
            ContentView()
        }
        .modelContainer(modelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 790)
        .commands {
            WaniItemCommands()
        }

        Settings {
            WaniSettingsView(cloudSyncEnabled: cloudSyncEnabled)
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)

        MenuBarExtra(
            "Wani",
            systemImage: "checkmark.circle",
            isInserted: $showMenuBarIcon
        ) {
            WaniMenuBarView()
        }
        .modelContainer(modelContainer)
        .menuBarExtraStyle(.menu)
    }
}

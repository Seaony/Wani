//
//  WaniApp.swift
//  Wani
//
//  Created by seaony on 2026/8/27.
//

import SwiftData
import SwiftUI

@main
struct WaniApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            let inMemory = WaniPersistence.usesEphemeralStore(
                arguments: ProcessInfo.processInfo.arguments,
                environment: ProcessInfo.processInfo.environment
            )
            // Mirrors the macOS launch rules: Debug stays on the local store unless
            // --cloud-sync is passed, so an unsigned simulator run never fails on a
            // CloudKit container it cannot reach.
            #if DEBUG
            let enablesCloudSync = ProcessInfo.processInfo.arguments.contains("--cloud-sync")
                && !inMemory
            #else
            let enablesCloudSync = true
            #endif
            modelContainer = try WaniPersistence.makeContainer(
                inMemory: inMemory,
                cloudSync: enablesCloudSync
            )
        } catch {
            fatalError("Unable to initialize Wani storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

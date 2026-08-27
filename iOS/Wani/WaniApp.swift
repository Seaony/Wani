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
            modelContainer = try WaniPersistence.makeContainer(inMemory: inMemory)
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

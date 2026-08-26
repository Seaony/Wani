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

    init() {
        do {
            let isRunningTests = ProcessInfo.processInfo.environment[
                "XCTestConfigurationFilePath"
            ] != nil
            modelContainer = try WaniPersistence.makeContainer(
                inMemory: isRunningTests,
                cloudSync: !isRunningTests
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

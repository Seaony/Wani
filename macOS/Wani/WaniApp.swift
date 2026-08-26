//
//  WaniApp.swift
//  Wani
//
//  Created by seaony on 2026/8/26.
//

import SwiftUI
import SwiftData

@main
struct WaniApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try WaniPersistence.makeContainer()
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

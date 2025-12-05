//
//  WorkScheduleAppApp.swift
//  WorkScheduleApp
//
//  Créé le 24 novembre 2025
//

import SwiftUI
import SwiftData

@main
struct WorkScheduleAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkSchedule.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Impossible de créer le ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
